import SwiftUI

/// The parchment in the middle of the table: phase banner and countdown on
/// top, then the narrator's numbered log, then whatever buttons this phase needs.
struct NarratorScroll: View {
    let model: BoardViewModel

    private let ink = Color(hex: 0x3A2A17)
    private static let bottomID = "log-bottom"

    var body: some View {
        VStack(spacing: 0) {
            banner
            if let instruction = model.instruction {
                Text(instruction)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.goldDeep)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(numberedLog, id: \.entry.id) { entry, number in
                            Group {
                                if let number {
                                    line(entry, number: number)
                                } else {
                                    DayDivider(text: entry.text, ink: ink)
                                }
                            }
                            .id(entry.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .animation(.easeOut(duration: 0.3), value: model.log.count)
                    // Scrolling here, below the padding, shows the last line in full.
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                // Fade the top edge so older lines slide away instead of being cut.
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06)], startPoint: .top, endPoint: .bottom))
                .onChange(of: model.log.last?.id) { _, _ in
                    withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
                // The parchment shrinks when the instruction or the footer's buttons appear.
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
                .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            footer
        }
        .scrollPaper()
    }

    /// Lines numbered 1, 2, 3…; dividers get no number.
    private var numberedLog: [(entry: LogEntry, number: Int?)] {
        var count = 0
        return model.log.map { entry in
            guard entry.tone != .divider else { return (entry, nil) }
            count += 1
            return (entry, count)
        }
    }

    private func line(_ entry: LogEntry, number: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).").font(.system(size: 17, weight: .medium).monospacedDigit()).foregroundStyle(ink.opacity(0.6))
            if entry.isPrivate {
                Image(systemName: "lock.fill").font(.footnote).foregroundStyle(Color(hex: 0x2A66AB))
            }
            Text(entry.text)
                .font(.system(size: 18, weight: entry.tone == .danger ? .semibold : .medium))
                .foregroundStyle(color(of: entry.tone))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func color(of tone: LogEntry.Tone) -> Color {
        switch tone {
        case .danger: Color(hex: 0xA3141F)
        case .secret: Color(hex: 0x1F4E86)
        case .neutral, .divider: ink
        }
    }

    private var banner: some View {
        VStack(spacing: 4) {
            ScrollTitle(text: model.title)
            if let endsAt = model.phaseEndsAt {
                Countdown(endsAt: endsAt)
            }
        }
        .padding(.top, 10)
    }

    @ViewBuilder private var footer: some View {
        // After a trial only the outcome is told (the narrator's line), not the eliminate/pardon counts.
        if model.canAbstain {
            VStack(spacing: 6) {
                Button {
                    Haptics.choose()
                    model.abstain()
                } label: {
                    HStack(spacing: 8) {
                        Text(model.abstained ? "ممتنع ✓" : "امتناع")
                        Text("\(model.abstainCount)")
                            .font(.system(size: 13, weight: .heavy).monospacedDigit())
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Circle().fill(ink.opacity(0.75)))
                            .foregroundStyle(Color(hex: 0xF4E7C9))
                    }
                }
                .buttonStyle(InkOutlineButtonStyle(ink: ink))
                .accessibilityLabel("امتناع، \(model.abstainCount) امتنعوا")
                if model.notVotedCount > 0 {
                    Text("باقي \(model.notVotedCount) ما صوّتوا")
                        .font(.system(size: 11, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ink.opacity(0.65))
                }
            }
            .padding(10)
        } else if model.watchesVoting {
            Text(model.notVotedCount > 0
                 ? "امتنع \(model.abstainCount) · باقي \(model.notVotedCount) ما صوّتوا"
                 : "امتنع \(model.abstainCount)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .multilineTextAlignment(.center)
                .foregroundStyle(ink.opacity(0.75))
                .padding(10)
        } else if model.phase == .ended {
            // Everyone chooses for themself: back to this room's lobby, or out to the rooms list.
            VStack(spacing: 8) {
                Button("العب مرة ثانية", action: model.playAgain)
                    .buttonStyle(GoldButtonStyle())
                Button("مغادرة", action: model.leave)
                    .buttonStyle(InkOutlineButtonStyle(ink: ink))
            }
            .padding(10)
        }
    }
}

/// The scroll's paper: parchment with a faint khatam pattern and a brown edge,
/// a little dimmer at night. The lobby's room scroll uses it too.
private struct ScrollPaper: ViewModifier {
    @Environment(\.phaseTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: 0xF4E7C9))
                    .overlay(KhatamPattern(color: Color(hex: 0xC9A66B), spacing: 34).opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 14)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xB88A4A), lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            }
            .brightness(theme == .night ? -0.08 : 0)
            .environment(\.colorScheme, .light)
    }
}

/// The phase name in a tan capsule at the top of the scroll.
struct ScrollTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.kufi(15, weight: 600))
            .foregroundStyle(Color(hex: 0x3A2A17))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: 0xE6CF9E)))
            .overlay(Capsule().stroke(Color(hex: 0xB88A4A), lineWidth: 1.5))
    }
}

extension View {
    func scrollPaper() -> some View { modifier(ScrollPaper()) }
}

/// Seconds left in a dark plaque, red in the last ten seconds.
private struct Countdown: View {
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
            Text("\(remaining)")
                .font(.system(size: 19, weight: .heavy).monospacedDigit())
                .foregroundStyle(remaining <= 10 ? Color(hex: 0xFF6B6B) : Palette.gold)
                .frame(minWidth: 48, minHeight: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x3A2A17)))
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: remaining)
                .accessibilityLabel("باقي \(remaining) ثانية")
        }
    }
}

/// «── الليلة ٢ ──» between the story's nights and days.
private struct DayDivider: View {
    let text: String
    let ink: Color

    private var isNight: Bool { text.hasPrefix("الليلة") }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(ink.opacity(0.25)).frame(height: 1)
            Label(text, systemImage: text == "النهاية" ? "flag.checkered" : isNight ? "moon.fill" : "sun.max.fill")
                .labelStyle(.titleAndIcon)
                .font(.kufi(13, weight: 600))
                .foregroundStyle(isNight ? Color(hex: 0x3C4A8A) : Palette.goldDeep)
                .fixedSize()
            Rectangle().fill(ink.opacity(0.25)).frame(height: 1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
