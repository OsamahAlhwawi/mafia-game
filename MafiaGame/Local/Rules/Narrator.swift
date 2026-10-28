import Foundation

// Each line is picked at random so the narrator doesn't repeat itself.
// Lines stay short (one event each) so they read large on the table.
// Lines avoid gendered verbs because names can belong to anyone.
// A player who is out is always written «{name} ({role})»: the app colors those lines red.
enum Narration {
    case roleReveal, nightFalls, killed, nobodyDied, saved, shot, mayorRevealed
    case discussion, voting, defense, judgment, pardoned, votedOut, noOneVotedOut
    case draw, townWins, mafiaWins

    fileprivate var lines: [String] {
        switch self {
        case .roleReveal: ["اقلب كرتك بالسر... اللعبة بتبدأ.", "كل واحد فيكم يحمل سر. اكشف دورك بهدوء."]
        case .nightFalls: ["حلّ الليل... المافيا تختار ضحيتها.", "انطفت أنوار المدينة.", "ليل جديد، والمافيا صاحية."]
        case .killed: ["{name} ({role}) صار ضحية الليل.", "لقوا {name} ({role}) بلا حراك.", "المافيا أخذت {name} ({role})."]
        case .nobodyDied: ["الليلة مرّت بسلام، والكل نجا.", "صباح هادي... ما أحد طلع الليلة."]
        // The mafia struck but the doctor protected their target. Never names who was saved.
        case .saved: ["المافيا ضربت، بس يد خفية وصلت قبلهم!", "أحد سهر وحمى الضحية. الكل نجا!", "الطبيب كان أسرع من المافيا!"]
        // The officer fired. Opens the morning; the lines after it tell who fell.
        case .shot: ["دوّى صوت رصاصة في الليل...", "طلقة وحدة كسرت سكون الليل..."]
        case .mayorRevealed: ["انكشف كرت {name}: العمدة! صوته بثلاثة.", "العمدة بيننا: {name}. صوته بثلاثة."]
        case .discussion: ["وقت النقاش! مين تشكّون فيه؟", "المدينة تجتمع في الساحة... تكلموا."]
        case .voting: ["وقت التصويت! صوّتوا أو امتنعوا.", "الكلام خلص... مين بيطلع اليوم؟"]
        case .defense: ["تم اختيار {name} للحكم.", "كل العيون على {name}. وقت الدفاع."]
        case .judgment: ["إقصاء {name} ولا إعفاء؟", "المدينة تقرر مصير {name}."]
        case .pardoned: ["المدينة عفت عن {name}.", "نجا {name} من الإقصاء."]
        case .votedOut: ["المدينة طردت {name} ({role}).", "بأغلبية الأصوات طلع {name} ({role})."]
        case .noOneVotedOut: ["الأصوات تفرّقت، وما أحد طلع.", "ما اتفقت المدينة على أحد."]
        case .draw: ["ما انحسم شي... تعادل!", "المدينة ما حسمت أمرها. تعادل!"]
        case .townWins: ["انكشفت المافيا كلها! فاز أهل المدينة!", "العدالة انتصرت! فاز أهل المدينة!"]
        case .mafiaWins: ["سقطت المدينة! فازت المافيا!", "المافيا سيطرت على المدينة! فازت المافيا!"]
        }
    }

    static func winner(_ winner: Winner) -> Narration {
        switch winner {
        case .town: .townWins
        case .mafia: .mafiaWins
        case .draw: .draw
        }
    }
}

extension GameRandom {
    func narrate(_ key: Narration, name: String = "", role: String = "") -> String {
        pick(key.lines)
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{role}", with: role)
    }
}
