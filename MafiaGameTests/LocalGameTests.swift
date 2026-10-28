import Foundation
import Testing
@testable import MafiaGame

extension PhaseTimings {
    /// A whole game in well under a second.
    static let instant = PhaseTimings(
        roleReveal: 0.01, night: 0.02, morning: 0.01, voting: 0.02, verdict: 0.01, voteGrace: 0.005, defense: 0.01, judgment: 0.02,
        discussion: 0.02, postGame: 60, botDelay: 0.001...0.005, botChatSpan: 0.01
    )
}

private func players(_ roles: [(String, RoleID)], dead: Set<String> = []) -> [CorePlayer] {
    roles.map { CorePlayer(id: $0.0, role: $0.1, alive: !dead.contains($0.0)) }
}

@Suite struct DealTests {
    @Test(arguments: [
        (5, [RoleID.mafia: 1, .doctor: 1, .detective: 1, .officer: 0, .mayor: 0, .citizen: 2]),
        (7, [.mafia: 2, .doctor: 1, .detective: 1, .officer: 1, .mayor: 0, .citizen: 2]),
        (9, [.mafia: 2, .doctor: 1, .detective: 1, .officer: 1, .mayor: 1, .citizen: 3]),
    ])
    func dealsByPlayerCount(count: Int, expected: [RoleID: Int]) {
        let counts = Dictionary(uniqueKeysWithValues: Deal.roleCounts(count).map { ($0.role, $0.count) })
        #expect(counts == expected)
    }

    @Test func hostChoicesAreCappedNotRefused() {
        let counts = Deal.roleCounts(5, setup: RoleSetup(mafia: 3, roles: [.doctor: false, .mayor: true]))
        let byRole = Dictionary(uniqueKeysWithValues: counts.map { ($0.role, $0.count) })
        #expect(byRole[.mafia] == 1 && byRole[.doctor] == 0 && byRole[.mayor] == 1)
        #expect(counts.reduce(0) { $0 + $1.count } == 5)
    }

    @Test func aForcedRoleIsHonoured() {
        let ids = ["a", "b", "c", "d", "e"]
        let roles = Deal.assign(ids, rng: GameRandom(seed: 1), forced: ["c": .detective])
        #expect(roles["c"] == .detective)
        #expect(roles.count == 5)
    }
}

@Suite struct NightTests {
    let table = players([("m", .mafia), ("doc", .doctor), ("det", .detective), ("off", .officer), ("c", .citizen)])

    @Test func theDoctorSavesTheMafiasTarget() {
        let outcome = Night.resolve(table, choices: ["m": "c", "doc": "c"], rng: GameRandom(seed: 1))
        #expect(outcome.attackedIds == ["c"])
        #expect(outcome.killedIds.isEmpty)
    }

    @Test func aBulletAtTheTownKillsTheOfficer() {
        let outcome = Night.resolve(table, choices: ["off": "c"], rng: GameRandom(seed: 1))
        #expect(outcome.killedIds == ["off"])
        #expect(outcome.shots == [Shot(shooterId: "off", targetId: "c", hitMafia: false)])
    }

    @Test func theDoctorCantStopABullet() {
        let outcome = Night.resolve(table, choices: ["off": "m", "doc": "m"], rng: GameRandom(seed: 1))
        #expect(outcome.killedIds == ["m"])
    }

    @Test func targetRules() {
        #expect(Night.validate(table, actorId: "m", targetId: "m", history: NightHistory()) == .cannotTargetSelf)
        #expect(Night.validate(table, actorId: "doc", targetId: "doc", history: NightHistory()) == nil)
        #expect(Night.validate(table, actorId: "doc", targetId: "c", history: NightHistory(lastTargetId: "c")) == .sameAsLastNight)
        #expect(Night.validate(table, actorId: "det", targetId: "m", history: NightHistory(pastTargetIds: ["m"])) == .alreadyTargeted)
        #expect(Night.validate(table, actorId: "off", targetId: "m", history: NightHistory(usesLeft: 0)) == .abilitySpent)
        #expect(Night.validate(table, actorId: "c", targetId: "m", history: NightHistory()) == .noNightAction)
    }
}

