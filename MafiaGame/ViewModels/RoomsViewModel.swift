import Foundation
import Observation

@MainActor
@Observable
final class RoomsViewModel {
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    var profile: Profile? { store.profile }
    var stats: PlayerStats { store.stats }

    var winRate: Int? { stats.games > 0 ? Int((Double(stats.wins) / Double(stats.games) * 100).rounded()) : nil }

    func create(name: String, capacity: Int) {
        store.createRoom(name: name, capacity: capacity, isPrivate: true)
    }
}
