import Foundation
import Observation

/// One player's place at the table.
struct Seat: Identifiable, Equatable {
    enum Face: Equatable {
        case hidden
        case role(RoleInfo)
    }

    enum ActionKind: Equatable {
        case kill, protect, inspect, shoot, vote, reveal, other
    }

    struct Action: Equatable {
        let kind: ActionKind
        let enabled: Bool

        var label: String {
            switch kind {
            case .kill: "اقتل"
            case .protect: "احمِ"
            case .inspect: "حقق"
            case .shoot: "أطلق"
            case .vote: "صوّت"
            case .reveal: "اكشف كرتك"
            case .other: "اختر"
            }
        }
    }

    let id: String
    let name: String
    let isMe: Bool
    let alive: Bool
    let connected: Bool
    var avatar: String?
    var face: Face = .hidden
    var action: Action?
    var selected = false
    /// Teammates who picked this player tonight ("أنت" for me).
    var picks: [String] = []
    /// Votes received, once revealed.
    var voteCount: Int?
    /// How many votes this player's vote is worth, when more than one (a revealed mayor).
    var voteWeight: Int?
    /// The detective's private finding about this player.
    var inspectedMafia: Bool?
    /// Just died / was voted out in this announcement.
    var justOut = false
    /// On trial: defending themself or awaiting the eliminate/pardon decision.
    var accused = false
    /// Defending right now: the card trembles.
    var shaking = false
}

/// What the card-info sheet shows for a tapped seat.
struct CardInfo: Equatable {
    let playerName: String
    /// Nil when this card is still face down for me.
    let role: RoleInfo?
    /// Why I can see it, or the player's state ("هذا كرتك", "طلع من اللعبة"...).
    let note: String?
    let alive: Bool
    var avatar: String?
}

/// Everything the table screen shows, built from the store per phase.
@MainActor
@Observable
final class BoardViewModel {
    private let store: GameStore
    private let night: NightViewModel
    private let voting: VotingViewModel
    private let end: EndViewModel

    init(store: GameStore) {
        self.store = store
        night = NightViewModel(store: store)
        voting = VotingViewModel(store: store)
        end = EndViewModel(store: store)
    }

    var phase: GamePhase { store.room?.phase ?? .lobby }
    var myRole: RoleInfo? { store.me?.role }
    var amAlive: Bool { store.me?.alive ?? false }
    var isHost: Bool { store.isHost }
    var log: [LogEntry] { store.log }
    var deck: [DeckEntry] { store.room?.deck ?? [] }
    var round: Int { store.room?.round ?? 1 }
    var narration: String? { store.room?.narration }

    /// Who died last night, with their (now revealed) cards, for the morning announcement.
    var lastNightVictims: [(name: String, id: String, role: RoleInfo?)] {
        guard let room = store.room else { return [] }
        let revealed = Dictionary(uniqueKeysWithValues: (room.revealedRoles ?? []).map { ($0.playerId, $0.role) })
        return room.lastNightKilledIds.map { (name: store.name(of: $0), id: $0, role: revealed[$0]) }
    }
    var phaseEndsAt: Date? { store.phaseEndsAt }
    var phaseTotal: TimeInterval { store.phaseTotal }

    var title: String {
        let round = store.room?.round ?? 1
        switch phase {
        case .roleReveal: return "كشف الأدوار"
        case .night: return "الليلة \(round)"
        case .morning: return "صباح اليوم \(round)"
        case .discussion: return "النقاش"
        case .voting: return "تصويت النهار"
        case .defense: return "الدفاع"
        case .judgment: return "إقصاء أو إعفاء؟"
        case .verdict: return "نتيجة التصويت"
        case .ended: return end.title
        case .lobby: return ""
        }
    }

