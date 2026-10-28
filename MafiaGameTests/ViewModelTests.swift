import Foundation
import Testing
@testable import MafiaGame

@MainActor
private func makeStore(phase: GamePhase, role: RoleID = .mafia) -> (GameStore, MockGameService) {
    let service = MockGameService()
    let store = GameStore(service: service, identity: InMemoryIdentityStore(profile: Profile(nickname: "أحمد", gender: .male, avatar: "m1")))
    store.handle(.status(.connected))
    store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: .zero)))
    store.handle(.message(.state(room: PreviewData.room(phase: phase), me: PreviewData.me(role: role, phase: phase))))
    return (store, service)
}

@MainActor
@Suite struct LobbyViewModelTests {
    @Test func hostCanStartWithEnoughPlayers() {
        let (store, service) = makeStore(phase: .lobby)
        let model = LobbyViewModel(store: store)
        #expect(model.isHost)
        #expect(model.missingPlayers == 0)
        model.start()
        #expect(service.sent.last == .startGame)
    }

    @Test func tableSeatsEveryoneButMeThenEmptyChairs() {
        let (store, _) = makeStore(phase: .lobby)
        let model = LobbyViewModel(store: store)
        #expect(model.me?.id == "p0")
        #expect(model.otherSeats.count == model.capacity - 1)
        #expect(!model.otherSeats.contains { $0.id == "p0" })
        #expect(model.otherSeats.prefix(model.players.count - 1).allSatisfy { if case .player = $0 { true } else { false } })
    }

    @Test func discussionStaysWithinBounds() {
        let (store, service) = makeStore(phase: .lobby)
        let model = LobbyViewModel(store: store)
        model.changeDiscussion(by: 30)
        #expect(service.sent.last == .setDiscussionSeconds(150))
        model.changeDiscussion(by: 1000)
        #expect(service.sent.last == .setDiscussionSeconds(300))
    }

    @Test func notEnoughPlayers() {
        let service = MockGameService()
        let store = GameStore(service: service, identity: InMemoryIdentityStore())
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: .zero)))
        let base = PreviewData.room(phase: .lobby)
        let small = RoomSnapshot(
            code: base.code, name: base.name, isPrivate: false, hostId: "p0", phase: .lobby, phaseSeq: 1, phaseEndsAt: nil, serverNow: base.serverNow, round: 0,
            settings: base.settings, players: Array(base.players.prefix(3)), narration: nil,
            lastNightKilledIds: [], votedIds: [], liveTally: [], liveAbstain: 0, accusedId: nil, judgment: nil,
            verdict: nil, winner: nil, deck: base.deck, revealedRoles: nil
        )
        store.handle(.message(.state(room: small, me: nil)))
        let model = LobbyViewModel(store: store)
        #expect(model.missingPlayers == 2)
        #expect(!model.canStart)
        #expect(model.statusText == "تحتاجون 2 لاعبين بعد")
        model.start()
        #expect(service.sent.isEmpty)
    }
}

@MainActor
@Suite struct NightViewModelTests {
    @Test func mafiaSeesOnlyValidTargetsWithTeamPicks() {
        let (store, _) = makeStore(phase: .night, role: .mafia)
        let model = NightViewModel(store: store)
        #expect(model.mode == .team)
        #expect(!model.rows.contains { $0.id == "p5" }) // teammate
        let sara = model.rows.first { $0.id == "p2" }!
        #expect(sara.selected)
        #expect(sara.pickedBy == ["أنت"])
        #expect(model.rows.first { $0.id == "p3" }?.pickedBy == ["خالد"])
    }

    @Test func tappingSelectedWithdrawsAndOtherPicks() {
        let (store, service) = makeStore(phase: .night, role: .mafia)
        let model = NightViewModel(store: store)
        model.tap(model.rows.first { $0.id == "p2" }!)
        #expect(service.sent.last == .nightAction(targetId: nil))
        model.tap(model.rows.first { $0.id == "p4" }!)
        #expect(service.sent.last == .nightAction(targetId: "p4"))
    }

    @Test func detectiveIsLockedAndSeesTonightsResult() {
        let (store, service) = makeStore(phase: .night, role: .detective)
        let model = NightViewModel(store: store)
        #expect(model.mode == .single(.inspect))
        #expect(model.tonightsInspection == InspectionResult(round: 2, targetId: "p2", isMafia: true, role: PreviewData.mafiaRole))
        #expect(model.pastInspections.count == 1)
        model.tap(model.rows.first { $0.id == "p4" }!)
        #expect(service.sent.isEmpty)
    }

    @Test func citizenWaits() {
        let (store, _) = makeStore(phase: .night, role: .citizen)
        #expect(NightViewModel(store: store).mode == .waiting)
    }
}

@MainActor
@Suite struct VotingViewModelTests {
    @Test func optionsExcludeMeAndTheDead() {
        let (store, service) = makeStore(phase: .voting)
        let model = VotingViewModel(store: store)
        #expect(!model.options.contains { $0.id == "p0" })
        #expect(model.myVote == "p3")
        model.vote(for: "p1")
        #expect(service.sent.last == .vote(targetId: "p1"))
        model.abstain()
        #expect(service.sent.last == .vote(targetId: nil))
    }
}

@MainActor
@Suite struct EndViewModelTests {
    @Test func revealsEveryoneMafiaFirst() {
        let store = PreviewData.store(phase: .ended, role: .mafia)
        let model = EndViewModel(store: store)
        #expect(model.winner == .town)
        #expect(model.players.count == 7)
        #expect(model.players.prefix(2).allSatisfy { $0.role.team == .mafia })
        #expect(!model.iWon)
    }
}
