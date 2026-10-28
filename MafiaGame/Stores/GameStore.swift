import Foundation
import Observation

/// One line on the narrator's scroll, or a divider between nights and days.
struct LogEntry: Identifiable, Equatable {
    /// How a line reads at a glance.
    enum Tone: Equatable {
        case neutral
        /// Someone was killed or voted out: shown in red.
        case danger
        /// Only this player sees it (the detective's findings).
        case secret
        /// «الليلة ٢», «النهار ٢»: not a line, a separator.
        case divider
    }

    let id: Int
    let text: String
    let tone: Tone

    var isPrivate: Bool { tone == .secret }
}

struct AppError: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let message: String
}

/// Holds the latest server snapshots and turns user intents into messages.
/// The server is the source of truth; this never computes game results.
@MainActor
@Observable
final class GameStore {
    private(set) var status: ConnectionStatus = .disconnected
    private(set) var playerId: String?
    /// The admin allowed this player the debug tools (everyone, on a local dev server).
    private(set) var debugEnabled = false
    /// Closed for maintenance: no new rooms.
    private(set) var maintenance = false
    private(set) var stats = PlayerStats.zero
    /// Public rooms, while the rooms screen is watching.
    private(set) var roomList: [RoomListing] = []
    /// The server no longer speaks this app's protocol.
    private(set) var updateRequired = false
    /// The server refused the nickname: ask for another before going on.
    private(set) var profileRejected = false
    /// Who I am; mirrors `identity` so screens showing my name and avatar update on save.
    private(set) var profile: Profile?
    private(set) var room: RoomSnapshot?
    private(set) var me: PrivateSnapshot?
    private(set) var chat: [ChatMessage] = []
    /// The narrator's lines for this game, oldest first.
    private(set) var log: [LogEntry] = []
    var lastError: AppError?
    /// Something that happened to me (kicked, room closed), shown as an alert.
    var notice: String?

    /// Server clock minus local clock, in seconds; corrects the countdowns.
    private(set) var clockOffset: TimeInterval = 0
    /// Full length of the current phase, for the countdown ring.
    private(set) var phaseTotal: TimeInterval = 0

    @ObservationIgnored private let service: GameService
    @ObservationIgnored private let identity: IdentityStoring
    @ObservationIgnored private var listener: Task<Void, Never>?
    /// Intents made before the server welcomed us (e.g. "create room" right after typing a name).
    @ObservationIgnored private var pending: [ClientMessage] = []
    @ObservationIgnored private var welcomed = false
    @ObservationIgnored private var watchingRooms = false
    @ObservationIgnored private var lastLogged: (seq: Int, text: String)?
    @ObservationIgnored private var lastDivider: String?

    init(service: GameService, identity: IdentityStoring) {
        self.service = service
        self.identity = identity
        profile = identity.profile
    }

    var nickname: String { profile?.nickname ?? "" }

    func start() {
        guard listener == nil else { return }
        listener = Task { [weak self, events = service.events] in
            for await event in events {
                self?.handle(event)
            }
        }
        if let profile {
            service.connect(profile: profile, token: identity.token)
        }
    }

    // MARK: Intents

