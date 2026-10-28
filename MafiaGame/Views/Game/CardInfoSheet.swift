import SwiftUI

/// A tapped card's explanation, on parchment: the card and its owner on one
/// side, the role and what it does on the other. Face-down cards show as unknown.
struct CardInfoSheet: View {
    let info: CardInfo
    let close: () -> Void

    private let ink = Color(hex: 0x3A2A17)

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(info.role?.name ?? "دور مجهول")
                            .font(.kufi(22, weight: 600))
                            .foregroundStyle(Palette.goldDeep)
                        if let role = info.role {
                            Label(role.team == .mafia ? "فريق المافيا" : "فريق المدينة",
                                  systemImage: role.team == .mafia ? "theatermasks.fill" : "house.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(role.team == .mafia ? Color(hex: 0xA3261F) : Color(hex: 0x1F4E86))
                        }
                        if let note = info.note {
                            Text(note)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(info.alive ? Palette.gold.opacity(0.3) : Palette.danger.opacity(0.18)))
                                .foregroundStyle(info.alive ? ink : Color(hex: 0x8E1B1B))
                        }
                        Text(info.role?.details ?? "دور \(info.playerName) ما زال سرّ. تابِع نقاشه وتصويته، وإذا طلع من اللعبة بينكشف كرته للكل.")
                            .font(.subheadline)
                            .lineSpacing(4)
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: -14) {
                        Group {
                            if let role = info.role {
                                CardFront(role: role, artwork: ArtAssets.role(role.id), width: 110)
                            } else {
                                CardBack(width: 110)
                            }
                        }
                        .frame(width: 110, height: 154)
                        .overlay { if !info.alive { BloodSplatter(seed: info.playerName) } }
                        PlayerAvatar(name: info.playerName, avatar: info.avatar, alive: info.alive, size: 40, showsCross: false)
                    }
                    .overlay(alignment: .bottom) {
                        Text(info.playerName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .offset(y: 24)
                    }
                    .padding(.bottom, 24)
                }
                .padding(20)
                .background(ParchmentFrame())
                .padding(.horizontal, 12)

                Button("حسناً", action: close)
                    .buttonStyle(FilledButtonStyle(font: .kufi(22, weight: 600), height: 58, cornerRadius: 0))
                    .accessibilityIdentifier("cardInfoOK")
            }
        }
        .environment(\.colorScheme, .light)
    }
}

#Preview("مكشوف") {
    CardInfoSheet(info: CardInfo(playerName: "أحمد", role: PreviewData.mafiaRole, note: "هذا كرتك", alive: true)) {}
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("مجهول") {
    CardInfoSheet(info: CardInfo(playerName: "نورة", role: nil, note: nil, alive: true)) {}
        .environment(\.layoutDirection, .rightToLeft)
}
