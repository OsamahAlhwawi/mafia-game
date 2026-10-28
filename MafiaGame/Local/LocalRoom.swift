import Foundation

/// Phase lengths, in seconds.
struct PhaseTimings: Sendable {
    var roleReveal: Double
    var night: Double
    var morning: Double
    var voting: Double
    var verdict: Double
    /// Once everyone has voted, voting closes after this (votes can still change meanwhile).
    var voteGrace: Double
    /// The most-voted player defends themself.
    var defense: Double
    /// Everyone else chooses: eliminate or pardon.
    var judgment: Double
    /// Used only with fast timers; otherwise the host's discussion setting applies.
    var discussion: Double
    /// The results stay up this long before the room goes back to the lobby.
    var postGame: Double
    /// How long a bot thinks before acting.
    var botDelay: ClosedRange<Double>
    /// Bots' discussion lines are spread across this much of the discussion.
    var botChatSpan: Double

    static let normal = PhaseTimings(
        roleReveal: 10, night: 25, morning: 5, voting: 15, verdict: 8, voteGrace: 5, defense: 20, judgment: 15,
        discussion: 120, postGame: 15, botDelay: 1.5...5.5, botChatSpan: 60
    )
    static let fast = PhaseTimings(
        roleReveal: 4, night: 12, morning: 3, voting: 8, verdict: 3, voteGrace: 2, defense: 8, judgment: 6,
        discussion: 15, postGame: 15, botDelay: 0.5...2, botChatSpan: 10
    )
}

struct LocalPlayer {
    let id: String
    var name: String
    let isBot: Bool
    let gender: Gender
    let avatar: String
    var alive = true
    var role: RoleID?

    var def: RoleDefinition? { role.map { RoleCatalog[$0] } }
}

/// One game room, played entirely on the device: the narrator that the online
/// version runs on a server. Holds all state, runs the phase timers and the
/// bots, and enforces who may do what. What each player gets to see is built
/// in `LocalRoom+Snapshots.swift`.
@MainActor
final class LocalRoom {
    static let maxRounds = 15
    static let discussionRange = 30...300

    let code: String
    let capacity: Int
    let rng: GameRandom
    private(set) var name: String
    private(set) var hostId = ""
    private(set) var phase: GamePhase = .lobby
    private(set) var phaseSeq = 0
    private(set) var phaseEndsAt: Date?
    private(set) var round = 0
    private(set) var discussionSeconds = 60
    /// The host's choice of cards; kept from one game to the next.
    private(set) var roleSetup = RoleSetup()
    private(set) var fastTimers = false
    var normalTimings = PhaseTimings.normal
    var fastTimings = PhaseTimings.fast

    /// In seating order.
    private(set) var players: [LocalPlayer] = []
    /// actorId → target for the current night (nil: skipped).
    private(set) var nightChoices: [String: String?] = [:]
    /// actorId → target from the previous night (doctor's "not twice in a row").
    private var lastNightChoices: [String: String?] = [:]
    /// actorId → everyone they picked on earlier nights (detective's "never the same player again").
    private var pastTargets: [String: Set<String>] = [:]
    /// actorId → how many times a limited ability was used this game (the officer's bullet).
    private var abilityUses: [String: Int] = [:]
    /// Players who revealed their card by day (the mayor).
    private(set) var publicReveals: Set<String> = []
    /// inspectorId → what they found; only that player is ever shown it.
    private(set) var inspections: [String: [InspectionResult]] = [:]
    private(set) var dayVotes: [String: String?] = [:]
    /// The most-voted player, on trial during the defense and the judgment.
    private(set) var accusedId: String?
    private(set) var judgments: [String: Judgment] = [:]
    private(set) var forcedRoles: [String: RoleID] = [:]
    private(set) var chatLog: [ChatMessage] = []
    private(set) var narration: String?
    private(set) var lastNightKilledIds: [String] = []
    private(set) var verdict: VerdictInfo?
    private(set) var winner: Winner?
    /// A win decided at night/verdict end, announced after the morning/verdict screen.
    private var pendingWinner: Winner?

    private var phaseTask: Task<Void, Never>?
    private var botTasks: [Task<Void, Never>] = []

    var onChange: () -> Void = {}
    var onChat: (ChatMessage) -> Void = { _ in }
    var onGameEnded: (Winner) -> Void = { _ in }

