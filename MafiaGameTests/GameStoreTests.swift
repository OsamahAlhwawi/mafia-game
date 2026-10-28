import Foundation
import Testing
@testable import MafiaGame

@MainActor
@Suite struct GameStoreTests {
    let service = MockGameService()
    let identity = InMemoryIdentityStore()
    let store: GameStore

    init() {
        store = GameStore(service: service, identity: identity)
    }

    private let welcome = ServerMessage.welcome(playerId: "me", token: "tok", debugEnabled: false, maintenance: true, stats: PlayerStats(games: 3, wins: 1, mafiaGames: 1, mafiaWins: 0))

    @Test func savingTheProfileConnectsAndQueuesIntentsUntilWelcome() {
        store.saveProfile(Profile(nickname: "  أسامة ", gender: .male, avatar: "m3"))
        let profile = Profile(nickname: "أسامة", gender: .male, avatar: "m3")
        #expect(identity.profile == profile)
        #expect(service.sent == [.hello(token: nil, profile: profile)])
        store.createRoom(name: "  ", capacity: 6, isPrivate: true)

        store.handle(.status(.connected))
        store.handle(.message(welcome))
        #expect(store.playerId == "me")
        #expect(identity.token == "tok")
        #expect(store.maintenance && !store.debugEnabled && store.stats.games == 3)
        #expect(service.sent.last == .createRoom(name: nil, capacity: 6, isPrivate: true))
    }

    @Test func aRejectedNameAsksAgainAndRetriesHello() {
        store.saveProfile(Profile(nickname: "كلب", gender: .male, avatar: "m1"))
        store.handle(.status(.connected))
        store.handle(.message(.error(code: "nameRejected", message: "x")))
        #expect(store.profileRejected)
        store.saveProfile(Profile(nickname: "سعد", gender: .male, avatar: "m1"))
        #expect(!store.profileRejected)
        #expect(service.sent.last == .hello(token: nil, profile: Profile(nickname: "سعد", gender: .male, avatar: "m1")))
    }

    @Test func theRoomListArrivesOnlyWhileWatching() {
        store.handle(.status(.connected))
        store.handle(.message(welcome))
        let listing = RoomListing(code: "123456", name: "غرفة", hostName: "نورة", hostAvatar: "f1", count: 2, capacity: 8, status: .open, round: 0)
        store.handle(.message(.rooms([listing])))
        #expect(store.roomList.isEmpty)
        store.watchRooms(true)
        #expect(service.sent.last == .watchRooms(true))
        store.handle(.message(.rooms([listing])))
        #expect(store.roomList == [listing])
        store.watchRooms(false)
        #expect(store.roomList.isEmpty)
    }

    @Test func noticesAndAdminChangesSurface() {
        store.handle(.message(.notice("انطردت من الغرفة")))
        #expect(store.notice == "انطردت من الغرفة")
        store.handle(.message(.serverStatus(debugEnabled: true, maintenance: true)))
        #expect(store.debugEnabled && store.maintenance)
        store.handle(.message(.error(code: "upgradeRequired", message: "x")))
        #expect(store.updateRequired)
    }

    @Test func resultsStayUpWhileIAmPendingAndOthersAreInTheLobby() {
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: false, maintenance: false, stats: .zero)))
        let ended = PreviewData.room(phase: .ended, winner: .town)
        store.handle(.message(.state(room: ended, me: PreviewData.me(role: .mafia, phase: .ended))))
        let lobby = RoomSnapshot.lobby(from: ended, pending: ["p0"])
        store.handle(.message(.state(room: lobby, me: PreviewData.me(role: nil, phase: .lobby))))
        #expect(store.room?.phase == .ended)
        store.playAgain()
        #expect(service.sent.last == .playAgain)
        store.handle(.message(.state(room: RoomSnapshot.lobby(from: ended, pending: []), me: PreviewData.me(role: nil, phase: .lobby))))
        #expect(store.room?.phase == .lobby)
    }

    @Test func stateUpdatesRoomAndCountdown() {
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: .zero)))
        let room = PreviewData.room(phase: .night)
        store.handle(.message(.state(room: room, me: PreviewData.me(role: .mafia, phase: .night))))
        #expect(store.room?.phase == .night)
        #expect(store.isHost)
        let remaining = store.phaseEndsAt!.timeIntervalSinceNow
        #expect(abs(remaining - 42) < 2)
        #expect(abs(store.phaseTotal - 42) < 0.01)
    }

    @Test func chatDedupesAndClearsWhenLeaving() {
        let message = ChatMessage(id: "m1", channel: .day, senderId: "p1", senderName: "نورة", text: "هلا", sentAt: 0)
        store.handle(.message(.chat(message)))
        store.handle(.message(.chat(message)))
        #expect(store.chat.count == 1)
        #expect(store.messages(in: .mafia).isEmpty)
        store.handle(.message(.state(room: nil, me: nil)))
        #expect(store.chat.isEmpty)
    }

    @Test func errorsSurface() {
        store.handle(.message(.error(code: "roomNotFound", message: "ما لقينا غرفة بهذا الكود.")))
        #expect(store.lastError?.code == "roomNotFound")
    }

    @Test func emptyChatIsNotSent() {
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: .zero)))
        store.sendChat("   ", channel: .day)
        #expect(service.sent.isEmpty)
        store.sendChat(" مرحبا ", channel: .day)
        #expect(service.sent == [.chat(channel: .day, text: "مرحبا")])
    }
}

extension RoomSnapshot {
    /// The same room back in the lobby after a game, with these players still on the results.
    static func lobby(from room: RoomSnapshot, pending: Set<String>) -> RoomSnapshot {
        RoomSnapshot(
            code: room.code, name: room.name, isPrivate: room.isPrivate, hostId: room.hostId, phase: .lobby, phaseSeq: room.phaseSeq + 1,
            phaseEndsAt: nil, serverNow: room.serverNow, round: 0, settings: room.settings,
            players: room.players.map {
                PublicPlayer(id: $0.id, name: $0.name, alive: true, connected: true, isBot: $0.isBot, isHost: $0.isHost,
                             gender: $0.gender, avatar: $0.avatar, pending: pending.contains($0.id))
            },
            narration: nil, lastNightKilledIds: [], votedIds: [], liveTally: [], liveAbstain: 0, accusedId: nil, judgment: nil,
            verdict: nil, winner: nil, deck: room.deck, revealedRoles: []
        )
    }
}
