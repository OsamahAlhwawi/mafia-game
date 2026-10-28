import SwiftUI

/// "Game setup": the cards in play on a parchment page. Tap a card for its
/// full explanation; the rules are one tap away.
struct DeckSheet: View {
    let deck: [DeckEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var selected: RoleInfo?
    @State private var showRules = false

    private let ink = Color(hex: 0x3A2A17)
    private let heading = Color(hex: 0xA3261F)

    /// One tile per card (two mafia → two tiles).
    private var cards: [(id: String, role: RoleInfo)] {
        deck.flatMap { entry in (0..<entry.count).map { (id: "\(entry.role.id.rawValue)-\($0)", role: entry.role) } }
    }

    var body: some View {
        ZStack {
            Palette.Night.top.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 16) {
                ScrollView {
                    VStack(spacing: 14) {
                        Emblem()
                        VStack(spacing: 4) {
                            Text("إعدادات اللعبة:").font(.kufi(20, weight: 600)).foregroundStyle(heading)
                            Text("\(cards.count) لاعبين، الأدوار تتوزع عشوائياً")
                                .font(.kufi(19, weight: 600))
                                .foregroundStyle(ink)
                        }
                        Text("البطاقات في اللعب:").font(.kufi(20, weight: 600)).foregroundStyle(heading)
                        // Rows of four, the last row centred (like a dealt hand).
                        VStack(spacing: 20) {
                            ForEach(Array(stride(from: 0, to: cards.count, by: 4)), id: \.self) { start in
                                HStack(spacing: 12) {
                                    ForEach(cards[start..<min(start + 4, cards.count)], id: \.id) { card in
                                        Button { withAnimation(.spring(duration: 0.35)) { selected = card.role } } label: {
                                            DeckTile(role: card.role)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(card.role.name)، اضغط للشرح")
                                    }
                                }
                            }
                        }
                        Text("اضغط على أي بطاقة عشان تعرف وش تسوي")
                            .font(.footnote)
                            .foregroundStyle(ink.opacity(0.7))
                        Text("جديد على المافيا؟").font(.kufi(17, weight: 600)).foregroundStyle(ink).padding(.top, 6)
                        Button { showRules = true } label: {
                            Text("قواعد اللعبة")
                                .font(.kufi(18))
                                .frame(maxWidth: 260, minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x6B6258)))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
                .background(ParchmentFrame())
                .padding(.horizontal, 16)

                Button("حسناً") { dismiss() }
                    .buttonStyle(FilledButtonStyle(font: .kufi(22, weight: 600), height: 60, cornerRadius: 6))
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)

            if let role = selected {
                RoleDetailCard(role: role) { withAnimation(.spring(duration: 0.3)) { selected = nil } }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showRules) { RulesView() }
    }
}

/// A card in the deck with its side marked: 😇 town, 😈 mafia.
private struct DeckTile: View {
    let role: RoleInfo

    var body: some View {
        CardFront(role: role, artwork: ArtAssets.role(role.id), width: 66)
            .frame(width: 66, height: 66 * 1.4)
            .overlay(alignment: .bottomLeading) {
                Text(role.team == .mafia ? "😈" : "😇")
                    .font(.system(size: 24))
                    .offset(x: -8, y: 10)
            }
    }
}

/// The red ribbon with the masks medallion at the top of the page.
private struct Emblem: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hex: 0xE2552C), Color(hex: 0xB93B1E)], startPoint: .top, endPoint: .bottom))
                .frame(width: 210, height: 46)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0x7A2412), lineWidth: 2))
            Circle()
                .fill(Color(hex: 0x4A3424))
                .frame(width: 96, height: 96)
                .overlay(Circle().stroke(Color(hex: 0xD98A2B), lineWidth: 7))
                .overlay(Circle().stroke(Color(hex: 0x7A2412), lineWidth: 2).padding(-4))
                .overlay(
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(hex: 0xF4E7C9))
                )
        }
        .accessibilityHidden(true)
    }
}

/// Parchment page in a dark, worn frame.
struct ParchmentFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: 0xF3E6C8))
            .overlay(KhatamPattern(color: Color(hex: 0xC9A66B), spacing: 36).opacity(0.10).clipShape(RoundedRectangle(cornerRadius: 10)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x4A433C), lineWidth: 10))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0x8C8378), lineWidth: 2).padding(6))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    }
}

/// The big card with its full explanation, over the deck.
private struct RoleDetailCard: View {
    let role: RoleInfo
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 16) {
                CardFront(role: role, artwork: ArtAssets.role(role.id), width: 170)
                    .frame(width: 170, height: 170 * 1.4)
                HStack(spacing: 6) {
                    Text(role.team == .mafia ? "😈" : "😇")
                    Text(role.team == .mafia ? "فريق المافيا" : "فريق المدينة")
                        .font(.kufi(16, weight: 600))
                        .foregroundStyle(role.team == .mafia ? Color(hex: 0xA3261F) : Color(hex: 0x1F4E86))
                }
                Text(role.details)
                    .font(.body)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color(hex: 0x3A2A17))
                    .fixedSize(horizontal: false, vertical: true)
                Button("تمام", action: close)
                    .buttonStyle(FilledButtonStyle(font: .kufi(18), height: 48))
            }
            .padding(22)
            .background(ParchmentFrame())
            .padding(24)
        }
    }
}

#Preview {
    DeckSheet(deck: PreviewData.deck)
}