    /// One line under the title telling me what to do now.
    var instruction: String? {
        switch phase {
        case .night:
            switch night.mode {
            case .team:
                if night.myTarget == nil { return "اختاروا الضحية من الطاولة" }
                return teamTied ? "تعادلتوا! بينختار واحد من اختياراتكم عشوائياً" : "اختيارك وصل لفريقك. تقدر تغيّره"
            case .single(.protect): return night.myTarget == nil ? "اختر شخص تحميه" : "بتحميه الليلة. تقدر تغيّر"
            case .single(.inspect): return night.locked ? "انقلب لك كرته، شوفه على الطاولة" : "اختر شخص تقلب كرته"
            case .single(.shoot): return night.myTarget == nil ? "تطلق رصاصتك الليلة؟ ولا تخليها لبعدين" : "بتنطلق الرصاصة مع الصبح. تقدر تغيّر أو تلغي"
            case .single: return "اختر لاعب"
            case .waiting:
                if !amAlive { return "أنت تشاهد" }
                return night.abilitySpent ? "استخدمت رصاصتك... انتظر الصباح" : "المدينة نايمة... انتظر الصباح"
            }
        case .voting:
            guard voting.canVote else { return "أنت تشاهد التصويت" }
            return voting.hasVoted ? (voting.abstained ? "امتنعت. تقدر تغيّر لين ينتهي الوقت" : "صوتك وصل. تقدر تغيّره") : "اضغط «صوّت» على اللي تشك فيه"
        case .discussion: return amAlive ? "تناقشوا... مين المافيا؟" : "أنت تشاهد النقاش"
        case .defense:
            return isAccused ? "الأصوات عليك! دافع عن نفسك في الشات" : "اسمعوا دفاع \(accusedName)"
        case .judgment:
            if isAccused { return "المدينة تقرر مصيرك..." }
            guard canJudge else { return "أنت تشاهد الحكم" }
            return myJudgment == nil ? "تقصي \(accusedName) ولا تعفي عنه؟" : "اخترت. تقدر تغيّر لين ينتهي الوقت"
        case .ended: return end.winner == .draw ? "ما فاز أحد هالمرة" : end.iWon ? "مبروك، فزت! 🎉" : "حظ أوفر المرة الجاية"
        default: return nil
        }
    }

    var canAbstain: Bool { phase == .voting && voting.canVote }
    /// The dead (and anyone else watching) see the abstentions without a button.
    var watchesVoting: Bool { phase == .voting && !voting.canVote }

    // MARK: Revealing my card (the mayor)

    var canRevealRole: Bool { store.me?.canRevealRole ?? false }
    func revealRole() { if canRevealRole { store.revealRole() } }

    /// The mafia's picks are split evenly between more than one target.
    var teamTied: Bool {
        let counts = Dictionary(grouping: (store.me?.teamChoices ?? []).compactMap(\.targetId), by: { $0 }).mapValues(\.count)
        guard let top = counts.values.max() else { return false }
        return counts.values.filter { $0 == top }.count > 1
    }

    // MARK: Trial

    var accusedId: String? { store.room?.accusedId }
    var accusedName: String { store.name(of: accusedId) }
    var isAccused: Bool { accusedId != nil && accusedId == store.playerId }
    var canJudge: Bool { phase == .judgment && amAlive && !isAccused }
    var myJudgment: Judgment? { store.me?.myJudgment }
    var judgmentCounts: JudgmentCounts { store.room?.judgment ?? JudgmentCounts(eliminate: 0, pardon: 0, votes: []) }

    /// Names of who chose `choice` so far.
    func judges(_ choice: Judgment) -> [PublicPlayer] {
        judgmentCounts.votes.filter { $0.choice == choice }.compactMap { store.player($0.voterId) }
    }
    var accusedAvatar: String? { store.player(accusedId)?.avatar }
    func avatar(of playerId: String) -> String? { store.player(playerId)?.avatar }
    func judge(_ choice: Judgment) { if canJudge { store.judge(choice) } }
    var abstained: Bool { voting.abstained }
    var abstainCount: Int { store.room?.liveAbstain ?? 0 }
    /// Living players who haven't voted yet (if time runs out they simply have no say).
    var notVotedCount: Int { max(0, voting.aliveCount - voting.votedCount) }
    func abstain() { voting.abstain() }

    func playAgain() { store.playAgain() }
    func leave() { store.leaveRoom() }

    // MARK: Seats

    var mySeat: Seat? { seats(includeMe: true).first { $0.isMe } }
    var otherSeats: [Seat] { seats(includeMe: true).filter { !$0.isMe } }

