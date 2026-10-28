import Foundation
import Testing
@testable import MafiaGame

@MainActor
private func board(phase: GamePhase, role: RoleID = .mafia, room: RoomSnapshot? = nil, me: PrivateSnapshot? = nil) -> (BoardViewModel, MockGameService, GameStore) {
    let service = MockGameService()
    let store = GameStore(service: service, identity: InMemoryIdentityStore(profile: Profile(nickname: "أحمد", gender: .male, avatar: "m1")))
    store.handle(.status(.connected))
    store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: .zero)))
    store.handle(.message(.state(room: room ?? PreviewData.room(phase: phase), me: me ?? PreviewData.me(role: role, phase: phase))))
    return (BoardViewModel(store: store), service, store)
}

@Suite struct BoardLayoutTests {
    @Test func splitsRightFirstAndShrinksCrowdedColumns() {
        let (right, left) = BoardLayout.columns(Array(1...11))
        #expect(right == [1, 2, 3, 4, 5, 6])
        #expect(left == [7, 8, 9, 10, 11])
        #expect(BoardLayout.columns([1, 2, 3, 4]).right == [1, 2])
        #expect(BoardLayout.scale(perColumn: 2, height: 600) == 1)
        #expect(BoardLayout.scale(perColumn: 6, height: 600) < 1)
    }
}

@MainActor
@Suite struct BoardViewModelTests {
    @Test func mafiaSeatsShowKillOnTargetsAndTeammateCard() {
        let (model, service, _) = board(phase: .night, role: .mafia)
        let seats = Dictionary(uniqueKeysWithValues: model.otherSeats.map { ($0.id, $0) })
        #expect(seats["p2"]?.action == Seat.Action(kind: .kill, enabled: true))
        #expect(seats["p2"]?.selected == true)
        #expect(seats["p2"]?.picks == ["أنت"])
        #expect(seats["p3"]?.picks == ["خالد"])
        // A count like the day vote; my pick and my teammate's differ, so it's a tie.
        #expect(seats["p2"]?.voteCount == 1)
        #expect(seats["p3"]?.voteCount == 1)
        #expect(seats["p1"]?.voteCount == nil)
        #expect(model.teamTied)
        #expect(model.instruction == "تعادلتوا! بينختار واحد من اختياراتكم عشوائياً")
        // Teammate: their side is shown, and there's nothing to do to them.
        #expect(seats["p5"]?.face == .role(PreviewData.mafiaRole))
        #expect(seats["p5"]?.action == nil)
        #expect(seats["p1"]?.face == .hidden)

        model.tap(seats["p4"]!)
        #expect(service.sent.last == .nightAction(targetId: "p4"))
        #expect(model.chatChannel == .day)
    }

    @Test func detectiveSeesNoActionOnOwnCard() {
        let (model, _, _) = board(phase: .night, role: .detective)
        #expect(model.mySeat?.action == nil)
    }

    @Test func doctorCanProtectFromOwnCard() {
        let (model, _, _) = board(phase: .night, role: .doctor)
        #expect(model.mySeat?.action?.kind == .protect)
        #expect(model.otherSeats.allSatisfy { $0.action?.kind == .protect })
    }

    @Test func detectiveFindingsShowOnSeatsAndInLog() {
        let (model, _, store) = board(phase: .night, role: .detective)
        let seat = model.otherSeats.first { $0.id == "p2" }!
        #expect(seat.inspectedMafia == true)
        #expect(model.otherSeats.first { $0.id == "p4" }?.inspectedMafia == false)
        #expect(seat.action?.enabled == false) // locked for tonight
        #expect(store.log.filter(\.isPrivate).count == 2)
        #expect(store.log.contains { $0.text == "تحقيقك قلب كرت سارة: المافيا! 🎭" })
        // The inspected cards flip for the detective.
        #expect(seat.face == .role(PreviewData.mafiaRole))
        #expect(model.otherSeats.first { $0.id == "p4" }?.face == .role(PreviewData.citizenRole))
        #expect(model.otherSeats.first { $0.id == "p1" }?.face == .hidden)
    }