    init(code: String, name: String, capacity: Int, rng: GameRandom) {
        self.code = code
        self.name = name
        self.capacity = min(Deal.maxPlayers, max(Deal.minPlayers, capacity))
        self.rng = rng
    }

    var timings: PhaseTimings { fastTimers ? fastTimings : normalTimings }

    func player(_ id: String?) -> LocalPlayer? {
        players.first { $0.id == id }
    }

    // MARK: Membership

    func join(id: String, name: String, gender: Gender, avatar: String, isBot: Bool = false) throws(LocalError) {
        guard phase == .lobby else { throw LocalError(.wrongPhase) }
        guard players.count < capacity else { throw LocalError(.roomFull) }
        players.append(LocalPlayer(id: id, name: uniqueName(name), isBot: isBot, gender: gender, avatar: avatar))
        if hostId.isEmpty && !isBot { hostId = id }
        changed()
    }

    /// Two «محمد» in one room become «محمد» and «محمد ٢».
    private func uniqueName(_ name: String) -> String {
        let taken = Set(players.map(\.name))
        guard taken.contains(name) else { return name }
        let arabic = Locale(identifier: "ar_SA")
        return (2...).lazy.map { "\(name) \($0.formatted(.number.locale(arabic)))" }.first { !taken.contains($0) }!
    }

    func kick(by: String, targetId: String) throws(LocalError) {
        try requireHost(by)
        try requirePhase(.lobby)
        guard targetId != by, player(targetId) != nil else { throw LocalError(.invalidTarget) }
        players.removeAll { $0.id == targetId }
        forcedRoles[targetId] = nil
        changed()
    }

    /// An empty name brings back the default, «غرفة <host>».
    func rename(by: String, to newName: String) throws(LocalError) {
        try requireHost(by)
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmed.isEmpty ? "غرفة \(player(by)?.name ?? "")" : String(trimmed.prefix(24))
        changed()
    }

    /// Stops every timer; the room is being thrown away.
    func dispose() {
        clearPhaseTimers()
    }

    // MARK: Host & dev controls

    func setDiscussionSeconds(by: String, _ seconds: Int) throws(LocalError) {
        try requireHost(by)
        guard phase != .ended else { throw LocalError(.wrongPhase) }
        discussionSeconds = min(Self.discussionRange.upperBound, max(Self.discussionRange.lowerBound, seconds))
        changed()
    }

    /// nil deals mafia by the player count again.
    func setMafiaCount(by: String, _ count: Int?) throws(LocalError) {
        try requireHost(by)
        try requirePhase(.lobby)
        roleSetup.mafia = count.map { max(1, $0) }
        changed()
    }

    func setRoleEnabled(by: String, _ role: RoleID, _ enabled: Bool) throws(LocalError) {
        try requireHost(by)
        try requirePhase(.lobby)
        guard Deal.optionalRoles.contains(role) else { throw LocalError(.badMessage) }
        roleSetup.roles[role] = enabled
        changed()
    }

    func addBot(by: String) throws(LocalError) {
        try requireHost(by)
        let taken = Set(players.map(\.name))
        let free = Bots.names.filter { !taken.contains($0) }
        let name = free.isEmpty ? "بوت \(players.count + 1)" : rng.pick(free)
        let look = Bots.look(for: name)
        try join(id: "bot-\(UUID().uuidString.prefix(8))", name: name, gender: look.gender, avatar: look.avatar, isBot: true)
    }

    func setForcedRole(by: String, _ role: RoleID?) throws(LocalError) {
        try requirePhase(.lobby)
        forcedRoles[by] = role
        changed()
    }

    func setFastTimers(by: String, _ enabled: Bool) throws(LocalError) {
        try requireHost(by)
        fastTimers = enabled
        changed()
    }

    // MARK: Game flow

    func start(by: String) throws(LocalError) {
        try requireHost(by)
        try requirePhase(.lobby)
        guard players.count >= Deal.minPlayers else { throw LocalError(.notEnoughPlayers) }

        let roles = Deal.assign(players.map(\.id), rng: rng, forced: forcedRoles, setup: roleSetup)
        for i in players.indices {
            players[i].role = roles[players[i].id]
            players[i].alive = true
        }
        resetGameState()
        narration = rng.narrate(.roleReveal)
        enterPhase(.roleReveal, timings.roleReveal)
    }

    /// After a game: back to the lobby without waiting for the results to time out.
    func playAgain(by: String) throws(LocalError) {
        switch phase {
        case .ended: backToLobby()
        case .lobby: return
        default: throw LocalError(.wrongPhase)
        }
    }