    private func seats(includeMe: Bool) -> [Seat] {
        guard let room = store.room, let myId = store.playerId else { return [] }
        let nightRows = Dictionary(uniqueKeysWithValues: (night.mode == .waiting ? [] : night.rows).map { ($0.id, $0) })
        let teammateIds = Set((store.me?.teammates ?? []).map(\.id))
        let revealed = Dictionary(uniqueKeysWithValues: (room.revealedRoles ?? []).map { ($0.playerId, $0.role) })
        let tally = Dictionary(uniqueKeysWithValues: (room.verdict?.tally ?? []).map { ($0.targetId, $0.count) })
        let liveTally = Dictionary(uniqueKeysWithValues: room.liveTally.map { ($0.targetId, $0.count) })
        let inspected = Dictionary((store.me?.inspections ?? []).map { ($0.targetId, $0) }, uniquingKeysWith: { _, new in new })

        return room.players.map { player in
            let isMe = player.id == myId
            var seat = Seat(id: player.id, name: player.name, isMe: isMe, alive: player.alive, connected: player.connected, avatar: player.avatar)

            if let role = revealed[player.id] {
                seat.face = .role(role)
            } else if isMe, let role = myRole {
                seat.face = .role(role)
            } else if teammateIds.contains(player.id), let role = myRole {
                // Teammates know each other's side; show them as our team's card.
                seat.face = .role(role)
            } else if let found = inspected[player.id] {
                // The detective's card flips for them alone.
                seat.face = .role(found.role)
            }
            seat.inspectedMafia = inspected[player.id]?.isMafia
            let weight = room.voteWeight(of: player.id)
            if player.alive && weight > 1 { seat.voteWeight = weight }

            switch phase {
            case .night:
                // On my own card, only show an action I can actually take (the doctor protecting themself).
                if let row = nightRows[player.id], !isMe || row.enabled || row.selected {
                    seat.action = Seat.Action(kind: actionKind(myRole?.abilityKind), enabled: row.enabled && !night.locked)
                    seat.selected = row.selected
                    seat.picks = row.pickedBy
                    // The mafia see how many of them picked each target, like the day vote.
                    if night.mode == .team, !row.pickedBy.isEmpty { seat.voteCount = row.pickedBy.count }
                }
            case .voting:
                if voting.canVote && player.alive && !isMe {
                    seat.action = Seat.Action(kind: .vote, enabled: true)
                    seat.selected = voting.myVote == player.id
                }
                seat.voteCount = liveTally[player.id]
            case .defense, .judgment:
                seat.accused = room.accusedId == player.id
                seat.shaking = phase == .defense && seat.accused
            case .verdict:
                seat.voteCount = tally[player.id]
                seat.justOut = room.verdict?.eliminatedId == player.id
            case .morning:
                seat.justOut = room.lastNightKilledIds.contains(player.id)
            default:
                break
            }
            return seat
        }
    }

    /// The explanation for a tapped card: the role if I can see it, otherwise "unknown".
    func cardInfo(for seat: Seat) -> CardInfo {
        let teammate = (store.me?.teammates ?? []).contains { $0.id == seat.id }
        let inspected = (store.me?.inspections ?? []).contains { $0.targetId == seat.id }
        let note: String? =
            if seat.isMe { "هذا كرتك" }
            else if !seat.alive { "طلع من اللعبة وانكشف كرته" }
            else if phase == .ended { nil }
            else if let weight = seat.voteWeight { "كشف كرته قدام الكل، وصوته بـ\(weight)" }
            else if teammate { "من فريقك 🎭" }
            else if inspected { "كشفت كرته بتحقيقك 🔍" }
            else { nil }
        if case let .role(role) = seat.face {
            return CardInfo(playerName: seat.name, role: role, note: note, alive: seat.alive, avatar: seat.avatar)
        }
        return CardInfo(playerName: seat.name, role: nil, note: note, alive: seat.alive, avatar: seat.avatar)
    }

    private func actionKind(_ kind: AbilityKind?) -> Seat.ActionKind {
        switch kind {
        case .teamKill?: .kill
        case .protect?: .protect
        case .inspect?: .inspect
        case .shoot?: .shoot
        default: .other
        }
    }

    func tap(_ seat: Seat) {
        guard let action = seat.action else { return }
        switch phase {
        case .night:
            guard let row = night.rows.first(where: { $0.id == seat.id }) else { return }
            night.tap(row)
        case .voting:
            guard action.enabled, !seat.selected else { return }
            voting.vote(for: seat.id)
        default:
            break
        }
    }

    // MARK: Chat

    /// Channels I may write to now (as the server says); the first is the default.
    var writableChannels: [ChatChannel] {
        let writable = store.me?.writableChannels ?? []
        return [ChatChannel.mafia, .dead, .day].filter { writable.contains($0) }
    }

    /// Where my messages go by default, if anywhere.
    var chatChannel: ChatChannel? { writableChannels.first }

    var chatPlaceholder: String {
        switch chatChannel {
        case .mafia?: "اكتب لفريقك بالسر..."
        case .dead?: "دردش مع اللي طلعوا..."
        case .day?: "قل اللي في بالك..."
        case nil: phase == .night ? "الشات مقفل بالليل" : "الشات مقفل الحين"
        }
    }

    var chat: [ChatMessage] { store.chat }
    var myId: String? { store.playerId }

    func send(_ text: String, channel: ChatChannel? = nil) {
        guard let channel = channel ?? chatChannel, writableChannels.contains(channel) else { return }
        store.sendChat(text, channel: channel)
    }

    /// How long a message stays on the table, and how many show at once.
    static let feedLifetime: TimeInterval = 4
    static let feedLimit = 3

    /// The messages floating over the table right now: the newest few, each fading after a while.
    func recentMessages(now: Date) -> [ChatMessage] {
        let serverNowMs = (now.timeIntervalSince1970 + store.clockOffset) * 1000
        return Array(store.chat.filter { serverNowMs - $0.sentAt < Self.feedLifetime * 1000 }.suffix(Self.feedLimit))
    }
}
