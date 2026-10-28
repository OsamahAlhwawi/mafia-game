import Foundation

/// What the host chose before the game; anything left unset follows the player count.
struct RoleSetup: Sendable {
    /// How many mafia to deal; nil follows the player count.
    var mafia: Int?
    /// Special town roles the host turned on or off.
    var roles: [RoleID: Bool] = [:]
}

enum Deal {
    static let minPlayers = 5
    static let maxPlayers = 9

    /// Town roles the host may turn on or off (every one but the filler).
    static let optionalRoles = RoleCatalog.all.filter { $0.team == .town && !$0.isFiller }.map(\.id)

    /// The most mafia a game of this size may have, so town isn't outnumbered after one night.
    static func maxMafia(_ playerCount: Int) -> Int {
        playerCount >= 8 ? 3 : playerCount >= 6 ? 2 : 1
    }

    /// The lobby can hold fewer players than a game needs; the deck shows what the minimum would get.
    static func clamp(_ playerCount: Int) -> Int {
        min(maxPlayers, max(minPlayers, playerCount))
    }

    /// How many of each role, in catalog order.
    static func roleCounts(_ playerCount: Int, setup: RoleSetup = RoleSetup()) -> [(role: RoleID, count: Int)] {
        precondition((minPlayers...maxPlayers).contains(playerCount), "player count must be \(minPlayers)-\(maxPlayers)")
        var counts: [(role: RoleID, count: Int)] = []
        var dealt = 0
        for def in RoleCatalog.all where !def.isFiller {
            let auto = def.count(playerCount)
            let count: Int
            if def.team == .mafia {
                // A choice made for more players than are seated now is capped, not refused.
                count = setup.mafia.map { min($0, maxMafia(playerCount)) } ?? auto
            } else if let enabled = setup.roles[def.id] {
                count = enabled ? max(1, auto) : 0
            } else {
                count = auto
            }
            counts.append((def.id, count))
            dealt += count
        }
        guard let filler = RoleCatalog.all.first(where: \.isFiller) else { preconditionFailure("role catalog needs a filler role") }
        counts.append((filler.id, playerCount - dealt))
        return counts
    }

    static func count(of role: RoleID, players: Int, setup: RoleSetup) -> Int {
        roleCounts(players, setup: setup).first { $0.role == role }?.count ?? 0
    }

    /// Randomly deals roles. `forced` (dev tools) pins a role to a player when
    /// that role is still in the pool; otherwise the request is ignored.
    static func assign(_ playerIds: [String], rng: GameRandom, forced: [String: RoleID] = [:], setup: RoleSetup = RoleSetup()) -> [String: RoleID] {
        var pool = roleCounts(playerIds.count, setup: setup).flatMap { Array(repeating: $0.role, count: $0.count) }
        var result: [String: RoleID] = [:]
        for (playerId, role) in forced.sorted(by: { $0.key < $1.key }) {
            guard playerIds.contains(playerId), let index = pool.firstIndex(of: role) else { continue }
            pool.remove(at: index)
            result[playerId] = role
        }
        let rest = rng.shuffled(playerIds.filter { result[$0] == nil })
        let roles = rng.shuffled(pool)
        for (id, role) in zip(rest, roles) { result[id] = role }
        return result
    }
}