    private func backToLobby() {
        for i in players.indices {
            players[i].alive = true
            players[i].role = nil
        }
        resetGameState()
        chatLog.removeAll()
        narration = nil
        enterPhase(.lobby, nil)
    }

    func nightAction(by: String, targetId: String?) throws(LocalError) {
        try requirePhase(.night)
        guard let actor = player(by), let ability = actor.def?.ability else { throw LocalError(.noNightAction) }
        let core = corePlayers()
        if let error = Night.validate(core, actorId: by, targetId: targetId, history: nightHistory(by)) { throw LocalError(error) }
        if ability.locksOnSubmit, (nightChoices[by] ?? nil) != nil { throw LocalError(.alreadyActed) }

        nightChoices.updateValue(targetId, forKey: by)
        if ability.kind == .inspect, let targetId, let target = player(targetId)?.role {
            inspections[by, default: []].append(
                InspectionResult(round: round, targetId: targetId, isMafia: Night.inspect(core, targetId: targetId), role: RoleCatalog[target].info)
            )
        }
        changed()
    }

    /// What limits this player's night choice: last night's target and any uses left.
    func nightHistory(_ id: String) -> NightHistory {
        let limit = player(id)?.def?.ability?.usesPerGame
        return NightHistory(
            lastTargetId: lastNightChoices[id] ?? nil,
            pastTargetIds: pastTargets[id] ?? [],
            usesLeft: limit.map { max(0, $0 - abilityUses[id, default: 0]) }
        )
    }

    /// Everyone this player may pick tonight.
    func validNightTargets(for id: String) -> [String] {
        let core = corePlayers()
        let history = nightHistory(id)
        return core.filter { Night.validate(core, actorId: id, targetId: $0.id, history: history) == nil }.map(\.id)
    }

    /// The mayor shows their card to everyone; from then on their vote weighs more.
    func revealRole(by: String) throws(LocalError) {
        guard let p = player(by), canRevealRole(p) else { throw LocalError(.cannotReveal) }
        publicReveals.insert(by)
        narration = rng.narrate(.mayorRevealed, name: p.name)
        changed()
    }

    func canRevealRole(_ p: LocalPlayer) -> Bool {
        let revealPhases: Set<GamePhase> = [.morning, .discussion, .voting, .defense, .judgment]
        return revealPhases.contains(phase) && p.alive && p.def?.revealVoteWeight != nil && !publicReveals.contains(p.id)
    }

    /// How many votes this player's vote is worth (a revealed mayor's counts more).
    func voteWeight(_ id: String) -> Int {
        guard publicReveals.contains(id) else { return 1 }
        return player(id)?.def?.revealVoteWeight ?? 1
    }

    func vote(by: String, targetId: String?) throws(LocalError) {
        try requirePhase(.voting)
        guard player(by)?.alive == true else { throw LocalError(.cannotVote) }
        if let targetId {
            guard targetId != by else { throw LocalError(.cannotTargetSelf) }
            guard let target = player(targetId) else { throw LocalError(.invalidTarget) }
            guard target.alive else { throw LocalError(.targetDead) }
        }
        dayVotes.updateValue(targetId, forKey: by)
        closeSoonIfEveryoneDecided()
        changed()
    }

    /// Eliminate or pardon the accused; everyone alive but the accused decides.
    func judge(by: String, _ choice: Judgment) throws(LocalError) {
        try requirePhase(.judgment)
        guard player(by)?.alive == true else { throw LocalError(.cannotVote) }
        guard by != accusedId else { throw LocalError(.cannotJudge) }
        judgments[by] = choice
        closeSoonIfEveryoneDecided()
        changed()
    }

    func chat(by: String, channel: ChatChannel, text: String) throws(LocalError) {
        guard let p = player(by), canWrite(p, channel) else { throw LocalError(.cannotChat) }
        let message = ChatMessage(
            id: UUID().uuidString, channel: channel, senderId: by, senderName: p.name,
            text: String(text.prefix(300)), sentAt: Date().timeIntervalSince1970 * 1000
        )
        chatLog.append(message)
        if chatLog.count > 200 { chatLog.removeFirst() }
        onChat(message)
    }

    var inGame: Bool { phase != .lobby && phase != .ended }

