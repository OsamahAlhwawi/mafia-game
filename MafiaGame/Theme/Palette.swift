import SwiftUI

extension Color {
    /// `Color(hex: 0x0B1026)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Colors from the approved design preview.
enum Palette {
    static let gold = Color(hex: 0xD4A84B)
    static let goldDeep = Color(hex: 0x8A5A12)

    enum Night {
        static let top = Color(hex: 0x0B1026)
        static let bottom = Color(hex: 0x1B2550)
        static let surface = Color(hex: 0x161D3F)
        static let cardBack = Color(hex: 0x121938)
        static let text = Color(hex: 0xEDEBF5)
        static let muted = Color(hex: 0xA9B0D6)
        static let moon = Color(hex: 0xC9D4FF)
    }

    enum Day {
        static let top = Color(hex: 0xFBF4E6)
        static let bottom = Color(hex: 0xF3E2C3)
        static let surface = Color.white
        static let stroke = Color(hex: 0xE6D3AE)
        static let text = Color(hex: 0x2B2116)
        static let muted = Color(hex: 0x5C4A33)
        static let sun = Color(hex: 0xF2A93B)
    }

    static let danger = Color(hex: 0xB3202E)
}
