import SwiftUI

/// The decision on the accused, as a full card: who's on trial, who has raised
/// a hand for each side so far, a countdown, and the two big buttons.
struct JudgmentModal: View {
    let model: BoardViewModel

    private let ink = Color(hex: 0x3A2A17)
    private let red = Color(hex: 0xE5534B)
    private let blue = Color(hex: 0x3B82E0)

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Emblem()
                    Text("المدينة صوّتت ضد \(model.accusedName)!")
                        .font(.kufi(21, weight: 600))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ink)
                    VStack(spacing: 4) {
                        PlayerAvatar(name: model.accusedName, avatar: model.accusedAvatar, size: 76)
                        Text(model.accusedName).font(.system(size: 18, weight: .bold)).foregroundStyle(ink)
                    }

                    VStack(spacing: 12) {
                        HandsRow(title: "أصوات للإقصاء", count: model.judgmentCounts.eliminate, players: model.judges(.eliminate), tint: Color(hex: 0xC0392B))
                        HandsRow(title: "أصوات للإعفاء", count: model.judgmentCounts.pardon, players: model.judges(.pardon), tint: blue)
                    }
                    .padding(.top, 6)

                    Text(question)
                        .font(.system(size: 17, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ink)
                        .padding(.top, 4)

                    if let endsAt = model.phaseEndsAt {
                        TimelineView(.periodic(from: .now, by: 0.25)) { context in
                            Text("\(max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up))))")
                                .font(.system(size: 38, weight: .heavy).monospacedDigit())
                                .foregroundStyle(ink)
                                .contentTransition(.numericText(countsDown: true))
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(ParchmentFrame())

                if model.canJudge {
                    HStack(spacing: 0) {
                        DecisionButton(title: "إقصاء", color: red, selected: model.myJudgment == .eliminate) { model.judge(.eliminate) }
                        DecisionButton(title: "إعفاء", color: blue, selected: model.myJudgment == .pardon) { model.judge(.pardon) }
                    }
                    .frame(height: 64)
                }
            }
            .padding(.horizontal, 18)
        }
        .environment(\.colorScheme, .light)
    }

    private var question: String {
        if model.isAccused { return "المدينة تقرر مصيرك..." }
        if !model.canJudge { return "أنت تشاهد الحكم" }
        return "هل تقصي \(model.accusedName)؟"
    }
}

/// "2 أصوات للإقصاء" with the avatars of who chose it.
private struct HandsRow: View {
    let title: String
    let count: Int
    let players: [PublicPlayer]
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                Text("\(count)")
                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint))
                    .foregroundStyle(.white)
            }
            HStack(spacing: -8) {
                ForEach(players) { player in
                    PlayerAvatar(name: player.name, avatar: player.avatar, size: 32)
                        .overlay(Circle().stroke(Color(hex: 0xF3E6C8), lineWidth: 2))
                }
            }
            .frame(minHeight: players.isEmpty ? 0 : 32)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(title): \(players.map(\.name).joined(separator: "، "))")
    }
}

/// One half of the bottom bar; the chosen side gets a white frame.
private struct DecisionButton: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.choose()
            action()
        } label: {
            Text(title)
                .font(.kufi(22, weight: 600))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color.opacity(selected ? 1 : 0.85))
                .overlay(Rectangle().stroke(.white, lineWidth: selected ? 4 : 0).padding(2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Ribbon with a scales-of-justice medallion.
private struct Emblem: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hex: 0xE2552C), Color(hex: 0xB93B1E)], startPoint: .top, endPoint: .bottom))
                .frame(width: 190, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0x7A2412), lineWidth: 2))
            Circle()
                .fill(Color(hex: 0x4A3424))
                .frame(width: 84, height: 84)
                .overlay(Circle().stroke(Color(hex: 0xD98A2B), lineWidth: 6))
                .overlay(Image(systemName: "scalemass.fill").font(.system(size: 34)).foregroundStyle(Color(hex: 0xF4E7C9)))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    RootView(store: PreviewData.store(phase: .judgment, role: .citizen))
}
