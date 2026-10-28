import Foundation

/// The whole game on the device: takes the same messages the online app sends
/// its server and answers with the same messages, so `GameStore` and every
/// screen work unchanged. One room at a time, you plus bots.
@MainActor
final class LocalGameService: GameService {
    static let playerId = "me"

    let events: AsyncStream<ServiceEvent>
    private let continuation: AsyncStream<ServiceEvent>.Continuation
    private let rng: GameRandom
    private let stats: LocalStats
    private var profile = Profile(nickname: "", gender: .male, avatar: "m1")
    private(set) var room: LocalRoom?
    /// Lets tests run whole games in moments.
    var timings: PhaseTimings?

    init(rng: GameRandom = GameRandom(), stats: LocalStats = LocalStats()) {
        self.rng = rng
        self.stats = stats
        (events, continuation) = AsyncStream.makeStream()
    }

    func connect(profile: Profile, token: String?) {
        self.profile = profile
        continuation.yield(.status(.connected))
        welcome()
    }

    func updateIdentity(profile: Profile, token: String?) {
        self.profile = profile
    }

    func disconnect() {
        continuation.yield(.status(.disconnected))
    }

    func send(_ message: ClientMessage) {
        do {
            try handle(message)
        } catch {
            emit(.error(code: error.code.rawValue, message: error.code.message))
        }
    }

    private func handle(_ message: ClientMessage) throws(LocalError) {
        let me = Self.playerId
        switch message {
        case let .hello(_, profile):
            self.profile = profile
            return welcome()
        case let .updateProfile(profile):
            self.profile = profile
            return
        case let .watchRooms(on):
            if on { emit(.rooms([])) }
            return
        case let .createRoom(name, capacity, _):
            return try createRoom(name: name, capacity: capacity)
        case .joinRoom:
            throw LocalError(.roomNotFound)
        case .leaveRoom:
            room?.dispose()
            room = nil
            return sendState()
        default:
            break
        }

        guard let room else { throw LocalError(.notInRoom) }
        switch message {
        case let .renameRoom(name): try room.rename(by: me, to: name)
        case let .kick(playerId): try room.kick(by: me, targetId: playerId)
        // Bots can't lead a room, and there's nobody else to hand it to.
        case .transferHost: throw LocalError(.invalidTarget)
        case let .setDiscussionSeconds(seconds): try room.setDiscussionSeconds(by: me, seconds)
        case let .setMafiaCount(count): try room.setMafiaCount(by: me, count)
        case let .setRoleEnabled(role, enabled): try room.setRoleEnabled(by: me, role, enabled)
        case .startGame: try room.start(by: me)
        case let .nightAction(targetId): try room.nightAction(by: me, targetId: targetId)
        case let .vote(targetId): try room.vote(by: me, targetId: targetId)
        case let .judge(choice): try room.judge(by: me, choice)
        case .revealRole: try room.revealRole(by: me)
        case let .chat(channel, text): try room.chat(by: me, channel: channel, text: text)
        case .playAgain: try room.playAgain(by: me)
        case .addBot: try room.addBot(by: me)
        case let .devSetRole(role): try room.setForcedRole(by: me, role)
        case let .devFastTimers(enabled): try room.setFastTimers(by: me, enabled)
        case .hello, .updateProfile, .watchRooms, .createRoom, .joinRoom, .leaveRoom: break
        }
    }

    /// A room of my own, the other seats filled with bots.
    private func createRoom(name: String?, capacity: Int) throws(LocalError) {
        guard room == nil else { throw LocalError(.alreadyInRoom) }
        let code = String(format: "%06d", rng.int(1_000_000))
        let room = LocalRoom(code: code, name: name ?? "غرفة \(profile.nickname)", capacity: capacity, rng: rng)
        if let timings {
            room.normalTimings = timings
            room.fastTimings = timings
        }
        room.onChange = { [weak self, weak room] in
            guard let self, let room, room === self.room else { return }
            self.sendState()
        }
        room.onChat = { [weak self, weak room] message in
            guard let self, let room, room === self.room, let me = room.player(Self.playerId), room.canRead(me, message.channel) else { return }
            self.emit(.chat(message))
        }
        room.onGameEnded = { [weak self, weak room] winner in
            guard let self, let room, let me = room.player(Self.playerId)?.def else { return }
            // Games with a role picked in the dev tools don't count.
            guard room.forcedRoles.isEmpty else { return }
            self.emit(.stats(self.stats.record(team: me.team, winner: winner)))
        }
        self.room = room
        try room.join(id: Self.playerId, name: profile.nickname, gender: profile.gender, avatar: profile.avatar)
        while room.players.count < room.capacity {
            try room.addBot(by: Self.playerId)
        }
        emit(.chatHistory([]))
    }

    private func welcome() {
        emit(.welcome(playerId: Self.playerId, token: "local", debugEnabled: true, maintenance: false, stats: stats.current))
        if let room { emit(.chatHistory(room.chatHistory(for: Self.playerId))) }
        sendState()
    }

    private func sendState() {
        emit(.state(room: room?.snapshot(), me: room?.privateSnapshot(for: Self.playerId)))
    }

    private func emit(_ message: ServerMessage) {
        continuation.yield(.message(message))
    }
}

/// Games played and won on this device.
@MainActor
final class LocalStats {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: PlayerStats {
        PlayerStats(
            games: defaults.integer(forKey: "stats.games"),
            wins: defaults.integer(forKey: "stats.wins"),
            mafiaGames: defaults.integer(forKey: "stats.mafiaGames"),
            mafiaWins: defaults.integer(forKey: "stats.mafiaWins")
        )
    }

    func record(team: Team, winner: Winner) -> PlayerStats {
        let won = winner.rawValue == team.rawValue
        let old = current
        let new = PlayerStats(
            games: old.games + 1,
            wins: old.wins + (won ? 1 : 0),
            mafiaGames: old.mafiaGames + (team == .mafia ? 1 : 0),
            mafiaWins: old.mafiaWins + (team == .mafia && won ? 1 : 0)
        )
        defaults.set(new.games, forKey: "stats.games")
        defaults.set(new.wins, forKey: "stats.wins")
        defaults.set(new.mafiaGames, forKey: "stats.mafiaGames")
        defaults.set(new.mafiaWins, forKey: "stats.mafiaWins")
        return new
    }
}
