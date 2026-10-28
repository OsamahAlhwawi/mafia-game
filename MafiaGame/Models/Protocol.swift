import Foundation

/// Must match the server's PROTOCOL_VERSION; an older app is asked to update.
let protocolVersion = 4

// The messages between the app and the narrator: `LocalGameService` in this
// build, a game server in the online one. The JSON in fixtures/ was recorded
// from that server and is decoded in FixtureDecodingTests.

enum GamePhase: String, Codable, Sendable {
    case lobby, roleReveal, night, morning, discussion, voting, defense, judgment, verdict, ended
}

enum Team: String, Codable, Sendable {
    case mafia, town
}

enum Winner: String, Codable, Sendable {
    /// `draw`: the round limit ran out.
    case mafia, town, draw
}

enum Gender: String, Codable, Sendable, CaseIterable {
    case male, female
}

/// Who the player is: sent with every `hello`.
struct Profile: Codable, Equatable, Sendable {
    var nickname: String
    var gender: Gender
    /// A bundled avatar: m1…m8 or f1…f8.
    var avatar: String
}

struct PlayerStats: Codable, Hashable, Sendable {
    let games: Int
    let wins: Int
    let mafiaGames: Int
    let mafiaWins: Int

    static let zero = PlayerStats(games: 0, wins: 0, mafiaGames: 0, mafiaWins: 0)
}

/// A public room on the rooms screen.
struct RoomListing: Codable, Identifiable, Hashable, Sendable {
    enum Status: String, Codable, Sendable { case open, full, playing }

    let code: String
    let name: String
    let hostName: String
    let hostAvatar: String
    let count: Int
    let capacity: Int
    let status: Status
    let round: Int

    var id: String { code }
}

enum ChatChannel: String, Codable, Sendable, CaseIterable {
    case day, mafia, dead
}

/// Open set of role ids, so a role added on the server decodes before the app knows it.
struct RoleID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let mafia = RoleID(rawValue: "mafia")
    static let doctor = RoleID(rawValue: "doctor")
    static let detective = RoleID(rawValue: "detective")
    static let officer = RoleID(rawValue: "officer")
    static let mayor = RoleID(rawValue: "mayor")
    static let citizen = RoleID(rawValue: "citizen")
}

/// Open set of night ability kinds, for the same reason as `RoleID`.
struct AbilityKind: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let teamKill = AbilityKind(rawValue: "teamKill")
    static let protect = AbilityKind(rawValue: "protect")
    static let inspect = AbilityKind(rawValue: "inspect")
    static let shoot = AbilityKind(rawValue: "shoot")
}

struct PublicPlayer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let alive: Bool
    let connected: Bool
    let isBot: Bool
    let isHost: Bool
    let gender: Gender
    let avatar: String
    /// Still on the last game's results; hasn't chosen to play again yet.
    let pending: Bool
}

struct RoleInfo: Codable, Hashable, Sendable {
    let id: RoleID
    let name: String
    let description: String
    /// Longer explanation for the rules & cards screen.
    let details: String
    let team: Team
    let abilityKind: AbilityKind?
}

struct VoteEntry: Codable, Hashable, Sendable {
    let voterId: String
    let targetId: String?
}

struct TallyEntry: Codable, Hashable, Sendable {
    let targetId: String
    let count: Int
}

/// A player whose vote counts more than once (a revealed mayor).
struct VoteWeight: Codable, Hashable, Sendable {
    let playerId: String
    let weight: Int
}

enum Judgment: String, Codable, Sendable {
    case eliminate, pardon
}

struct JudgmentVote: Codable, Hashable, Sendable {
    let voterId: String
    let choice: Judgment
}

struct TrialResult: Codable, Hashable, Sendable {
    let accusedId: String
    let eliminate: Int
    let pardon: Int
    let votes: [JudgmentVote]
    /// "eliminated" or "pardoned".
    let outcome: String
}

struct JudgmentCounts: Codable, Hashable, Sendable {
    let eliminate: Int
    let pardon: Int
    /// Who chose what, shown live like a show of hands.
    let votes: [JudgmentVote]
}

struct VerdictInfo: Codable, Hashable, Sendable {
    let votes: [VoteEntry]
    let tally: [TallyEntry]
    let abstain: Int
    let eliminatedId: String?
    let reason: String
    let trial: TrialResult?
}

struct RoomSettings: Codable, Hashable, Sendable {
    let discussionSeconds: Int
    let fastTimers: Bool
    let minPlayers: Int
    let maxPlayers: Int
    let mafia: MafiaSetting
    /// Town roles the host can turn on or off.
    let optionalRoles: [OptionalRole]
}

struct MafiaSetting: Codable, Hashable, Sendable {
    /// The host's choice; nil follows the player count.
    let count: Int?
    /// The most allowed with the players seated now.
    let max: Int
}

struct OptionalRole: Codable, Hashable, Sendable {
    let role: RoleInfo
    /// Dealt with the players seated now.
    let enabled: Bool
}

