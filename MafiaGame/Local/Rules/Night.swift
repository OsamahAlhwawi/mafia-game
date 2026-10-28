import Foundation

/// What the actor did before that limits tonight's choice.
struct NightHistory {
    var lastTargetId: String?
    /// Everyone the actor picked on earlier nights.
    var pastTargetIds: Set<String> = []
    /// Uses left for a limited ability (the officer's bullet); nil when unlimited.
    var usesLeft: Int?
}

struct Shot: Equatable {
    let shooterId: String
    let targetId: String
    /// A hit on the mafia kills the target; otherwise the shooter dies instead.
    let hitMafia: Bool
}

struct NightOutcome {
    /// Who was attacked, before protection.
    let attackedIds: [String]
    /// Who actually died.
    let killedIds: [String]
    /// Bullets fired tonight.
    let shots: [Shot]
}

enum Night {
    /// Checks one night choice against the actor's role rules. A nil target
    /// (withdraw / skip) is always valid for a living player with an ability.
    static func validate(_ players: [CorePlayer], actorId: String, targetId: String?, history: NightHistory) -> LocalError.Code? {
        guard let actor = players.first(where: { $0.id == actorId }), actor.alive else { return .notAlive }
        guard let ability = actor.def.ability else { return .noNightAction }
        guard let targetId else { return nil }
        if history.usesLeft == 0 { return .abilitySpent }

        guard let target = players.first(where: { $0.id == targetId }) else { return .invalidTarget }
        if !target.alive { return .targetDead }
        let rules = ability.targets
        let isSelf = targetId == actorId
        if isSelf && !rules.allowSelf { return .cannotTargetSelf }
        if !isSelf && !rules.allowTeammates && target.def.team == actor.def.team { return .cannotTargetTeammate }
        if rules.notSameTargetTwice && targetId == history.lastTargetId { return .sameAsLastNight }
        if rules.notSameTargetAgain && history.pastTargetIds.contains(targetId) { return .alreadyTargeted }
        return nil
    }

    /// The detective's answer: does this player belong to the mafia?
    static func inspect(_ players: [CorePlayer], targetId: String) -> Bool {
        players.first { $0.id == targetId }?.def.team == .mafia
    }

    /// Protection runs first so it applies to every attack; a bullet is never an
    /// attack (nothing stops it). `inspect` has no end-of-night effect: its answer
    /// is given the moment the choice is made.
    static func resolve(_ players: [CorePlayer], choices: [String: String?], rng: GameRandom) -> NightOutcome {
        let alive = Dictionary(uniqueKeysWithValues: players.filter(\.alive).map { ($0.id, $0) })

        /// Choices made by living players whose role has the given ability kind, in seating order.
        func picks(of kind: AbilityKind) -> [(actor: CorePlayer, target: String)] {
            players.compactMap { p in
                guard p.alive, p.def.ability?.kind == kind, let target = choices[p.id] ?? nil else { return nil }
                return (p, target)
            }
        }

        let protectedIds = Set(picks(of: .protect).map(\.target))

        // The team votes; most votes wins, ties are broken at random.
        var attackedIds: [String] = []
        var tally: [(id: String, votes: Int)] = []
        for (actor, target) in picks(of: .teamKill) {
            guard let victim = alive[target], victim.def.team != actor.def.team else { continue }
            if let i = tally.firstIndex(where: { $0.id == target }) { tally[i].votes += 1 } else { tally.append((target, 1)) }
        }
        if let top = tally.map(\.votes).max() {
            attackedIds.append(rng.pick(tally.filter { $0.votes == top }.map(\.id)))
        }

        // Everything happens at once: a shooter killed by the mafia tonight still fires.
        var certainKills: [String] = []
        var shots: [Shot] = []
        for (shooter, target) in picks(of: .shoot) {
            guard let victim = alive[target] else { continue }
            let hitMafia = victim.def.team == .mafia
            certainKills.append(hitMafia ? victim.id : shooter.id)
            shots.append(Shot(shooterId: shooter.id, targetId: victim.id, hitMafia: hitMafia))
        }

        var killed: [String] = []
        for id in attackedIds.filter({ !protectedIds.contains($0) }) + certainKills where !killed.contains(id) {
            killed.append(id)
        }
        return NightOutcome(attackedIds: attackedIds, killedIds: killed, shots: shots)
    }
}
