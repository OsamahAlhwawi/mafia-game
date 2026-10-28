import Foundation

struct TargetRules: Sendable {
    var allowSelf: Bool
    /// When false the actor can't pick someone on their own team (mafia can't target mafia).
    var allowTeammates: Bool
    /// The actor can't pick the same player two nights in a row (doctor rule).
    var notSameTargetTwice = false
    /// The actor can't pick anyone they picked on an earlier night (detective rule).
    var notSameTargetAgain = false
}

struct NightAbility: Sendable {
    let kind: AbilityKind
    let targets: TargetRules
    /// First choice is final (detective). Otherwise the actor can change it until night ends.
    var locksOnSubmit = false
    /// Limited uses for the whole game (the officer's single bullet); unlimited when nil.
    var usesPerGame: Int?
}

struct RoleDefinition: Sendable {
    let id: RoleID
    let name: String
    let description: String
    /// Longer explanation shown when a player taps the card in the rules screen.
    let details: String
    let team: Team
    let ability: NightAbility?
    /// Can see the other members of the same team and their live night choices.
    var knowsTeammates = false
    /// How many of this role to deal for a given player count. Ignored for the filler role.
    let count: @Sendable (Int) -> Int
    /// The player may reveal their card by day; from then on their vote counts this many times (the mayor).
    var revealVoteWeight: Int?
    /// Exactly one role fills the remaining seats (the citizen).
    var isFiller = false

    var info: RoleInfo {
        RoleInfo(id: id, name: name, description: description, details: details, team: team, abilityKind: ability?.kind)
    }
}

/// Every role in the game, in dealing order. To add a card, add an entry here
/// (and, for a brand-new kind of night ability, a resolver in `Night.swift`).
enum RoleCatalog {
    static let all: [RoleDefinition] = [
        RoleDefinition(
            id: .mafia,
            name: "المافيا",
            description: "تعرفون بعض بالسر. كل ليلة تتفقون على ضحية من أهل المدينة.",
            details: "أنت من فريق المافيا. تعرف أعضاء فريقك من أول اللعبة، وبالليل تشوفون اختيارات بعض لحظياً وتتكلمون بشات سري. كل واحد يختار ضحية، واللي ياخذ أكثر أصوات يطلع، وإذا تعادلوا ينختار واحد منهم عشوائياً. بالنهار تظاهر إنك مواطن بريء. تفوزون إذا صار عددكم يساوي أو يزيد على أهل المدينة.",
            team: .mafia,
            ability: NightAbility(kind: .teamKill, targets: TargetRules(allowSelf: false, allowTeammates: false)),
            knowsTeammates: true,
            count: { $0 <= 6 ? 1 : 2 }
        ),
        RoleDefinition(
            id: .doctor,
            name: "الطبيب",
            description: "كل ليلة تحمي شخص. تقدر تحمي نفسك، بس مو نفس الشخص ليلتين ورا بعض.",
            details: "أنت من فريق المدينة. كل ليلة تختار شخص تحميه، ولو كان هو ضحية المافيا ينجو والكل يصحى سالم. تقدر تحمي نفسك، بس ما تقدر تحمي نفس الشخص ليلتين ورا بعض. تفوز مع المدينة إذا طلعت كل المافيا.",
            team: .town,
            ability: NightAbility(kind: .protect, targets: TargetRules(allowSelf: true, allowTeammates: true, notSameTargetTwice: true)),
            count: { _ in 1 }
        ),
        RoleDefinition(
            id: .detective,
            name: "المحقق",
            description: "كل ليلة تقلب كرت لاعب واحد بالسر وتعرف دوره.",
            details: "أنت من فريق المدينة. كل ليلة تختار لاعب واحد، وينقلب لك كرته فوراً وبالسر فتعرف دوره بالضبط، واختيارك نهائي لتلك الليلة. وما تقدر تحقق مع نفس الشخص مرتين. ما أحد غيرك يشوف الكرت. استخدم معلوماتك بذكاء في النقاش بدون ما تكشف نفسك، لأن المافيا بتحاول تتخلص منك. تفوز مع المدينة إذا طلعت كل المافيا.",
            team: .town,
            ability: NightAbility(kind: .inspect, targets: TargetRules(allowSelf: false, allowTeammates: true, notSameTargetAgain: true), locksOnSubmit: true),
            count: { _ in 1 }
        ),
        RoleDefinition(
            id: .officer,
            name: "الضابط",
            description: "معك رصاصة وحدة باللعبة كلها. لو أصبت مافيا يموت، ولو أصبت بريء تموت أنت.",
            details: "أنت من فريق المدينة. معك رصاصة وحدة بس للعبة كلها، تطلقها بالليل على أي لاعب. لو طلع مافيا يموت، ولو طلع بريء ما يصير له شي وأنت اللي تموت بدله. الطبيب ما يقدر يوقف الرصاصة. تقدر تغيّر اختيارك أو تلغيه لين تخلص الليلة، والرصاصة ما تنحسب إلا إذا انطلقت. تفوز مع المدينة إذا طلعت كل المافيا.",
            team: .town,
            ability: NightAbility(kind: .shoot, targets: TargetRules(allowSelf: false, allowTeammates: true), usesPerGame: 1),
            count: { $0 >= 7 ? 1 : 0 }
        ),
        RoleDefinition(
            id: .mayor,
            name: "العمدة",
            description: "عمدة الحارة. بالنهار تقدر تكشف كرتك للكل، وبعدها صوتك يصير بثلاثة.",
            details: "أنت من فريق المدينة. ما عندك قدرة بالليل، بس بالنهار تقدر تكشف كرتك للكل مرة وحدة، ومن بعدها صوتك يصير بثلاثة أصوات في التصويت وفي الحكم (إقصاء أو إعفاء). انتبه: أول ما تنكشف بتصير هدف للمافيا. تفوز مع المدينة إذا طلعت كل المافيا.",
            team: .town,
            ability: nil,
            count: { $0 >= 8 ? 1 : 0 },
            revealVoteWeight: 3
        ),
        RoleDefinition(
            id: .citizen,
            name: "المواطن",
            description: "ما عندك قدرات، بس صوتك ونقاشك هم سلاح المدينة.",
            details: "أنت من فريق المدينة. ما عندك قدرة بالليل، بس بالنهار تناقش وتراقب وتصوّت على اللي تشك فيه. انتبه للي يدافع زيادة أو يسكت زيادة. تفوز مع المدينة إذا طلعت كل المافيا.",
            team: .town,
            ability: nil,
            count: { _ in 0 },
            isFiller: true
        ),
    ]

    private static let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static subscript(id: RoleID) -> RoleDefinition {
        guard let def = byId[id] else { preconditionFailure("unknown role \(id.rawValue)") }
        return def
    }
}

/// The minimal player shape the pure rules need.
struct CorePlayer: Sendable {
    let id: String
    let role: RoleID
    var alive: Bool

    var def: RoleDefinition { RoleCatalog[role] }
}