struct DeckEntry: Codable, Hashable, Sendable {
    let role: RoleInfo
    let count: Int
}

struct RevealedRole: Codable, Hashable, Sendable {
    let playerId: String
    let role: RoleInfo
}

struct RoomSnapshot: Codable, Hashable, Sendable {
    let code: String
    let name: String
    let isPrivate: Bool
    let hostId: String
    let phase: GamePhase
    let phaseSeq: Int
    /// Epoch milliseconds, server clock.
    let phaseEndsAt: Double?
    let serverNow: Double
    let round: Int
    let settings: RoomSettings
    let players: [PublicPlayer]
    let narration: String?
    let lastNightKilledIds: [String]
    let votedIds: [String]
    /// Votes each player has right now, while voting is open.
    let liveTally: [TallyEntry]
    /// How many have chosen to abstain so far.
    let liveAbstain: Int
    /// The most-voted player, during the defense, judgment and verdict.
    let accusedId: String?
    /// Live eliminate/pardon counts during the judgment.
    let judgment: JudgmentCounts?
    let verdict: VerdictInfo?
    let winner: Winner?
    /// Cards in play for this many players.
    let deck: [DeckEntry]
    let revealedRoles: [RevealedRole]?
    /// Players whose vote counts more than once (a revealed mayor).
    var voteWeights: [VoteWeight] = []

    func player(_ id: String?) -> PublicPlayer? {
        players.first { $0.id == id }
    }

    func voteWeight(of id: String) -> Int {
        voteWeights.first { $0.playerId == id }?.weight ?? 1
    }
}

struct Teammate: Codable, Hashable, Sendable {
    let id: String
    let name: String
}

struct TeamChoice: Codable, Hashable, Sendable {
    let actorId: String
    let targetId: String?
}

struct InspectionResult: Codable, Hashable, Sendable {
    let round: Int
    let targetId: String
    let isMafia: Bool
    /// The target's card, flipped for the detective only.
    let role: RoleInfo
}

struct PrivateSnapshot: Codable, Hashable, Sendable {
    let playerId: String
    let role: RoleInfo?
    let alive: Bool
    let teammates: [Teammate]?
    let teamChoices: [TeamChoice]?
    let myNightTarget: String?
    let validTargetIds: [String]
    let nightActionLocked: Bool
    let inspections: [InspectionResult]
    let myVote: String?
    let myJudgment: Judgment?
    let writableChannels: [ChatChannel]
    let forcedRole: RoleID?
    /// Debug tools are allowed for this player.
    let canDebug: Bool
    /// Uses left of a limited night ability (the officer's bullet); nil when unlimited or none.
    var abilityUsesLeft: Int? = nil
    /// This player may reveal their card right now (the mayor, by day).
    var canRevealRole: Bool = false
}

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let channel: ChatChannel
    let senderId: String
    let senderName: String
    let text: String
    let sentAt: Double
}

// MARK: - Server → client

enum ServerMessage: Decodable, Sendable {
    case welcome(playerId: String, token: String, debugEnabled: Bool, maintenance: Bool, stats: PlayerStats)
    /// The admin changed something that affects this player.
    case serverStatus(debugEnabled: Bool, maintenance: Bool)
    case rooms([RoomListing])
    case stats(PlayerStats)
    /// Something a state change alone doesn't explain (kicked, room closed).
    case notice(String)
    case state(room: RoomSnapshot?, me: PrivateSnapshot?)
    case chatHistory([ChatMessage])
    case chat(ChatMessage)
    case error(code: String, message: String)
    /// A message type this build doesn't know; ignored.
    case unknown(String)

    private enum CodingKeys: String, CodingKey {
        case type, playerId, token, debugEnabled, maintenance, stats, rooms, text, room, me, messages, message, code
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "welcome":
            self = .welcome(
                playerId: try c.decode(String.self, forKey: .playerId),
                token: try c.decode(String.self, forKey: .token),
                debugEnabled: try c.decode(Bool.self, forKey: .debugEnabled),
                maintenance: try c.decode(Bool.self, forKey: .maintenance),
                stats: try c.decode(PlayerStats.self, forKey: .stats)
            )
        case "serverStatus":
            self = .serverStatus(
                debugEnabled: try c.decode(Bool.self, forKey: .debugEnabled),
                maintenance: try c.decode(Bool.self, forKey: .maintenance)
            )
        case "rooms":
            self = .rooms(try c.decode([RoomListing].self, forKey: .rooms))
        case "stats":
            self = .stats(try c.decode(PlayerStats.self, forKey: .stats))
        case "notice":
            self = .notice(try c.decode(String.self, forKey: .text))
        case "state":
            self = .state(
                room: try c.decodeIfPresent(RoomSnapshot.self, forKey: .room),
                me: try c.decodeIfPresent(PrivateSnapshot.self, forKey: .me)
            )
        case "chatHistory":
            self = .chatHistory(try c.decode([ChatMessage].self, forKey: .messages))
        case "chat":
            self = .chat(try c.decode(ChatMessage.self, forKey: .message))
        case "error":
            self = .error(code: try c.decode(String.self, forKey: .code), message: try c.decode(String.self, forKey: .message))
        default:
            self = .unknown(type)
        }
    }
}

