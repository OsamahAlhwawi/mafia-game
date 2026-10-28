import Foundation

/// Sample snapshots for SwiftUI previews (and handy in tests).
@MainActor
enum PreviewData {
    static let mafiaRole = RoleInfo(id: .mafia, name: "المافيا", description: "تعرفون بعض بالسر. كل ليلة تتفقون على ضحية من أهل المدينة.", details: "تفاصيل دور المافيا.", team: .mafia, abilityKind: .teamKill)
    static let doctorRole = RoleInfo(id: .doctor, name: "الطبيب", description: "كل ليلة تحمي شخص. تقدر تحمي نفسك، بس مو نفس الشخص ليلتين ورا بعض.", details: "تفاصيل دور الطبيب.", team: .town, abilityKind: .protect)
    static let detectiveRole = RoleInfo(id: .detective, name: "المحقق", description: "كل ليلة تكشف حقيقة لاعب واحد: مافيا ولا لا.", details: "تفاصيل دور المحقق.", team: .town, abilityKind: .inspect)
    static let officerRole = RoleInfo(id: .officer, name: "الضابط", description: "معك رصاصة وحدة باللعبة كلها. لو أصبت مافيا يموت، ولو أصبت بريء تموت أنت.", details: "تفاصيل دور الضابط.", team: .town, abilityKind: .shoot)
    static let mayorRole = RoleInfo(id: .mayor, name: "العمدة", description: "عمدة الحارة. بالنهار تقدر تكشف كرتك للكل، وبعدها صوتك يصير بثلاثة.", details: "تفاصيل دور العمدة.", team: .town, abilityKind: nil)
    static let citizenRole = RoleInfo(id: .citizen, name: "المواطن", description: "ما عندك قدرات، بس صوتك ونقاشك هم سلاح المدينة.", details: "تفاصيل دور المواطن.", team: .town, abilityKind: nil)

    static func role(_ id: RoleID) -> RoleInfo {
        [mafiaRole, doctorRole, detectiveRole, officerRole, mayorRole, citizenRole].first { $0.id == id } ?? citizenRole
    }

    static let names = ["أحمد", "نورة", "سارة", "فهد", "ريم", "خالد", "لمى"]
    /// Who holds which role in the sample game (by seat index).
    static let dealtRoles: [RoleID] = [.mafia, .doctor, .detective, .citizen, .citizen, .mafia, .officer]

    static let deck = [
        DeckEntry(role: mafiaRole, count: 2), DeckEntry(role: doctorRole, count: 1),
        DeckEntry(role: detectiveRole, count: 1), DeckEntry(role: officerRole, count: 1),
        DeckEntry(role: citizenRole, count: 2),
    ]

    static func players(dead: Set<String> = []) -> [PublicPlayer] {
        names.enumerated().map { i, name in
            PublicPlayer(
                id: "p\(i)", name: name, alive: !dead.contains("p\(i)"), connected: true, isBot: i > 4, isHost: i == 0,
                gender: [1, 2, 4, 6].contains(i) ? .female : .male, avatar: [1, 2, 4, 6].contains(i) ? "f\(i + 1)" : "m\(i + 1)", pending: false
            )
        }
    }

    static func room(
        phase: GamePhase,
        dead: Set<String> = [],
        narration: String? = "حلّ الليل... المافيا تختار ضحيتها.",
        votedIds: [String] = [],
        verdict: VerdictInfo? = nil,
        winner: Winner? = nil,
        revealed: [RevealedRole]? = nil,
        killed: [String] = []
    ) -> RoomSnapshot {
        let now = Date().timeIntervalSince1970 * 1000
        let deadRoles = dead.sorted().map { id in RevealedRole(playerId: id, role: role(dealtRoles[Int(id.dropFirst())!])) }
        return RoomSnapshot(
            code: "482913", name: "سهرة الخميس", isPrivate: false, hostId: "p0", phase: phase, phaseSeq: 3,
            phaseEndsAt: phase == .lobby || phase == .ended ? nil : now + 42_000, serverNow: now,
            round: 2,
            settings: RoomSettings(
                discussionSeconds: 120, fastTimers: false, minPlayers: 5, maxPlayers: 9,
                mafia: MafiaSetting(count: nil, max: 2),
                optionalRoles: [doctorRole, detectiveRole, officerRole, mayorRole].map { OptionalRole(role: $0, enabled: $0.id != .mayor) }
            ),
            players: players(dead: dead), narration: phase == .lobby ? nil : narration,
            lastNightKilledIds: killed, votedIds: votedIds,
            liveTally: phase == .voting ? [TallyEntry(targetId: "p3", count: 2), TallyEntry(targetId: "p1", count: 1)] : [],
            liveAbstain: phase == .voting ? 1 : 0,
            accusedId: [.defense, .judgment, .verdict].contains(phase) ? "p2" : nil,
            judgment: phase == .judgment ? JudgmentCounts(eliminate: 2, pardon: 1, votes: [
                JudgmentVote(voterId: "p3", choice: .eliminate), JudgmentVote(voterId: "p4", choice: .eliminate),
                JudgmentVote(voterId: "p5", choice: .pardon),
            ]) : nil,
            verdict: verdict, winner: winner, deck: deck, revealedRoles: revealed ?? deadRoles
        )
    }

