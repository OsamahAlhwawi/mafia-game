import Foundation
import Observation

@MainActor
@Observable
final class VotingViewModel {
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    var canVote: Bool { store.me?.alive ?? false }
    var myVote: String? { store.me?.myVote }
    var hasVoted: Bool { store.room?.votedIds.contains(store.playerId ?? "") ?? false }
    var abstained: Bool { hasVoted && myVote == nil }

    /// Living players other than me.
    var options: [PublicPlayer] {
        (store.room?.players ?? []).filter { $0.alive && $0.id != store.playerId }
    }

    func didVote(_ playerId: String) -> Bool { store.room?.votedIds.contains(playerId) ?? false }

    var votedCount: Int { store.room?.votedIds.count ?? 0 }
    var aliveCount: Int { (store.room?.players ?? []).filter(\.alive).count }

    func vote(for playerId: String) { if canVote { store.vote(playerId) } }
    func abstain() { if canVote { store.vote(nil) } }
}
