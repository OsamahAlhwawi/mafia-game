import Foundation

// The secrecy boundary: everything the app is shown is built here, the same
// public/private split the online server makes, so the UI can't tell the difference.
extension LocalRoom {
    func snapshot() -> RoomSnapshot {
        let seated = Deal.clamp(players.count)
        let counts = Deal.roleCounts(seated, setup: roleSetup)
        let voting = phase == .voting
        return RoomSnapshot(
            code: code,
            name: name,
            isPrivate: false,
            hostId: hostId,
            phase: phase,
            phaseSeq: phaseSeq,
            phaseEndsAt: phaseEndsAt.map { $0.timeIntervalSince1970 * 1000 },
            serverNow: Date().timeIntervalSince1970 * 1000,
            round: round,
            settings: RoomSettings(
                discussionSeconds: discussionSeconds,
                fastTimers: fastTimers,
                minPlayers: Deal.minPlayers,
                maxPlayers: capacity,
                mafia: MafiaSetting(count: roleSetup.mafia, max: Deal.maxMafia(seated)),
                optionalRoles: Deal.optionalRoles.map { id in
                    OptionalRole(role: RoleCatalog[id].info, enabled: counts.contains { $0.role == id && $0.count > 0 })
                }
            ),
            players: players.map { p in
                PublicPlayer(id: p.id, name: p.name, alive: p.alive, connected: true, isBot: p.isBot, isHost: p.id == hostId, gender: p.gender, avatar: p.avatar, pending: false)
            },
            narration: narration,
            lastNightKilledIds: lastNightKilledIds,
            votedIds: voting ? players.map(\.id).filter { dayVotes.keys.contains($0) } : [],
            liveTally: voting ? liveTally() : [],
            liveAbstain: voting ? dayVotes.filter { $0.value == nil && player($0.key)?.alive == true }.reduce(0) { $0 + voteWeight($1.key) } : 0,
            accusedId: [.defense, .judgment, .verdict].contains(phase) ? accusedId : nil,
            judgment: phase == .judgment ? judgmentCounts() : nil,
            verdict: phase == .verdict ? verdict : nil,
            winner: winner,
            deck: counts.filter { $0.count > 0 }.map { DeckEntry(role: RoleCatalog[$0.role].info, count: $0.count) },
            // The dead's cards (and a revealed mayor's) are flipped for everyone; at the end, everyone's are.
            revealedRoles: players.compactMap { p in
                guard let def = p.def, phase == .ended || !p.alive || publicReveals.contains(p.id) else { return nil }
                return RevealedRole(playerId: p.id, role: def.info)
            },
            voteWeights: players.filter { $0.alive && voteWeight($0.id) > 1 }.map { VoteWeight(playerId: $0.id, weight: voteWeight($0.id)) }
        )
    }

    /// Votes each living player has right now (counts only, weighted like the final tally).
    private func liveTally() -> [TallyEntry] {
        var tally: [TallyEntry] = []
        for p in players {
            guard let target = dayVotes[p.id] ?? nil, p.alive, player(target)?.alive == true else { continue }
            if let i = tally.firstIndex(where: { $0.targetId == target }) {
                tally[i] = TallyEntry(targetId: target, count: tally[i].count + voteWeight(p.id))
            } else {
                tally.append(TallyEntry(targetId: target, count: voteWeight(p.id)))
            }
        }
        return tally
    }

    private func judgmentCounts() -> JudgmentCounts {
        let votes = players.compactMap { p in p.alive ? judgments[p.id].map { JudgmentVote(voterId: p.id, choice: $0) } : nil }
        let weigh = { (choice: Judgment) in votes.filter { $0.choice == choice }.reduce(0) { $0 + self.voteWeight($1.voterId) } }
        return JudgmentCounts(eliminate: weigh(.eliminate), pardon: weigh(.pardon), votes: votes)
    }

    func privateSnapshot(for viewerId: String) -> PrivateSnapshot? {
        guard let me = player(viewerId) else { return nil }
        let def = me.def
        let ability = def?.ability
        let isNight = phase == .night

        let teammates: [Teammate]? = def?.knowsTeammates == true
            ? players.filter { $0.id != me.id && $0.def?.team == def?.team }.map { Teammate(id: $0.id, name: $0.name) }
            : nil
        let teamChoices: [TeamChoice]? = isNight && ability?.kind == .teamKill
            ? ([me.id] + (teammates ?? []).map(\.id))
                .filter { player($0)?.alive == true }
                .map { TeamChoice(actorId: $0, targetId: nightChoices[$0] ?? nil) }
            : nil

        let myNightTarget = isNight ? (nightChoices[me.id] ?? nil) : nil
        let locked = ability?.locksOnSubmit == true && myNightTarget != nil
        let canAct = isNight && ability != nil && me.alive && !locked

        return PrivateSnapshot(
            playerId: me.id,
            role: def?.info,
            alive: me.alive,
            teammates: teammates,
            teamChoices: teamChoices,
            myNightTarget: myNightTarget,
            validTargetIds: canAct ? validNightTargets(for: me.id) : [],
            nightActionLocked: locked,
            inspections: inspections[me.id] ?? [],
            myVote: phase == .voting ? (dayVotes[me.id] ?? nil) : nil,
            myJudgment: phase == .judgment ? judgments[me.id] : nil,
            writableChannels: ChatChannel.allCases.filter { canWrite(me, $0) },
            forcedRole: forcedRoles[me.id],
            // Offline, the dev tools (bots, pick your role, fast timers) are for everyone.
            canDebug: true,
            abilityUsesLeft: nightHistory(me.id).usesLeft,
            canRevealRole: canRevealRole(me)
        )
    }

    func chatHistory(for viewerId: String) -> [ChatMessage] {
        guard let me = player(viewerId) else { return [] }
        return chatLog.filter { canRead(me, $0.channel) }
    }
}
