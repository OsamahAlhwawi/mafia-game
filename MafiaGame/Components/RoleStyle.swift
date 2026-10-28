import SwiftUI

/// How a role's card looks. Add an entry here when adding a role on the server;
/// unknown roles get `fallback` so a new server role never breaks the app.
struct RoleStyle {
    let gradient: [Color]
    let foreground: Color
    let muted: Color
    let symbol: String

    static func of(_ role: RoleID) -> RoleStyle {
        registry[role] ?? fallback
    }

    static let registry: [RoleID: RoleStyle] = [
        .mafia: RoleStyle(
            gradient: [Color(hex: 0xA11D2A), Color(hex: 0x4A0A14)],
            foreground: Color(hex: 0xFFF1EE), muted: Color(hex: 0xF2C9C4), symbol: "theatermasks.fill"
        ),
        .doctor: RoleStyle(
            gradient: [Color(hex: 0x237F52), Color(hex: 0x0F4D30)],
            foreground: Color(hex: 0xF0FFF6), muted: Color(hex: 0xC4E8D3), symbol: "cross.case.fill"
        ),
        .detective: RoleStyle(
            gradient: [Color(hex: 0x2A66AB), Color(hex: 0x0F2E57)],
            foreground: Color(hex: 0xEEF5FF), muted: Color(hex: 0xC5D8F0), symbol: "magnifyingglass"
        ),
        .officer: RoleStyle(
            gradient: [Color(hex: 0x34405A), Color(hex: 0x141A2B)],
            foreground: Color(hex: 0xEEF1F8), muted: Color(hex: 0xC3CADB), symbol: "scope"
        ),
        .mayor: RoleStyle(
            gradient: [Color(hex: 0xC8932E), Color(hex: 0x7A4E12)],
            foreground: Color(hex: 0xFFF8E8), muted: Color(hex: 0xF2DDB0), symbol: "building.columns.fill"
        ),
        .citizen: RoleStyle(
            gradient: [Color(hex: 0xEBD9AE), Color(hex: 0xC49A5C)],
            foreground: Color(hex: 0x2B2116), muted: Color(hex: 0x3D2F1E), symbol: "person.fill"
        ),
    ]

    static let fallback = RoleStyle(
        gradient: [Color(hex: 0x5B4B8A), Color(hex: 0x2A2148)],
        foreground: Color(hex: 0xF3EEFF), muted: Color(hex: 0xD3CAEE), symbol: "questionmark.circle.fill"
    )
}