    /// Saves who I am and tells the server: the first time this connects.
    func saveProfile(_ profile: Profile) {
        let trimmed = Profile(nickname: profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines), gender: profile.gender, avatar: profile.avatar)
        guard !trimmed.nickname.isEmpty else { return }
        let changed = trimmed != self.profile
        identity.profile = trimmed
        self.profile = trimmed
        service.updateIdentity(profile: trimmed, token: identity.token)
        profileRejected = false
        if !welcomed {
            if status == .disconnected {
                service.connect(profile: trimmed, token: identity.token)
            } else {
                service.send(.hello(token: identity.token, profile: trimmed))
            }
        } else if changed {
            send(.updateProfile(trimmed))
        }
    }

    /// The rooms screen is showing: keep its list fresh.
    func watchRooms(_ on: Bool) {
        watchingRooms = on
        if !on { roomList = [] }
        if welcomed { service.send(.watchRooms(on)) }
    }

    func createRoom(name: String?, capacity: Int, isPrivate: Bool) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        send(.createRoom(name: trimmed?.isEmpty == false ? trimmed : nil, capacity: capacity, isPrivate: isPrivate))
    }

    func joinRoom(code: String) { send(.joinRoom(code: code)) }
    func leaveRoom() { send(.leaveRoom) }
    func renameRoom(_ name: String) { send(.renameRoom(name)) }
    func transferHost(_ playerId: String) { send(.transferHost(playerId: playerId)) }
    func kick(_ playerId: String) { send(.kick(playerId: playerId)) }
    func setDiscussionSeconds(_ seconds: Int) { send(.setDiscussionSeconds(seconds)) }
    func setMafiaCount(_ count: Int?) { send(.setMafiaCount(count)) }
    func setRoleEnabled(_ role: RoleID, _ enabled: Bool) { send(.setRoleEnabled(role, enabled)) }
    func startGame() { send(.startGame) }
    func nightAction(_ targetId: String?) { send(.nightAction(targetId: targetId)) }
    func vote(_ targetId: String?) { send(.vote(targetId: targetId)) }
    func judge(_ choice: Judgment) { send(.judge(choice)) }
    func revealRole() { send(.revealRole) }
    func playAgain() { send(.playAgain) }
    func addBot() { send(.addBot) }
    func devSetRole(_ role: RoleID?) { send(.devSetRole(role)) }
    func devFastTimers(_ enabled: Bool) { send(.devFastTimers(enabled)) }

    func sendChat(_ text: String, channel: ChatChannel) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        send(.chat(channel: channel, text: String(trimmed.prefix(300))))
    }

    private func send(_ message: ClientMessage) {
        if welcomed { service.send(message) } else { pending.append(message) }
    }

    // MARK: Derived

    var isHost: Bool { room != nil && room?.hostId == playerId }

    func player(_ id: String?) -> PublicPlayer? { room?.player(id) }

    func name(of id: String?) -> String { player(id)?.name ?? "؟" }

    /// When the current phase ends, in local time.
    var phaseEndsAt: Date? {
        guard let ms = room?.phaseEndsAt else { return nil }
        return Date(timeIntervalSince1970: ms / 1000 - clockOffset)
    }

    func messages(in channel: ChatChannel) -> [ChatMessage] {
        chat.filter { $0.channel == channel }
    }

    // MARK: Narrator log

    private func appendToLog(room: RoomSnapshot?, me: PrivateSnapshot?, previousInspections: [InspectionResult]) {
        if let room {
            // «الليلة ٢» when a night starts, «النهار ٢» when its morning comes.
            if let divider = Self.divider(for: room), divider != lastDivider {
                log.append(LogEntry(id: log.count, text: divider, tone: .divider))
                lastDivider = divider
            }
            // A new line, or the same line in a new phase (a repeated story beat).
            // One numbered line per event: the server puts each on its own line.
            if let narration = room.narration, lastLogged?.seq != room.phaseSeq || lastLogged?.text != narration {
                for line in narration.split(separator: "\n").map(String.init) {
                    log.append(LogEntry(id: log.count, text: line, tone: Self.tone(of: line, in: room)))
                }
                lastLogged = (room.phaseSeq, narration)
            }
        }
        for result in (me?.inspections ?? []).dropFirst(previousInspections.count) {
            let name = self.name(of: result.targetId)
            let text = result.isMafia
                ? "تحقيقك قلب كرت \(name): \(result.role.name)! 🎭"
                : "تحقيقك قلب كرت \(name): \(result.role.name)."
            log.append(LogEntry(id: log.count, text: text, tone: .secret))
        }
    }

    private static func divider(for room: RoomSnapshot) -> String? {
        switch room.phase {
        case .night: "الليلة \(room.round)"
        case .morning, .discussion, .voting, .defense, .judgment, .verdict: "النهار \(room.round)"
        case .ended: "النهاية"
        case .lobby, .roleReveal: nil
        }
    }

    /// Red for a death: killed at night, voted out, or out for leaving or idling.
    /// The server writes a player who is out as «name (role)», so only those lines turn red.
    private static func tone(of line: String, in room: RoomSnapshot) -> LogEntry.Tone {
        room.players.contains { !$0.alive && line.contains("\($0.name) (") } ? .danger : .neutral
    }

    // MARK: Events

    func handle(_ event: ServiceEvent) {
        switch event {
        case let .status(status):
            self.status = status
            if status != .connected { welcomed = false }
        case let .message(message):
            handle(message)
        }
    }

    private func handle(_ message: ServerMessage) {
        switch message {
        case let .welcome(playerId, token, debugEnabled, maintenance, stats):
            self.playerId = playerId
            self.debugEnabled = debugEnabled
            self.maintenance = maintenance
            self.stats = stats
            identity.token = token
            if let profile { service.updateIdentity(profile: profile, token: token) }
            welcomed = true
            if watchingRooms { service.send(.watchRooms(true)) }
            let queued = pending
            pending.removeAll()
            queued.forEach(service.send)
        case let .serverStatus(debugEnabled, maintenance):
            self.debugEnabled = debugEnabled
            self.maintenance = maintenance
        case let .rooms(list):
            if watchingRooms { roomList = list }
        case let .stats(stats):
            self.stats = stats
        case let .notice(text):
            notice = text
        case let .state(room, me):
            if let room, room.phase == .lobby, room.player(playerId)?.pending == true {
                // Others already went back to the lobby. Keep showing the results until I choose;
                // with no results to show (e.g. after relaunching), just go back too.
                if self.room?.phase == .ended { return }
                service.send(.playAgain)
            }
            if room == nil || (room?.phase == .lobby && self.room?.phase == .ended) { chat.removeAll() }
            if room == nil || room?.phase == .lobby {
                log.removeAll()
                lastDivider = nil
            }
            if let room {
                clockOffset = room.serverNow / 1000 - Date().timeIntervalSince1970
                if room.phaseSeq != self.room?.phaseSeq {
                    phaseTotal = room.phaseEndsAt.map { max(0, ($0 - room.serverNow) / 1000) } ?? 0
                }
            }
            let previousInspections = self.me?.inspections ?? []
            self.room = room
            self.me = me
            appendToLog(room: room, me: me, previousInspections: previousInspections)
        case let .chatHistory(messages):
            chat = messages
        case let .chat(message):
            if !chat.contains(where: { $0.id == message.id }) { chat.append(message) }
        case let .error(code, message):
            if code == "upgradeRequired" { updateRequired = true }
            if code == "nameRejected" { profileRejected = true }
            lastError = AppError(code: code, message: message)
        case .unknown:
            break
        }
    }
}
