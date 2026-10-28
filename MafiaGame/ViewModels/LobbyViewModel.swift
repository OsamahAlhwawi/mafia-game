import Foundation
import Observation

/// One chair in the lobby: a player, or an empty seat up to the room's capacity.
enum LobbySeat: Identifiable {
    case player(PublicPlayer)
    case empty(Int)

    var id: String {
        switch self {
        case let .player(p): p.id
        case let .empty(i): "empty-\(i)"
        }
    }
}

@MainActor
@Observable
final class LobbyViewModel {
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    var code: String { store.room?.code ?? "" }
    var name: String { store.room?.name ?? "" }
    var isPrivate: Bool { store.room?.isPrivate ?? false }
    var players: [PublicPlayer] { store.room?.players ?? [] }
    var deck: [DeckEntry] { store.room?.deck ?? [] }
    var isHost: Bool { store.isHost }
    var myId: String? { store.playerId }
    var minPlayers: Int { store.room?.settings.minPlayers ?? 5 }
    var capacity: Int { store.room?.settings.maxPlayers ?? 9 }
    var discussionSeconds: Int { store.room?.settings.discussionSeconds ?? 120 }
    /// The host's mafia choice; nil follows the player count.
    var mafiaChoice: Int? { store.room?.settings.mafia.count }
    var maxMafia: Int { store.room?.settings.mafia.max ?? 1 }
    var mafiaInDeck: Int { deck.filter { $0.role.team == .mafia }.reduce(0) { $0 + $1.count } }
    var optionalRoles: [OptionalRole] { store.room?.settings.optionalRoles ?? [] }
    var canDebug: Bool { store.me?.canDebug ?? false }
    var fastTimers: Bool { store.room?.settings.fastTimers ?? false }
    var forcedRole: RoleID? { store.me?.forcedRole }

    /// Players first, then the empty chairs.
    var seats: [LobbySeat] {
        players.map(LobbySeat.player) + (players.count..<max(players.count, capacity)).map(LobbySeat.empty)
    }

    /// The chairs around the table, in the order the game seats everyone; mine sits at the bottom.
    var otherSeats: [LobbySeat] {
        seats.filter { if case let .player(p) = $0 { p.id != myId } else { true } }
    }
    var me: PublicPlayer? { players.first { $0.id == myId } }

    var missingPlayers: Int { max(0, minPlayers - players.count) }
    /// Still on the last game's results.
    var pendingCount: Int { players.filter(\.pending).count }
    var canStart: Bool { isHost && missingPlayers == 0 && pendingCount == 0 }
    var canAddBot: Bool { canDebug && isHost && players.count < capacity }

    var statusText: String {
        if missingPlayers > 0 { return missingPlayers == 1 ? "تحتاجون لاعب واحد بعد" : "تحتاجون \(missingPlayers) لاعبين بعد" }
        if pendingCount > 0 { return pendingCount == 1 ? "بانتظار لاعب يرجع من شاشة النتيجة" : "بانتظار \(pendingCount) يرجعون من شاشة النتيجة" }
        return isHost ? "جاهزين! تقدر تبدأ اللعبة" : "بانتظار قائد الغرفة يبدأ اللعبة"
    }

    /// The cards in play, for everyone to see before the game: «المافيا ×2 · الطبيب · المواطن ×3».
    var deckSummary: String {
        deck.map { $0.count > 1 ? "\($0.role.name) ×\($0.count)" : $0.role.name }.joined(separator: " · ")
    }

    /// The host asked for more mafia than the players seated now allow.
    var mafiaCapNote: String? {
        guard let choice = mafiaChoice, choice > maxMafia else { return nil }
        return "اللاعبين ما يكفون لـ\(choice) مافيا، بيتوزّع \(mafiaInDeck)"
    }

    /// The host can act on anyone but themself (bots can't lead).
    func canManage(_ player: PublicPlayer) -> Bool { isHost && player.id != myId }

    func start() { if canStart { store.startGame() } }
    func kick(_ player: PublicPlayer) { if canManage(player) { store.kick(player.id) } }
    func makeHost(_ player: PublicPlayer) { if canManage(player) && !player.isBot { store.transferHost(player.id) } }
    func rename(_ newName: String) { if isHost { store.renameRoom(newName) } }
    func leave() { store.leaveRoom() }
    func addBot() { if canAddBot { store.addBot() } }
    func setForcedRole(_ role: RoleID?) { store.devSetRole(role) }
    func setFastTimers(_ enabled: Bool) { store.devFastTimers(enabled) }

    func setMafia(_ count: Int?) { if isHost && count != mafiaChoice { store.setMafiaCount(count) } }
    func toggle(_ role: OptionalRole) { if isHost { store.setRoleEnabled(role.role.id, !role.enabled) } }

    /// Discussion length in 30-second steps between 30 s and 5 min.
    func changeDiscussion(by delta: Int) {
        let next = min(300, max(30, discussionSeconds + delta))
        if isHost && next != discussionSeconds { store.setDiscussionSeconds(next) }
    }
}
