import SwiftUI

/// The chat icon (bottom right) with the number of messages since it was last opened.
struct ChatButton: View {
    let unread: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "text.bubble.fill")
                .font(.title2)
                .foregroundStyle(Palette.gold)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Palette.Night.surface.opacity(0.95)))
                .overlay(Circle().stroke(Palette.gold.opacity(0.6), lineWidth: 1.5))
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(Palette.danger))
                            .foregroundStyle(.white)
                    }
                }
        }
        .accessibilityLabel(unread > 0 ? "الشات، \(unread) رسائل جديدة" : "الشات")
    }
}

/// The open chat: the table dims, the whole conversation floats over it on the
/// left like the live feed, and the input sits on top of the keyboard.
/// Tap anywhere empty to close.
struct ChatOverlay: View {
    let model: BoardViewModel
    let close: () -> Void

    @State private var draft = ""
    @State private var channel: ChatChannel?
    @FocusState private var focused: Bool

    private var current: ChatChannel? {
        channel.flatMap { model.writableChannels.contains($0) ? $0 : nil } ?? model.chatChannel
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { focused = false; close() }

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Spacer(minLength: 0)
                            if model.chat.isEmpty {
                                Text("ما فيه رسائل للحين. ابدأ الكلام!")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 120)
                            }
                            ForEach(model.chat) { message in
                                FeedRow(message: message, isMine: message.senderId == model.myId, side: .right, avatarKey: model.avatar(of: message.senderId))
                                    .frame(maxWidth: 280, alignment: .leading)
                                    .id(message.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: model.chat.last?.id) { _, id in
                        guard let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { focused = false; close() }

                inputBar
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { focused = model.chatChannel != nil }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if model.writableChannels.count > 1 {
                HStack(spacing: 8) {
                    ForEach(model.writableChannels, id: \.self) { option in
                        Button { channel = option } label: {
                            Text(Self.name(of: option))
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(Capsule().fill(current == option ? (option == .mafia ? Palette.danger : Palette.gold) : .white.opacity(0.12)))
                                .foregroundStyle(current == option && option != .mafia ? Palette.Day.text : .white)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            HStack(spacing: 10) {
                Button { focused = false; close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white.opacity(0.8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("سكّر الشات")

                TextField("", text: $draft, prompt: Text(current.map(Self.placeholder) ?? "تقدر تقرا بس الحين").foregroundStyle(.white.opacity(0.55)))
                    .focused($focused)
                    .accessibilityIdentifier("chatInput")
                    .disabled(current == nil)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(current == .mafia ? Palette.danger : .white.opacity(0.15), lineWidth: 1))

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .flipsForRightToLeftLayoutDirection(true)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.gold))
                        .foregroundStyle(Palette.Day.text)
                }
                .buttonStyle(.plain)
                .disabled(current == nil || draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("إرسال")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: 0x0B0E1C).opacity(0.97).ignoresSafeArea(edges: .bottom))
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.send(text, channel: current)
        draft = ""
    }

    static func name(of channel: ChatChannel) -> String {
        switch channel {
        case .mafia: "فريق المافيا 🎭"
        case .dead: "المشاهدين"
        case .day: "الكل"
        }
    }

    static func placeholder(_ channel: ChatChannel) -> String {
        switch channel {
        case .mafia: "اكتب لفريقك بالسر..."
        case .dead: "دردش مع اللي طلعوا..."
        case .day: "قل اللي في بالك..."
        }
    }
}