// MARK: - Client → server

enum ClientMessage: Encodable, Equatable, Sendable {
    case hello(token: String?, profile: Profile)
    case updateProfile(Profile)
    case watchRooms(Bool)
    case createRoom(name: String?, capacity: Int, isPrivate: Bool)
    case joinRoom(code: String)
    case leaveRoom
    case renameRoom(String)
    case transferHost(playerId: String)
    case kick(playerId: String)
    case setDiscussionSeconds(Int)
    case setMafiaCount(Int?)
    case setRoleEnabled(RoleID, Bool)
    case startGame
    case nightAction(targetId: String?)
    case vote(targetId: String?)
    case judge(Judgment)
    case revealRole
    case chat(channel: ChatChannel, text: String)
    case playAgain
    case addBot
    case devSetRole(RoleID?)
    case devFastTimers(Bool)

    private enum CodingKeys: String, CodingKey {
        case type, protocolVersion = "protocol", token, nickname, gender, avatar, on, name, capacity, isPrivate
        case code, playerId, seconds, count, targetId, channel, text, role, enabled, choice
    }

    private func encode(_ profile: Profile, into c: inout KeyedEncodingContainer<CodingKeys>) throws {
        try c.encode(profile.nickname, forKey: .nickname)
        try c.encode(profile.gender, forKey: .gender)
        try c.encode(profile.avatar, forKey: .avatar)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .hello(token, profile):
            try c.encode("hello", forKey: .type)
            try c.encode(protocolVersion, forKey: .protocolVersion)
            try c.encodeIfPresent(token, forKey: .token)
            try encode(profile, into: &c)
        case let .updateProfile(profile):
            try c.encode("updateProfile", forKey: .type)
            try encode(profile, into: &c)
        case let .watchRooms(on):
            try c.encode("watchRooms", forKey: .type)
            try c.encode(on, forKey: .on)
        case let .createRoom(name, capacity, isPrivate):
            try c.encode("createRoom", forKey: .type)
            try c.encodeIfPresent(name, forKey: .name)
            try c.encode(capacity, forKey: .capacity)
            try c.encode(isPrivate, forKey: .isPrivate)
        case let .renameRoom(name):
            try c.encode("renameRoom", forKey: .type)
            try c.encode(name, forKey: .name)
        case let .transferHost(playerId):
            try c.encode("transferHost", forKey: .type)
            try c.encode(playerId, forKey: .playerId)
        case let .joinRoom(code):
            try c.encode("joinRoom", forKey: .type)
            try c.encode(code, forKey: .code)
        case .leaveRoom:
            try c.encode("leaveRoom", forKey: .type)
        case let .kick(playerId):
            try c.encode("kick", forKey: .type)
            try c.encode(playerId, forKey: .playerId)
        case let .setDiscussionSeconds(seconds):
            try c.encode("setDiscussionSeconds", forKey: .type)
            try c.encode(seconds, forKey: .seconds)
        case let .setMafiaCount(count):
            // nil is sent as JSON null: back to the player count.
            try c.encode("setMafiaCount", forKey: .type)
            try c.encode(count, forKey: .count)
        case let .setRoleEnabled(role, enabled):
            try c.encode("setRoleEnabled", forKey: .type)
            try c.encode(role, forKey: .role)
            try c.encode(enabled, forKey: .enabled)
        case .startGame:
            try c.encode("startGame", forKey: .type)
        case let .nightAction(targetId):
            // The server requires the key; nil is sent as JSON null (skip / withdraw).
            try c.encode("nightAction", forKey: .type)
            try c.encode(targetId, forKey: .targetId)
        case let .vote(targetId):
            try c.encode("vote", forKey: .type)
            try c.encode(targetId, forKey: .targetId)
        case let .judge(choice):
            try c.encode("judge", forKey: .type)
            try c.encode(choice, forKey: .choice)
        case .revealRole:
            try c.encode("revealRole", forKey: .type)
        case let .chat(channel, text):
            try c.encode("chat", forKey: .type)
            try c.encode(channel, forKey: .channel)
            try c.encode(text, forKey: .text)
        case .playAgain:
            try c.encode("playAgain", forKey: .type)
        case .addBot:
            try c.encode("addBot", forKey: .type)
        case let .devSetRole(role):
            try c.encode("devSetRole", forKey: .type)
            try c.encode(role, forKey: .role)
        case let .devFastTimers(enabled):
            try c.encode("devFastTimers", forKey: .type)
            try c.encode(enabled, forKey: .enabled)
        }
    }
}