    static func me(role: RoleID?, phase: GamePhase, alive: Bool = true) -> PrivateSnapshot {
        let night = phase == .night
        let isMafia = role == .mafia
        return PrivateSnapshot(
            playerId: "p0",
            role: role.map(Self.role),
            alive: alive,
            teammates: isMafia ? [Teammate(id: "p5", name: "خالد")] : nil,
            teamChoices: isMafia && night ? [TeamChoice(actorId: "p0", targetId: "p2"), TeamChoice(actorId: "p5", targetId: "p3")] : nil,
            myNightTarget: night && role != .citizen ? "p2" : nil,
            // As the server computes them: mafia skip teammates, the detective can't pick themself.
            validTargetIds: night ? (isMafia ? ["p1", "p2", "p3", "p4", "p6"] : role == .detective ? ["p1", "p2", "p3", "p4", "p5", "p6"] : ["p0", "p1", "p2", "p3", "p4", "p5", "p6"]) : [],
            nightActionLocked: night && role == .detective,
            inspections: role == .detective ? [InspectionResult(round: 1, targetId: "p4", isMafia: false, role: citizenRole), InspectionResult(round: 2, targetId: "p2", isMafia: true, role: mafiaRole)] : [],
            myVote: phase == .voting ? "p3" : nil,
            myJudgment: phase == .judgment ? .eliminate : nil,
            // Chat is open all the time for the living; there's no private mafia channel.
            writableChannels: !alive ? [.dead] : [.day],
            forcedRole: nil,
            canDebug: true
        )
    }

    /// A store already showing the given phase; `nil` is the home screen.
    static func store(phase: GamePhase?, role: RoleID = .mafia) -> GameStore {
        let store = GameStore(service: MockGameService(), identity: InMemoryIdentityStore(profile: Profile(nickname: "أحمد", gender: .male, avatar: "m1")))
        store.handle(.status(.connected))
        store.handle(.message(.welcome(playerId: "p0", token: "t", debugEnabled: true, maintenance: false, stats: PlayerStats(games: 12, wins: 7, mafiaGames: 4, mafiaWins: 2))))
        guard let phase else { return store }

        let room: RoomSnapshot
        switch phase {
        case .morning:
            room = Self.room(phase: .morning, dead: ["p3"], narration: "فهد (المواطن) صار ضحية الليل.", killed: ["p3"])
        case .voting:
            room = Self.room(phase: .voting, dead: ["p3"], votedIds: ["p0", "p1", "p4"])
        case .verdict:
            let votes = [VoteEntry(voterId: "p0", targetId: "p2"), VoteEntry(voterId: "p1", targetId: "p2"), VoteEntry(voterId: "p2", targetId: "p1"), VoteEntry(voterId: "p4", targetId: "p2"), VoteEntry(voterId: "p5", targetId: nil), VoteEntry(voterId: "p6", targetId: "p1")]
            room = Self.room(
                phase: .verdict, dead: ["p3", "p2"], narration: "المدينة طردت سارة (المحقق).",
                verdict: VerdictInfo(
                    votes: votes, tally: [TallyEntry(targetId: "p2", count: 3), TallyEntry(targetId: "p1", count: 2)], abstain: 1, eliminatedId: "p2", reason: "majority",
                    trial: TrialResult(accusedId: "p2", eliminate: 3, pardon: 1, votes: [], outcome: "eliminated")
                )
            )
        case .ended:
            let roles = dealtRoles
            room = Self.room(
                phase: .ended, dead: ["p0", "p5", "p3"], narration: "انكشفت المافيا كلها! فاز أهل المدينة!",
                winner: .town, revealed: roles.enumerated().map { RevealedRole(playerId: "p\($0)", role: Self.role($1)) }
            )
        default:
            room = Self.room(phase: phase)
        }
        store.handle(.message(.state(room: room, me: me(role: phase == .lobby ? nil : role, phase: phase))))
        if phase == .discussion || phase == .night {
            let channel: ChatChannel = phase == .night ? .mafia : .day
            store.handle(.message(.chatHistory([
                ChatMessage(id: "1", channel: channel, senderId: "p5", senderName: "خالد", text: "فهد أخطر واحد، شكله يشك فينا", sentAt: 0),
                ChatMessage(id: "2", channel: channel, senderId: "p0", senderName: "أحمد", text: "خلنا نركز على سارة", sentAt: 0),
            ])))
        }
        return store
    }
}