    func canWrite(_ p: LocalPlayer, _ channel: ChatChannel) -> Bool {
        switch channel {
        // Open all the time: anyone in the lobby or after the game, the living during it.
        case .day: inGame ? p.alive : true
        // No private mafia chat: they talk in the open like everyone (the channel stays in the protocol).
        case .mafia: false
        case .dead: !p.alive && inGame
        }
    }

    func canRead(_ p: LocalPlayer, _ channel: ChatChannel) -> Bool {
        switch channel {
        case .day: true
        case .mafia: p.def?.team == .mafia
        case .dead: !p.alive
        }
    }

    func corePlayers() -> [CorePlayer] {
        players.compactMap { p in p.role.map { CorePlayer(id: p.id, role: $0, alive: p.alive) } }
    }

    // MARK: Phases

    private func onPhaseTimeout(_ seq: Int) {
        guard seq == phaseSeq else { return }
        switch phase {
        case .roleReveal: startNight()
        case .night: endNight()
        case .morning: if let pendingWinner { endGame(pendingWinner) } else { startDiscussion() }
        case .discussion: startVoting()
        case .voting: endVoting()
        case .defense: startJudgment()
        case .judgment: endJudgment()
        case .verdict: if let pendingWinner { endGame(pendingWinner) } else { startNight() }
        case .ended: backToLobby()
        case .lobby: break
        }
    }

    private func startNight() {
        if round >= Self.maxRounds { return endGame(.draw) }
        round += 1
        nightChoices.removeAll()
        verdict = nil
        accusedId = nil
        narration = rng.narrate(.nightFalls)
        enterPhase(.night, timings.night)
    }

    private func endNight() {
        let outcome = Night.resolve(corePlayers(), choices: nightChoices, rng: rng)
        // A limited ability is spent only when the night ends with a target chosen.
        for (actorId, targetId) in nightChoices where targetId != nil && player(actorId)?.def?.ability?.usesPerGame != nil {
            abilityUses[actorId, default: 0] += 1
        }
        for id in outcome.killedIds {
            setAlive(id, false)
        }
        lastNightChoices = nightChoices
        for case let (actorId, targetId?) in nightChoices {
            pastTargets[actorId, default: []].insert(targetId)
        }
        lastNightKilledIds = outcome.killedIds
        let morning = outcome.killedIds.isEmpty
            ? [rng.narrate(outcome.attackedIds.isEmpty ? .nobodyDied : .saved)]
            : outLines(.killed, outcome.killedIds)
        narration = ((outcome.shots.isEmpty ? [] : [rng.narrate(.shot)]) + morning).joined(separator: "\n")
        pendingWinner = Voting.winner(corePlayers())
        enterPhase(.morning, timings.morning)
    }

    private func startDiscussion() {
        narration = rng.narrate(.discussion)
        enterPhase(.discussion, fastTimers ? timings.discussion : Double(discussionSeconds))
    }

    private func startVoting() {
        dayVotes.removeAll()
        narration = rng.narrate(.voting)
        enterPhase(.voting, timings.voting)
    }

    /// The most-voted player goes on trial; with no clear leader, nobody leaves.
    private func endVoting() {
        let aliveIds = self.aliveIds()
        let result = Voting.tally(aliveIds: aliveIds, votes: dayVotes) { self.voteWeight($0) }
        verdict = VerdictInfo(
            votes: aliveIds.filter { dayVotes.keys.contains($0) }.map { VoteEntry(voterId: $0, targetId: dayVotes[$0] ?? nil) },
            tally: result.tally,
            abstain: result.abstain,
            eliminatedId: nil,
            reason: result.reason,
            trial: nil
        )
        if let accused = result.eliminatedId {
            accusedId = accused
            narration = rng.narrate(.defense, name: player(accused)?.name ?? "")
            return enterPhase(.defense, timings.defense)
        }
        narration = rng.narrate(.noOneVotedOut)
        pendingWinner = Voting.winner(corePlayers())
        enterPhase(.verdict, timings.verdict)
    }

    private func startJudgment() {
        judgments.removeAll()
        narration = rng.narrate(.judgment, name: player(accusedId)?.name ?? "")
        enterPhase(.judgment, timings.judgment)
    }

