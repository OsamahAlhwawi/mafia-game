import Foundation

struct BotTurn: Sendable {
    let delay: Double
    let act: @MainActor @Sendable (LocalRoom) throws(LocalError) -> Void
}

/// The other players. Simple on purpose: random but valid choices, nudged by what
/// the bot's role knows (the mafia spare each other, the detective uses its findings).
@MainActor
enum Bots {
    static let names = ["بوت سعود", "بوت هيا", "بوت مشاري", "بوت جود", "بوت تركي", "بوت دانة", "بوت راشد", "بوت لولوة", "بوت بدر", "بوت شهد", "بوت ناصر"]

    private static let female: Set<String> = ["بوت هيا", "بوت جود", "بوت دانة", "بوت لولوة", "بوت شهد"]

    /// A fixed gender and avatar per bot name, so a bot looks the same every game.
    static func look(for name: String) -> (gender: Gender, avatar: String) {
        let gender: Gender = female.contains(name) ? .female : .male
        let index = name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 8 + 1
        return (gender, "\(gender == .female ? "f" : "m")\(index)")
    }

    private static let lines = [
        "أنا مواطن والله، لا تطالعوني كذا 😅",
        "أحس فيه أحد ساكت زيادة عن اللزوم...",
        "خلونا نركز، مين تكلم أقل شي أمس؟",
        "أنا شاك بواحد بس ما راح أقول الحين",
        "صوّتوا بعقل، لا نطلّع واحد من المدينة",
        "ليش محد يتكلم؟ 🤔",
        "أنا عندي شك قوي بس أبي أتأكد",
        "اللي مات أمس كان بريء، انتبهوا",
    ]

    private static let defenseLines = [
        "والله مظلوم! أنا مواطن وأقدر أثبت",
        "لو طلعتوني بتخسرون واحد من المدينة",
        "المافيا هي اللي وجهت الأصوات علي، انتبهوا",
    ]

    /// What each bot does in the phase that just started, and when.
    static func plan(for room: LocalRoom) -> [BotTurn] {
        let rng = room.rng
        let timings = room.timings
        func delay() -> Double {
            timings.botDelay.lowerBound + rng.next() * (timings.botDelay.upperBound - timings.botDelay.lowerBound)
        }

        var turns: [BotTurn] = []
        for bot in room.players where bot.isBot && bot.alive {
            guard let def = bot.def else { continue }
            let id = bot.id
            switch room.phase {
            case .night:
                guard let ability = def.ability else { continue }
                // The officer keeps the single bullet for later most nights.
                if ability.usesPerGame != nil && rng.next() > 0.3 { continue }
                turns.append(BotTurn(delay: delay()) { room throws(LocalError) in
                    if let target = nightTarget(for: id, in: room) { try room.nightAction(by: id, targetId: target) }
                })
            case .voting:
                turns.append(BotTurn(delay: delay()) { room throws(LocalError) in
                    try room.vote(by: id, targetId: room.rng.chance(0.2) ? nil : suspect(for: id, in: room))
                })
            case .defense where id == room.accusedId:
                turns.append(BotTurn(delay: delay()) { room throws(LocalError) in
                    try room.chat(by: id, channel: .day, text: room.rng.pick(defenseLines))
                })
            case .judgment where id != room.accusedId:
                turns.append(BotTurn(delay: delay()) { room throws(LocalError) in
                    try room.judge(by: id, judgment(for: id, in: room))
                })
            case .discussion:
                if def.revealVoteWeight != nil && rng.chance(0.4) {
                    turns.append(BotTurn(delay: delay()) { room throws(LocalError) in try room.revealRole(by: id) })
                }
                // A couple of lines spread across the discussion, so the table feels alive.
                for _ in 0..<2 where rng.chance(0.6) {
                    turns.append(BotTurn(delay: 0.8 + rng.next() * timings.botChatSpan) { room throws(LocalError) in
                        try room.chat(by: id, channel: .day, text: chatLine(for: id, in: room))
                    })
                }
            default:
                continue
            }
        }
        return turns
    }

    // MARK: Choices

    /// The mafia follow a teammate's pick when there is one; everyone else picks at random.
    private static func nightTarget(for id: String, in room: LocalRoom) -> String? {
        let options = room.validNightTargets(for: id)
        guard !options.isEmpty else { return nil }
        if room.player(id)?.def?.ability?.kind == .teamKill {
            let teamPicks = room.players
                .filter { $0.id != id && $0.alive && $0.def?.team == .mafia }
                .compactMap { room.nightChoices[$0.id] ?? nil }
                .filter(options.contains)
            if !teamPicks.isEmpty && room.rng.chance(0.7) { return room.rng.pick(teamPicks) }
        }
        return room.rng.pick(options)
    }

    /// Mafia found by this bot's own investigations and still alive.
    private static func knownMafia(for id: String, in room: LocalRoom) -> [String] {
        (room.inspections[id] ?? []).filter { $0.isMafia && room.player($0.targetId)?.alive == true }.map(\.targetId)
    }

    /// Who this bot votes against: never a teammate for the mafia, a found mafia for the detective.
    private static func suspect(for id: String, in room: LocalRoom) -> String? {
        let me = room.player(id)
        if let found = knownMafia(for: id, in: room).first { return found }
        let cleared = Set((room.inspections[id] ?? []).filter { !$0.isMafia }.map(\.targetId))
        let others = room.players.filter { p in
            p.alive && p.id != id && !cleared.contains(p.id) && !(me?.def?.team == .mafia && p.def?.team == .mafia)
        }
        return others.isEmpty ? nil : room.rng.pick(others).id
    }

    private static func judgment(for id: String, in room: LocalRoom) -> Judgment {
        guard let accused = room.player(room.accusedId) else { return .pardon }
        if room.player(id)?.def?.team == .mafia {
            return accused.def?.team == .mafia ? .pardon : .eliminate
        }
        if let finding = room.inspections[id]?.last(where: { $0.targetId == accused.id }) {
            return finding.isMafia ? .eliminate : .pardon
        }
        return room.rng.chance(0.55) ? .eliminate : .pardon
    }

    private static func chatLine(for id: String, in room: LocalRoom) -> String {
        if let found = knownMafia(for: id, in: room).first, let name = room.player(found)?.name, room.rng.chance(0.5) {
            return "حققت وتأكدت: \(name) من المافيا!"
        }
        return room.rng.pick(lines)
    }
}
