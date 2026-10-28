import Foundation
import Observation

struct RevealedPlayer: Identifiable {
    let id: String
    let name: String
    let role: RoleInfo
    let alive: Bool
    let isMe: Bool
}

@MainActor
@Observable
final class EndViewModel {
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    var winner: Winner? { store.room?.winner }
    var isHost: Bool { store.isHost }
    var narration: String { store.room?.narration ?? "" }

    var title: String {
        switch winner {
        case .mafia: "فازت المافيا"
        case .draw: "تعادل"
        default: "فاز أهل المدينة"
        }
    }

    var iWon: Bool {
        guard let winner, winner != .draw, let team = store.me?.role?.team else { return false }
        return (winner == .mafia) == (team == .mafia)
    }

    /// Mafia first, then everyone else, as revealed by the server.
    var players: [RevealedPlayer] {
        (store.room?.revealedRoles ?? [])
            .map { revealed in
                let player = store.player(revealed.playerId)
                return RevealedPlayer(
                    id: revealed.playerId,
                    name: player?.name ?? "؟",
                    role: revealed.role,
                    alive: player?.alive ?? false,
                    isMe: revealed.playerId == store.playerId
                )
            }
            .sorted { ($0.role.team == .mafia ? 0 : 1) < ($1.role.team == .mafia ? 0 : 1) }
    }

    func leave() { store.leaveRoom() }
}