    /// More "eliminate" than "pardon" sends the accused out; a tie spares them.
    private func endJudgment() {
        guard let accused = player(accusedId), let previous = verdict else { return startNight() }
        let votes = aliveIds().filter { $0 != accused.id }.compactMap { id in judgments[id].map { JudgmentVote(voterId: id, choice: $0) } }
        let weigh = { (choice: Judgment) in votes.filter { $0.choice == choice }.reduce(0) { $0 + self.voteWeight($1.voterId) } }
        let eliminate = weigh(.eliminate)
        let pardon = weigh(.pardon)
        let eliminated = eliminate > pardon

        if eliminated {
            setAlive(accused.id, false)
            narration = outLines(.votedOut, [accused.id]).joined(separator: "\n")
        } else {
            narration = rng.narrate(.pardoned, name: accused.name)
        }
        verdict = VerdictInfo(
            votes: previous.votes, tally: previous.tally, abstain: previous.abstain,
            eliminatedId: eliminated ? accused.id : nil,
            reason: previous.reason,
            trial: TrialResult(accusedId: accused.id, eliminate: eliminate, pardon: pardon, votes: votes, outcome: eliminated ? "eliminated" : "pardoned")
        )
        pendingWinner = Voting.winner(corePlayers())
        enterPhase(.verdict, timings.verdict)
    }

    private func endGame(_ winner: Winner) {
        self.winner = winner
        pendingWinner = nil
        narration = rng.narrate(.winner(winner))
        enterPhase(.ended, timings.postGame)
        onGameEnded(winner)
    }

    private func enterPhase(_ phase: GamePhase, _ duration: Double?) {
        clearPhaseTimers()
        self.phase = phase
        phaseSeq += 1
        phaseEndsAt = duration.map { Date().addingTimeInterval($0) }
        if let duration { schedulePhaseEnd(after: duration) }
        scheduleBots()
        changed()
    }

    private func schedulePhaseEnd(after seconds: Double) {
        phaseTask?.cancel()
        let seq = phaseSeq
        phaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.onPhaseTimeout(seq)
        }
    }

    private func scheduleBots() {
        let seq = phaseSeq
        for turn in Bots.plan(for: self) {
            botTasks.append(Task { [weak self] in
                try? await Task.sleep(for: .seconds(turn.delay))
                guard !Task.isCancelled, let self, seq == self.phaseSeq else { return }
                // A bot picking something no longer valid is harmless; skip it.
                try? turn.act(self)
            })
        }
    }

    private func clearPhaseTimers() {
        phaseTask?.cancel()
        phaseTask = nil
        botTasks.forEach { $0.cancel() }
        botTasks.removeAll()
    }

    private func resetGameState() {
        round = 0
        nightChoices.removeAll()
        lastNightChoices.removeAll()
        pastTargets.removeAll()
        inspections.removeAll()
        abilityUses.removeAll()
        publicReveals.removeAll()
        dayVotes.removeAll()
        accusedId = nil
        judgments.removeAll()
        lastNightKilledIds = []
        verdict = nil
        winner = nil
        pendingWinner = nil
    }

    func aliveIds() -> [String] {
        players.filter { $0.alive && $0.role != nil }.map(\.id)
    }

    private func setAlive(_ id: String, _ alive: Bool) {
        if let i = players.firstIndex(where: { $0.id == id }) { players[i].alive = alive }
    }

    /// Everyone has voted (or judged): rather than closing at once, give a few
    /// seconds in which anyone can still change their mind.
    private func closeSoonIfEveryoneDecided() {
        let alive = aliveIds()
        let decided = (phase == .voting && alive.allSatisfy { dayVotes.keys.contains($0) })
            || (phase == .judgment && alive.allSatisfy { $0 == accusedId || judgments[$0] != nil })
        guard decided else { return }
        let grace = timings.voteGrace
        if let phaseEndsAt, phaseEndsAt.timeIntervalSinceNow <= grace { return }
        phaseEndsAt = Date().addingTimeInterval(grace)
        schedulePhaseEnd(after: grace)
    }

    /// One line per player who is out, each turning their card over.
    private func outLines(_ key: Narration, _ ids: [String]) -> [String] {
        ids.compactMap(player).map { rng.narrate(key, name: $0.name, role: $0.def?.name ?? "") }
    }

    // MARK: Guards

    private func changed() {
        onChange()
    }

    private func requireHost(_ id: String) throws(LocalError) {
        guard player(id) != nil else { throw LocalError(.notInRoom) }
        guard id == hostId else { throw LocalError(.notHost) }
    }

    private func requirePhase(_ phase: GamePhase) throws(LocalError) {
        guard self.phase == phase else { throw LocalError(.wrongPhase) }
    }
}