    @Test func votingSeatsAndAbstain() {
        let (model, service, _) = board(phase: .voting, room: PreviewData.room(phase: .voting, votedIds: ["p0", "p1", "p4"]))
        let seats = Dictionary(uniqueKeysWithValues: model.otherSeats.map { ($0.id, $0) })
        #expect(seats["p3"]?.selected == true)
        // Live counts while voting is open.
        #expect(seats["p3"]?.voteCount == 2)
        #expect(seats["p1"]?.voteCount == 1)
        #expect(seats["p4"]?.voteCount == nil)
        #expect(model.mySeat?.action == nil)
        model.tap(seats["p1"]!)
        #expect(service.sent.last == .vote(targetId: "p1"))
        #expect(model.canAbstain)
        #expect(model.abstainCount == 1)
        #expect(model.notVotedCount == 4) // 7 alive, 3 voted
        model.abstain()
        #expect(service.sent.last == .vote(targetId: nil))
    }

    @Test func endRevealsEveryCard() {
        let store = PreviewData.store(phase: .ended)
        let model = BoardViewModel(store: store)
        #expect(model.otherSeats.allSatisfy { if case .role = $0.face { true } else { false } })
        #expect(model.title == "فاز أهل المدينة")
    }

    @Test func officerShootsUntilTheBulletIsSpent() {
        let (model, service, _) = board(phase: .night, role: .officer)
        #expect(model.otherSeats.allSatisfy { $0.action?.kind == .shoot })
        model.tap(model.otherSeats.first { $0.id == "p3" }!)
        #expect(service.sent.last == .nightAction(targetId: "p3"))

        var spent = PreviewData.me(role: .officer, phase: .night)
        spent.abilityUsesLeft = 0
        let (after, _, _) = board(phase: .night, role: .officer, me: spent)
        #expect(after.otherSeats.allSatisfy { $0.action == nil })
        #expect(after.instruction == "استخدمت رصاصتك... انتظر الصباح")
    }

    @Test func mayorRevealsByDayAndOthersSeeTheWeight() {
        var me = PreviewData.me(role: .mayor, phase: .discussion)
        me.canRevealRole = true
        let (model, service, _) = board(phase: .discussion, role: .mayor, me: me)
        #expect(model.canRevealRole)
        model.revealRole()
        #expect(service.sent.last == .revealRole)

        var room = PreviewData.room(phase: .voting, revealed: [RevealedRole(playerId: "p3", role: PreviewData.mayorRole)])
        room.voteWeights = [VoteWeight(playerId: "p3", weight: 3)]
        let (other, _, _) = board(phase: .voting, role: .citizen, room: room)
        let mayor = other.otherSeats.first { $0.id == "p3" }!
        #expect(mayor.face == .role(PreviewData.mayorRole))
        #expect(mayor.voteWeight == 3)
        #expect(other.otherSeats.first { $0.id == "p4" }?.voteWeight == nil)
        #expect(!other.canRevealRole)
    }

    @Test func deadPlayersCardIsFaceUp() {
        let (model, _, _) = board(phase: .morning, room: PreviewData.room(phase: .morning, dead: ["p3"], killed: ["p3"]))
        let dead = model.otherSeats.first { $0.id == "p3" }!
        #expect(!dead.alive)
        #expect(dead.face == .role(PreviewData.citizenRole))
        #expect(dead.justOut)
        #expect(model.otherSeats.first { $0.id == "p4" }?.face == .hidden)
    }

    @Test func chatFeedKeepsTheNewestFewAndForgetsOldOnes() {
        let (model, _, store) = board(phase: .discussion)
        let now = Date()
        let nowMs = (now.timeIntervalSince1970 + store.clockOffset) * 1000
        for i in 0..<6 {
            store.handle(.message(.chat(ChatMessage(id: "m\(i)", channel: .day, senderId: "p1", senderName: "نورة", text: "\(i)", sentAt: nowMs - 1000))))
        }
        store.handle(.message(.chat(ChatMessage(id: "old", channel: .day, senderId: "p2", senderName: "سارة", text: "قديمة", sentAt: nowMs - 30_000))))
        let feed = model.recentMessages(now: now)
        #expect(feed.map(\.id) == ["m3", "m4", "m5"])
        #expect(model.recentMessages(now: now.addingTimeInterval(10)).isEmpty)
    }

