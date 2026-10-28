import SwiftUI

/// Start of the game: the big card in the middle of the table, flipped in secret.
struct RoleRevealOverlay: View {
    let role: RoleInfo
    let model: BoardViewModel
    @State private var revealed = false

    var body: some View {
        ZStack {
            Palette.Night.top.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Text("كشف الأدوار").font(.kufi(26, weight: 600))
                    Spacer()
                    if let endsAt = model.phaseEndsAt {
                        TimerRing(endsAt: endsAt, total: model.phaseTotal)
                    }
                }
                if let line = model.log.last?.text {
                    NarratorCard(text: line)
                }
                Spacer(minLength: 0)
                RoleCardView(role: role, isRevealed: $revealed)
                Spacer(minLength: 0)
                Text(revealed ? "اضغط مطوّلاً على الكرت لإخفائه" : "اضغط على الكرت لكشف دورك")
                    .font(.footnote)
                    .foregroundStyle(Palette.Night.muted)
            }
            .padding(20)
            .foregroundStyle(Palette.Night.text)
            .environment(\.phaseTheme, .night)
        }
    }
}