@Suite struct VotingTests {
    let alive = ["a", "b", "c", "d"]

    @Test func aClearLeaderGoesOnTrial() {
        let result = Voting.tally(aliveIds: alive, votes: ["a": "c", "b": "c", "c": "a"])
        #expect(result.eliminatedId == "c" && result.reason == "majority")
    }

    @Test func aTieOrEnoughAbstentionsSparesEveryone() {
        #expect(Voting.tally(aliveIds: alive, votes: ["a": "c", "b": "d"]).reason == "tie")
        #expect(Voting.tally(aliveIds: alive, votes: ["a": "c", "b": nil]).reason == "abstain")
        #expect(Voting.tally(aliveIds: alive, votes: [:]).reason == "noVotes")
    }

    @Test func aRevealedMayorCountsThreeTimes() {
        let result = Voting.tally(aliveIds: alive, votes: ["a": "c", "b": "c", "d": "b"]) { $0 == "d" ? 3 : 1 }
        #expect(result.eliminatedId == "b")
    }

    @Test func winConditions() {
        #expect(Voting.winner(players([("m", .mafia), ("c", .citizen), ("d", .doctor)], dead: ["m"])) == .town)
        #expect(Voting.winner(players([("m", .mafia), ("c", .citizen), ("d", .doctor)], dead: ["d"])) == .mafia)
        #expect(Voting.winner(players([("m", .mafia), ("c", .citizen), ("d", .doctor)])) == nil)
    }
}

@MainActor
@Suite struct LocalGameServiceTests {
    private func makeService(seed: UInt64) -> LocalGameService {
        let defaults = UserDefaults(suiteName: "LocalGameServiceTests-\(UUID().uuidString)")!
        let service = LocalGameService(rng: GameRandom(seed: seed), stats: LocalStats(defaults: defaults))
        service.timings = .instant
        service.connect(profile: Profile(nickname: "سارة", gender: .female, avatar: "f1"), token: nil)
        return service
    }

    @Test func aRoomIsFilledWithBotsAndOnlineRoomsAreRefused() throws {
        let service = makeService(seed: 3)
        service.send(.createRoom(name: nil, capacity: 6, isPrivate: true))
        let room = try #require(service.room)
        #expect(room.players.count == 6)
        #expect(room.players.filter(\.isBot).count == 5)
        #expect(room.hostId == LocalGameService.playerId)

        service.send(.leaveRoom)
        #expect(service.room == nil)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [1, 2, 3, 4, 5] as [UInt64])
    func aWholeGameAgainstBotsEndsWithAWinner(seed: UInt64) async throws {
        let service = makeService(seed: seed)
        service.send(.createRoom(name: nil, capacity: 9, isPrivate: true))
        service.send(.devFastTimers(true))
        service.send(.startGame)

        var phases: [GamePhase] = []
        var stats: PlayerStats?
        for await event in service.events {
            guard case let .message(message) = event else { continue }
            if case let .state(room?, me?) = message {
                if phases.last != room.phase { phases.append(room.phase) }
                // Nobody's card shows before they're out, unless a mayor turned it over.
                if room.phase != .ended && room.phase != .lobby {
                    for revealed in room.revealedRoles ?? [] where revealed.playerId != me.playerId {
                        #expect(room.player(revealed.playerId)?.alive == false || revealed.role.id == .mayor)
                    }
                }
            }
            if case let .stats(new) = message {
                stats = new
                break
            }
        }

        #expect(stats?.games == 1)
        #expect(phases.contains(.night) && phases.contains(.voting))
        let room = try #require(service.room)
        #expect(room.phase == .ended && room.winner != nil)
    }
}