    @Test func cardInfoShowsWhatICanSeeAndUnknownOtherwise() {
        let (model, _, _) = board(phase: .night, role: .mafia)
        let me = model.mySeat!
        #expect(model.cardInfo(for: me) == CardInfo(playerName: "أحمد", role: PreviewData.mafiaRole, note: "هذا كرتك", alive: true, avatar: "m1"))
        let teammate = model.otherSeats.first { $0.id == "p5" }!
        #expect(model.cardInfo(for: teammate).role == PreviewData.mafiaRole)
        #expect(model.cardInfo(for: teammate).note == "من فريقك 🎭")
        let stranger = model.otherSeats.first { $0.id == "p1" }!
        #expect(model.cardInfo(for: stranger).role == nil)

        let (dayModel, _, _) = board(phase: .morning, room: PreviewData.room(phase: .morning, dead: ["p3"], killed: ["p3"]))
        let dead = dayModel.otherSeats.first { $0.id == "p3" }!
        #expect(dayModel.cardInfo(for: dead).role == PreviewData.citizenRole)
        #expect(dayModel.cardInfo(for: dead).note == "طلع من اللعبة وانكشف كرته")
    }

    @Test func citizenHasNoNightActionsButChatStaysOpen() {
        let (model, _, _) = board(phase: .night, role: .citizen)
        #expect(model.otherSeats.allSatisfy { $0.action == nil })
        #expect(model.writableChannels == [.day])
    }

    @Test func mafiaTalkInTheOpenAtNight() {
        let (model, service, _) = board(phase: .night, role: .mafia)
        #expect(model.writableChannels == [.day])
        model.send("للكل")
        #expect(service.sent.last == .chat(channel: .day, text: "للكل"))
    }

    @Test func judgmentLetsOthersEliminateOrPardonTheAccused() {
        let (model, service, _) = board(phase: .judgment, role: .citizen)
        #expect(model.accusedId == "p2")
        #expect(model.otherSeats.first { $0.id == "p2" }?.accused == true)
        #expect(model.canJudge)
        #expect(model.myJudgment == .eliminate)
        #expect(model.judgmentCounts.eliminate == 2 && model.judgmentCounts.pardon == 1)
        #expect(model.judges(.eliminate).map(\.name) == ["فهد", "ريم"])
        #expect(model.judges(.pardon).map(\.name) == ["خالد"])
        model.judge(.pardon)
        #expect(service.sent.last == .judge(.pardon))
        #expect(model.title == "إقصاء أو إعفاء؟")
    }
}

@MainActor
@Suite struct NarratorLogTests {
    @Test func logsEachNewLineOnceAndClearsInLobby() {
        let service = MockGameService()
        let store = GameStore(service: service, identity: InMemoryIdentityStore())
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: .zero)))
        let night = PreviewData.room(phase: .night)
        store.handle(.message(.state(room: night, me: nil)))
        store.handle(.message(.state(room: night, me: nil)))
        #expect(store.log.map(\.text) == ["الليلة 2", night.narration!])
        store.handle(.message(.state(room: PreviewData.room(phase: .lobby), me: nil)))
        #expect(store.log.isEmpty)
    }

    @Test func nightsAndDaysAreDividedAndDeathsAreRed() {
        let store = GameStore(service: MockGameService(), identity: InMemoryIdentityStore())
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: false, maintenance: false, stats: .zero)))
        store.handle(.message(.state(room: PreviewData.room(phase: .night), me: nil)))
        let killed = PreviewData.room(
            phase: .morning, dead: ["p3", "p6"],
            narration: "دوّى صوت رصاصة في الليل...\nلمى (الضابط) صار ضحية الليل.\nفهد (المواطن) صار ضحية الليل.", killed: ["p3", "p6"]
        )
        store.handle(.message(.state(room: killed, me: nil)))
        store.handle(.message(.state(room: PreviewData.room(phase: .discussion, narration: "وقت النقاش!"), me: nil)))

        // Each event is its own line, and only the players who are out are red.
        #expect(store.log.map(\.text).dropFirst(3).prefix(3) == ["دوّى صوت رصاصة في الليل...", "لمى (الضابط) صار ضحية الليل.", "فهد (المواطن) صار ضحية الليل."])
        #expect(store.log.map(\.tone) == [.divider, .neutral, .divider, .neutral, .danger, .danger, .neutral])
        #expect(store.log.filter { $0.tone == .divider }.map(\.text) == ["الليلة 2", "النهار 2"])
    }
}
