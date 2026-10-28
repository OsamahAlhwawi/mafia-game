import SwiftUI

/// Night (dark navy) or day (warm sand). Home and lobby use night as the app's identity.
enum PhaseTheme: Equatable {
    case night, day

    init(phase: GamePhase?, winner: Winner? = nil) {
        switch phase {
        case .morning, .discussion, .voting, .defense, .judgment, .verdict: self = .day
        case .ended: self = winner == .town ? .day : .night
        default: self = .night
        }
    }

    var text: Color { self == .night ? Palette.Night.text : Palette.Day.text }
    var muted: Color { self == .night ? Palette.Night.muted : Palette.Day.muted }
    var surface: Color { self == .night ? Palette.Night.surface.opacity(0.85) : Palette.Day.surface.opacity(0.85) }
    var stroke: Color { self == .night ? Palette.Night.moon.opacity(0.18) : Palette.Day.stroke }
    /// Gold that stays readable as text on this theme's background.
    var accentText: Color { self == .night ? Palette.gold : Palette.goldDeep }
    var colorScheme: ColorScheme { self == .night ? .dark : .light }
}

private struct PhaseThemeKey: EnvironmentKey {
    static let defaultValue: PhaseTheme = .night
}

extension EnvironmentValues {
    var phaseTheme: PhaseTheme {
        get { self[PhaseThemeKey.self] }
        set { self[PhaseThemeKey.self] = newValue }
    }
}
