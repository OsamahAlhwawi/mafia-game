import SwiftUI

/// A face-down role card. Tap flips it (3D) to reveal the role; a long press
/// hides it again. `artwork` (or a `role_<id>` image asset) replaces the SF Symbol.
/// Below 200pt wide it switches to a compact face (symbol + name only).
struct RoleCardView: View {
    let role: RoleInfo
    var artwork: Image? = nil
    @Binding var isRevealed: Bool
    var width: CGFloat = 260

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FlipCard(
            angle: isRevealed ? 180 : 0,
            front: CardFront(role: role, artwork: artwork ?? ArtAssets.role(role.id), width: width),
            back: CardBack(width: width)
        )
        .frame(width: width, height: width * 1.4)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.72), value: isRevealed)
        .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner(width)))
        .onTapGesture { if !isRevealed { isRevealed = true } }
        .onLongPressGesture(minimumDuration: 0.55) { if isRevealed { isRevealed = false } }
        .sensoryFeedback(trigger: isRevealed) { _, revealed in
            revealed ? .impact(weight: .medium) : .impact(weight: .light)
        }
        // Never leave a role showing when the app goes to the background.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { isRevealed = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRevealed ? "\(role.name). \(role.description)" : "كرت مقلوب")
        .accessibilityHint(isRevealed ? "اضغط مطوّلاً لإخفاء الدور" : "اضغط لكشف دورك")
        .accessibilityAddTraits(.isButton)
    }
}

enum CardMetrics {
    static func corner(_ width: CGFloat) -> CGFloat { max(8, width * 0.077) }
    static func isCompact(_ width: CGFloat) -> Bool { width < 200 }
}

/// Swaps faces exactly when the card is edge-on (90°), frame by frame.
struct FlipCard<Front: View, Back: View>: View, @preconcurrency Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            back.opacity(angle < 90 ? 1 : 0)
            front
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle < 90 ? 0 : 1)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

/// The same back for every role, so nothing leaks to someone glancing over.
struct CardBack: View {
    let width: CGFloat

    var body: some View {
        let corner = CardMetrics.corner(width)
        let inset = width * 0.046
        RoundedRectangle(cornerRadius: corner)
            .fill(Palette.Night.cardBack)
            .overlay {
                if let art = ArtAssets.cardBack {
                    art.resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: corner))
                } else {
                    drawnBack(corner: corner, inset: inset)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: width * 0.07, y: width * 0.05)
    }

    @ViewBuilder private func drawnBack(corner: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            KhatamPattern(color: Palette.gold, spacing: max(14, width * 0.123))
                .opacity(0.18)
            RadialGradient(
                colors: [Palette.Night.cardBack, Palette.Night.cardBack, Palette.Night.cardBack.opacity(0)],
                center: .init(x: 0.5, y: 0.45), startRadius: 0, endRadius: width * 0.58
            )
            VStack(spacing: width * 0.085) {
                ZStack {
                    KhatamStar()
                        .stroke(Palette.gold, lineWidth: max(1, width * 0.006))
                        .frame(width: width * 0.4, height: width * 0.4)
                    if CardMetrics.isCompact(width) {
                        Text("؟").font(.kufi(width * 0.2, weight: 700)).foregroundStyle(Palette.gold)
                    } else {
                        Circle()
                            .stroke(Palette.gold.opacity(0.6), lineWidth: 0.8)
                            .frame(width: width * 0.22, height: width * 0.22)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: width * 0.115))
                            .foregroundStyle(Palette.gold)
                    }
                }
                if !CardMetrics.isCompact(width) {
                    Text("اضغط لكشف دورك")
                        .font(.kufi(18))
                        .foregroundStyle(Palette.gold)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: max(4, corner - inset / 2)).stroke(Palette.gold, lineWidth: max(1, width * 0.006)).padding(inset))
    }
}

struct CardFront: View {
    let role: RoleInfo
    var artwork: Image? = nil
    let width: CGFloat

    var body: some View {
        let style = RoleStyle.of(role.id)
        let corner = CardMetrics.corner(width)
        RoundedRectangle(cornerRadius: corner)
            .fill(LinearGradient(colors: style.gradient, startPoint: .topTrailing, endPoint: .bottomLeading))
            .overlay {
                if let artwork {
                    artwork.resizable().scaledToFill()
                        .overlay(alignment: .top) {
                            LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: width * 0.5)
                        }
                        .overlay(alignment: .bottom) {
                            if !CardMetrics.isCompact(width) {
                                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    .frame(height: width * 0.75)
                            }
                        }
                } else {
                    KhatamPattern(color: Palette.gold, spacing: max(14, width * 0.123)).opacity(0.10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay {
                if CardMetrics.isCompact(width) { compact(style) } else { full(style) }
            }
            .shadow(color: .black.opacity(0.45), radius: width * 0.07, y: width * 0.05)
    }

    /// The role's own ink on its drawn card; white over artwork, where the text sits on a dark band.
    private func textColor(_ style: RoleStyle) -> Color {
        artwork == nil ? style.foreground : .white
    }

    private func compact(_ style: RoleStyle) -> some View {
        VStack(spacing: width * 0.06) {
            Text(role.name)
                .font(.kufi(max(9, width * 0.17), weight: 600))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if artwork == nil {
                Image(systemName: style.symbol).font(.system(size: width * 0.34))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(textColor(style))
        .shadow(color: artwork == nil ? .clear : .black.opacity(0.8), radius: 2, y: 1)
        .padding(.vertical, width * 0.1)
        .padding(.horizontal, width * 0.06)
    }

    private func full(_ style: RoleStyle) -> some View {
        VStack(spacing: 0) {
            Text(role.team == .mafia ? "فريق المافيا" : "فريق المدينة")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(style.foreground.opacity(0.4), lineWidth: 1))
            Spacer(minLength: 8)
            if artwork == nil {
                Image(systemName: style.symbol)
                    .font(.system(size: 54, weight: .regular))
                    .frame(width: 112, height: 112)
                    .background(Circle().fill(style.foreground.opacity(0.10)))
            }
            Spacer(minLength: 8)
            Text(role.name)
                .font(.kufi(34, weight: 600))
            Text(role.description)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(artwork == nil ? style.muted : .white.opacity(0.85))
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(textColor(style))
        .shadow(color: artwork == nil ? .clear : .black.opacity(0.8), radius: 2, y: 1)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(style.foreground.opacity(0.4), lineWidth: 1))
        .padding(12)
    }
}

#Preview {
    @Previewable @State var revealed = false
    @Previewable @State var small = false
    ZStack {
        Palette.Night.top.ignoresSafeArea()
        VStack(spacing: 30) {
            RoleCardView(role: PreviewData.mafiaRole, isRevealed: $revealed)
            HStack {
                RoleCardView(role: PreviewData.doctorRole, isRevealed: $small, width: 90)
                CardBack(width: 56).frame(width: 56, height: 78)
                CardFront(role: PreviewData.detectiveRole, width: 56).frame(width: 56, height: 78)
            }
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
