import SwiftUI

/// Primary call to action: gold, full width.
struct GoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kufi(18))
            .foregroundStyle(Palette.Day.text)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.gold))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Secondary action: outlined in the theme's accent.
struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.phaseTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kufi(17))
            .foregroundStyle(theme.accentText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 16).stroke(theme.accentText, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Rounded surface used for lists and info blocks.
struct PanelModifier: ViewModifier {
    @Environment(\.phaseTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.stroke, lineWidth: 1))
    }
}

extension View {
    func panel() -> some View { modifier(PanelModifier()) }
}

/// A solid button whose whole coloured area is tappable. Frame and fill live
/// inside the style; set outside a `Button`, only the title would respond.
struct FilledButtonStyle: ButtonStyle {
    var color: Color = Color(hex: 0x3B82E0)
    var font: Font = .kufi(20, weight: 600)
    var height: CGFloat = 54
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(color))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outlined button on parchment, tappable across its whole outline.
struct InkOutlineButtonStyle: ButtonStyle {
    var ink = Color(hex: 0x3A2A17)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kufi(15))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).stroke(ink.opacity(0.5), lineWidth: 1.5))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Icon-only button with a full 44×44 touch area.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.title3)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
