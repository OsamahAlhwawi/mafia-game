import Foundation
import Testing
@testable import MafiaGame

/// Decodes JSON recorded from the online game server (fixtures/), so the
/// app keeps speaking the same protocol.
@Suite struct FixtureDecodingTests {
    private final class BundleToken {}

    private func fixture(_ name: String) throws -> ServerMessage {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "fixtures"), "missing fixture \(name)")
        return try JSONDecoder().decode(ServerMessage.self, from: Data(contentsOf: url))
    }

    @Test func everyFixtureDecodes() throws {
        let bundle = Bundle(for: BundleToken.self)
        let urls = try #require(bundle.urls(forResourcesWithExtension: "json", subdirectory: "fixtures"))
        #expect(urls.count >= 14)
        for url in urls {
            let message = try JSONDecoder().decode(ServerMessage.self, from: Data(contentsOf: url))
            if case let .unknown(type) = message { Issue.record("unknown message type \(type) in \(url.lastPathComponent)") }
        }
    }

    @Test func mafiaSeesTeamChoicesAtNight() throws {
        guard case let .state(room, me) = try fixture("state_night_mafia") else { Issue.record("not a state"); return }
        #expect(room?.phase == .night)
        #expect(me?.role?.id == .mafia)
        #expect(me?.role?.abilityKind == .teamKill)
        #expect(me?.teamChoices?.first?.targetId == "p3")
    }

    @Test func detectiveGetsInspection() throws {
        guard case let .state(_, me) = try fixture("state_night_detective") else { Issue.record("not a state"); return }
        #expect(me?.inspections.count == 1)
        #expect(me?.inspections.first?.targetId == "p0")
        #expect(me?.inspections.first?.isMafia == true)
        #expect(me?.inspections.first?.role.id == .mafia)
        #expect(me?.nightActionLocked == true)
        #expect(me?.teammates == nil)
    }

    @Test func verdictAndEndScreens() throws {
        guard case let .state(verdictRoom, _) = try fixture("state_verdict") else { Issue.record("not a state"); return }
        #expect(verdictRoom?.verdict?.eliminatedId == "p0")
        guard case let .state(endRoom, _) = try fixture("state_ended") else { Issue.record("not a state"); return }
        #expect(endRoom?.winner == .town)
        #expect(endRoom?.revealedRoles?.count == 5)
    }

    @Test func trialPhasesDecode() throws {
        guard case let .state(defense, _) = try fixture("state_defense") else { Issue.record("not a state"); return }
        #expect(defense?.phase == .defense)
        #expect(defense?.accusedId == "p0")
        guard case let .state(judgment, me) = try fixture("state_judgment") else { Issue.record("not a state"); return }
        #expect(judgment?.judgment?.eliminate == 1 && judgment?.judgment?.pardon == 0)
        #expect(judgment?.judgment?.votes == [JudgmentVote(voterId: "p1", choice: .eliminate)])
        #expect(me?.myJudgment == .eliminate)
        guard case let .state(verdict, _) = try fixture("state_verdict") else { Issue.record("not a state"); return }
        #expect(verdict?.verdict?.trial?.outcome == "eliminated")
        guard case let .state(voting, _) = try fixture("state_voting") else { Issue.record("not a state"); return }
        #expect(voting?.liveTally == [TallyEntry(targetId: "p0", count: 1)])
    }

    @Test func otherMessages() throws {
        guard case let .welcome(playerId, token, debugEnabled, maintenance, stats) = try fixture("welcome") else { Issue.record("not welcome"); return }
        #expect(playerId == "p0" && token == "secret-token" && debugEnabled && !maintenance)
        #expect(stats == PlayerStats(games: 12, wins: 7, mafiaGames: 3, mafiaWins: 2))
        guard case let .serverStatus(debug, closed) = try fixture("serverStatus") else { Issue.record("not serverStatus"); return }
        #expect(!debug && closed)
        guard case let .rooms(rooms) = try fixture("rooms") else { Issue.record("not rooms"); return }
        #expect(rooms.first?.status == .open && rooms.first?.capacity == 9)
        guard case let .stats(next) = try fixture("stats") else { Issue.record("not stats"); return }
        #expect(next.games == 13)
        guard case let .notice(text) = try fixture("notice") else { Issue.record("not notice"); return }
        #expect(text.contains("ساعة"))
        guard case let .error(code, _) = try fixture("error") else { Issue.record("not error"); return }
        #expect(code == "roomNotFound")
        guard case let .state(room, me) = try fixture("state_none") else { Issue.record("not state"); return }
        #expect(room == nil && me == nil)
    }

    @Test func lobbyCarriesTheDeckWithDetails() throws {
        guard case let .state(room, _) = try fixture("state_lobby") else { Issue.record("not a state"); return }
        #expect(room?.deck.map(\.count) == [1, 1, 1, 2])
        #expect(room?.deck.allSatisfy { !$0.role.details.isEmpty } == true)
        #expect(room?.settings.maxPlayers == 9)
    }

    @Test func unknownRoleStillDecodes() throws {
        let json = #"{"id":"sniper","name":"القناص","description":"x","details":"y","team":"town","abilityKind":"shoot"}"#
        let role = try JSONDecoder().decode(RoleInfo.self, from: Data(json.utf8))
        #expect(role.id.rawValue == "sniper")
        #expect(role.abilityKind?.rawValue == "shoot")
    }
}

@Suite struct ClientMessageEncodingTests {
    private func json(_ message: ClientMessage) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any] ?? [:]
    }

    @Test func nilTargetIsSentAsNull() throws {
        let body = try json(.nightAction(targetId: nil))
        #expect(body["type"] as? String == "nightAction")
        #expect(body.keys.contains("targetId"))
        #expect(body["targetId"] is NSNull)
    }

    @Test func helloCarriesTheProtocolAndProfile() throws {
        let body = try json(.hello(token: nil, profile: Profile(nickname: "نورة", gender: .female, avatar: "f3")))
        #expect(!body.keys.contains("token"))
        #expect(body["protocol"] as? Int == protocolVersion)
        #expect(body["nickname"] as? String == "نورة")
        #expect(body["gender"] as? String == "female")
        #expect(body["avatar"] as? String == "f3")
    }

    @Test func createRoomOmitsAnEmptyName() throws {
        let body = try json(.createRoom(name: nil, capacity: 6, isPrivate: true))
        #expect(!body.keys.contains("name"))
        #expect(body["capacity"] as? Int == 6)
        #expect(body["isPrivate"] as? Bool == true)
    }

    @Test func judge() throws {
        #expect(try json(.judge(.eliminate))["choice"] as? String == "eliminate")
    }

    @Test func chatAndVote() throws {
        #expect(try json(.chat(channel: .mafia, text: "هلا"))["channel"] as? String == "mafia")
        #expect(try json(.vote(targetId: "p2"))["targetId"] as? String == "p2")
    }
}
