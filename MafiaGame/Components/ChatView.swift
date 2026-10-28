import SwiftUI

/// Messages for one channel plus an input when the player may write there.
struct ChatView: View {
    let messages: [ChatMessage]
    let myId: String?
    let canWrite: Bool
    var placeholder = "اكتب رسالة..."
    var lockedHint = "تقدر تشوف بس، ما تقدر تكتب"
    let onSend: (String) -> Void

    @Environment(\.phaseTheme) private var theme
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: messages.last?.id) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            if canWrite {
                HStack(spacing: 8) {
                    TextField(placeholder, text: $draft)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.stroke, lineWidth: 1))
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .flipsForRightToLeftLayoutDirection(true)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Palette.gold))
                            .foregroundStyle(Palette.Day.text)
                    }
                    .accessibilityLabel("إرسال")
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Text(lockedHint)
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let mine = message.senderId == myId
        return VStack(alignment: .leading, spacing: 2) {
            if !mine {
                Text(message.senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accentText)
            }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(mine ? Palette.Day.text : theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(mine ? Palette.gold.opacity(0.9) : theme.surface))
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend(text)
        draft = ""
    }
}
