import Foundation

struct VoteResult {
    let eliminatedId: String?
    /// Players only, most votes first.
    let tally: [TallyEntry]
    let abstain: Int
    /// "majority", "tie", "abstain" or "noVotes".
    let reason: String
}

enum Voting {
    /// Day vote. Only votes actually cast count: a living player who never voted
    /// has no say, while an explicit abstention (nil) counts as abstaining.
    /// Nobody leaves on a tie for first, or when abstentions match or beat the
    /// leading player. `weightOf` gives a revealed mayor's vote (and abstention) its weight.
    static func tally(aliveIds: [String], votes: [String: String?], weightOf: (String) -> Int = { _ in 1 }) -> VoteResult {
        let alive = Set(aliveIds)
        var tally: [TallyEntry] = []
        var abstain = 0
        for voterId in aliveIds {
            guard let target = votes[voterId] else { continue }
            let weight = weightOf(voterId)
            guard let target else {
                abstain += weight
                continue
            }
            guard alive.contains(target) else { continue }
            if let i = tally.firstIndex(where: { $0.targetId == target }) {
                tally[i] = TallyEntry(targetId: target, count: tally[i].count + weight)
            } else {
                tally.append(TallyEntry(targetId: target, count: weight))
            }
        }
        tally.sort { $0.count > $1.count }

        guard let top = tally.first?.count else { return VoteResult(eliminatedId: nil, tally: tally, abstain: abstain, reason: "noVotes") }
        if tally.filter({ $0.count == top }).count > 1 { return VoteResult(eliminatedId: nil, tally: tally, abstain: abstain, reason: "tie") }
        if abstain >= top { return VoteResult(eliminatedId: nil, tally: tally, abstain: abstain, reason: "abstain") }
        return VoteResult(eliminatedId: tally[0].targetId, tally: tally, abstain: abstain, reason: "majority")
    }

    /// Town wins when no mafia is left; the mafia wins once they match the rest.
    static func winner(_ players: [CorePlayer]) -> Winner? {
        let alive = players.filter(\.alive)
        let mafia = alive.filter { $0.def.team == .mafia }.count
        if mafia == 0 { return .town }
        if mafia >= alive.count - mafia { return .mafia }
        return nil
    }
}
