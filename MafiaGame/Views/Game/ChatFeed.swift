import SwiftUI

/// The newest chat messages stacked at the bottom-left of the table, each with
/// the sender's avatar and name. A message fades out after a few seconds, or
/// sooner when newer ones push it off the top.
struct ChatFeed: View {
    let model: BoardViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let messages = model.recentMessages(now: context.date)
            // In RTL, `.trailing` is the left edge, where the feed sits.
            VStack(alignment: .trailing, spacing: 6) {
                ForEach(messages) { message in
                    FeedRow(message: message, isMine: message.senderId == model.myId, avatarKey: model.avatar(of: message.senderId))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: 210, alignment: .trailing)
            .animation(.spring(duration: 0.35), value: messages.map(\.id))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One chat message: name above a bubble, the sender's avatar on the outer edge.
struct FeedRow: View {
    enum Side { case left, right }

    let message: ChatMessage
    let isMine: Bool
    var side: Side = .left
    var avatarKey: String?

    private var tint: Color {
        switch message.channel {
        case .mafia: Color(hex: 0x7A0F18)
        case .dead: Color(hex: 0x3B3F55)
        case .day: isMine ? Color(hex: 0x6B4A12) : Color(hex: 0x1E1E26)
        }
    }

    var body: some View {
        // In RTL, `.leading` is the right edge; the avatar always sits on the outer edge.
        HStack(alignment: .bottom, spacing: 5) {
            if side == .right { avatar }
            VStack(alignment: side == .right ? .leading : .trailing, spacing: 2) {
                nameTag
                bubble
            }
            if side == .left { avatar }
        }
    }

    private var avatar: some View {
        PlayerAvatar(name: message.senderName, avatar: avatarKey, size: 28)
    }

    private var nameTag: some View {
        HStack(spacing: 3) {
            if message.channel == .mafia {
                Image(systemName: "theatermasks.fill").font(.system(size: 9))
            } else if message.channel == .dead {
                Image(systemName: "eye.fill").font(.system(size: 9))
            }
            Text(isMine ? "أنت" : message.senderName)
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 1)
        .background(Capsule().fill(.black.opacity(0.55)))
        .foregroundStyle(Palette.gold)
    }

    private var bubble: some View {
        Text(Self.bidi(message.text))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .lineLimit(side == .left ? 2 : nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 15).fill(tint.opacity(0.9)))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }

    /// A message with any Arabic in it reads right-to-left as a whole, so an
    /// English word typed first ("btw اسامه القاتل") stays first instead of
    /// flipping to the end. The paragraph otherwise takes its direction from
    /// the first letter.
    static func bidi(_ text: String) -> String {
        let arabic = text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value) || (0xFB50...0xFEFF).contains($0.value) }
        return arabic ? "\u{200F}" + text : text
    }
}
