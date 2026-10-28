import Foundation

/// A refused action, sent to the app as an `error` message.
struct LocalError: Error, Equatable {
    enum Code: String {
        case roomNotFound, alreadyInRoom, notInRoom, roomFull, notHost, wrongPhase, notEnoughPlayers
        case alreadyActed, cannotVote, cannotJudge, cannotChat, cannotReveal, badMessage
        case notAlive, noNightAction, invalidTarget, targetDead, cannotTargetTeammate
        case sameAsLastNight, alreadyTargeted, cannotTargetSelf, abilitySpent

        var message: String {
            switch self {
            case .roomNotFound: "هذي النسخة تلعب بدون إنترنت: أنشئ غرفة والعب مع البوتات."
            case .alreadyInRoom: "أنت داخل غرفة أصلاً."
            case .notInRoom: "أنت مو داخل غرفة."
            case .roomFull: "الغرفة مليانة."
            case .notHost: "هذا الإجراء للمضيف بس."
            case .wrongPhase: "مو وقته الحين."
            case .notEnoughPlayers: "تحتاجون 5 لاعبين على الأقل."
            case .alreadyActed: "اخترت خلاص، واختيارك نهائي."
            case .cannotVote: "ما تقدر تصوّت."
            case .cannotJudge: "ما تقدر تحكم على نفسك."
            case .cannotChat: "ما تقدر تكتب هنا الحين."
            case .cannotReveal: "ما تقدر تكشف كرتك الحين."
            case .badMessage: "طلب غير مفهوم."
            case .notAlive: "أنت خارج اللعبة."
            case .noNightAction: "دورك ما له قدرة بالليل."
            case .invalidTarget: "اختيار غير صحيح."
            case .targetDead: "هذا اللاعب خارج اللعبة."
            case .cannotTargetTeammate: "ما تقدر تختار واحد من فريقك."
            case .sameAsLastNight: "حميت هذا الشخص الليلة اللي فاتت."
            case .alreadyTargeted: "حققت مع هذا الشخص قبل."
            case .cannotTargetSelf: "ما تقدر تختار نفسك."
            case .abilitySpent: "استخدمت رصاصتك خلاص."
            }
        }
    }

    let code: Code

    init(_ code: Code) {
        self.code = code
    }
}
