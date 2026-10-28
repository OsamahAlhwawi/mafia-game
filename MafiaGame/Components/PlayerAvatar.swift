import SwiftUI

/// The player's avatar picture on a parchment circle, or, without one (bots
/// from an older server, previews), their first letter in a color derived from
/// their name.
struct PlayerAvatar: View {
    let name: String
    /// A bundled avatar key: m1…m8 or f1…f8.
    var avatar: String? = nil
    var alive = true
    var size: CGFloat = 56
    var showsCross = true

    private static let colors: [Color] = [
        Color(hex: 0x6B4FB0), Color(hex: 0x25707B), Color(hex: 0xA84A31), Color(hex: 0x33679A),
        Color(hex: 0x963B68), Color(hex: 0x4D7330), Color(hex: 0x86601F), Color(hex: 0x424F92),
    ]

    static let keys: [Gender: [String]] = [
        .male: (1...8).map { "m\($0)" },
        .female: (1...8).map { "f\($0)" },
    ]

    /// Stable across launches (unlike `hashValue`), so a player keeps their color.
    static func color(for name: String) -> Color {
        let hash = name.unicodeScalars.reduce(UInt32(5381)) { ($0 &<< 5) &+ $0 &+ $1.value }
        return colors[Int(hash % UInt32(colors.count))]
    }

    var body: some View {
        face
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if !alive && showsCross {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.5, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .grayscale(alive ? 0 : 1)
            .opacity(alive ? 1 : 0.45)
            .animation(.easeInOut(duration: 1.2), value: alive)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        if let avatar, let image = ArtAssets.image("avatar_\(avatar)") {
            image
                .resizable()
                .scaledToFill()
                .padding(.top, size * 0.06)
                .background(Circle().fill(Color(hex: 0xEBDDBF)))
                .overlay(Circle().strokeBorder(Palette.gold.opacity(0.7), lineWidth: max(1, size * 0.03)))
        } else {
            Text(name.first.map(String.init) ?? "؟")
                .font(.kufi(size * 0.4, weight: 600))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Self.color(for: name)))
        }
    }
}
