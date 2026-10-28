import UIKit

/// For moments that aren't tied to a single view's state change (most views use `.sensoryFeedback`).
@MainActor
enum Haptics {
    static func announce(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// A choice in the game (kill, protect, inspect, vote, abstain, eliminate/pardon), felt as the finger lands.
    static func choose() {
        tap(.medium)
    }
}
