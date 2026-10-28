import SwiftUI

/// The narrator's line, typed out letter by letter like a storyteller.
struct NarratorCard: View {
    let text: String
    var large = false

    @Environment(\.phaseTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("الراوي", systemImage: "book.closed.fill")
                .font(.kufi(15))
                .foregroundStyle(theme.accentText)
            // The full text sits underneath invisibly so the card doesn't grow while typing.
            Text(text)
                .font(large ? .title3 : .body)
                .lineSpacing(6)
                .hidden()
                .overlay(alignment: .topLeading) {
                    Text(String(text.prefix(shown)))
                        .font(large ? .title3 : .body)
                        .lineSpacing(6)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.text)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.stroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("الراوي: \(text)")
        .task(id: text) {
            guard !reduceMotion else { shown = text.count; return }
            shown = 0
            for i in 1...max(text.count, 1) {
                try? await Task.sleep(for: .milliseconds(28))
                if Task.isCancelled { return }
                shown = i
            }
        }
    }
}
