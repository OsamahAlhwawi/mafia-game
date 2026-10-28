import SwiftUI

/// Countdown ring for the current phase. Turns red in the last 10 seconds.
struct TimerRing: View {
    let endsAt: Date?
    let total: TimeInterval
    var size: CGFloat = 52

    @Environment(\.phaseTheme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = max(0, endsAt?.timeIntervalSince(context.date) ?? 0)
            let fraction = total > 0 ? remaining / total : 0
            let urgent = remaining <= 10 && endsAt != nil
            ZStack {
                Circle().stroke(theme.text.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(urgent ? Palette.danger : Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: fraction)
                Text(Self.format(remaining))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("الوقت المتبقي \(Int(remaining.rounded(.up))) ثانية")
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
