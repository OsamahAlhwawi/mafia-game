import SwiftUI

/// The table: players sit in two columns around the narrator's scroll, my card
/// sits at the bottom, and the chat bar is underneath. Every in-game phase uses
/// this one screen; only what's on the seats and the scroll changes.
struct GameBoardView: View {
    @State private var model: BoardViewModel
    /// The last tapped card; kept after closing so the sheet stays in the tree.
    @State private var infoSeat: Seat?
    @State private var infoVisible = false
    @State private var chatOpen = false
    /// Messages already seen when the chat was last open (for the unread badge).
    @State private var seenChat = 0

    init(store: GameStore) {
        _model = State(initialValue: BoardViewModel(store: store))
        // What was said in the lobby carries over, already read there.
        _seenChat = State(initialValue: store.chat.count)
    }

    private func show(_ seat: Seat) {
        infoSeat = seat
        infoVisible = true
    }

    var body: some View {
        table
            // The keyboard (chat) slides over the table instead of squeezing it, so the cards keep their size.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay { modals }
            // The chat sits above the phase layers so the accused can plead and everyone can
            // argue during the judgment too; the role reveal and the morning still cover it.
            // New messages float up from the bottom-left corner and fade away.
            .overlay(alignment: .bottomTrailing) {
                ChatFeed(model: model)
                    .opacity(chatOpen || coveredByAnnouncement ? 0 : 1)
                    .padding(.bottom, 10)
                    .padding(.trailing, 10)
            }
            // The judgment card covers the table's chat button: the same button, in the same corner, on top.
            .overlay(alignment: .bottomLeading) {
                if model.phase == .judgment && !chatOpen {
                    ChatButton(unread: unreadChat, action: openChat)
                        .frame(height: 58)
                        .padding(.leading, 8)
                }
            }
            // Its own layer, outside `modals`, so the hidden phase layers never stretch it.
            .overlay {
                if chatOpen {
                    ChatOverlay(model: model, close: closeChat)
                }
            }
            .onChange(of: model.chat.count) { _, count in if chatOpen { seenChat = count } }
            // Restarts whenever the phase or its end moves (voting closes early once everyone has voted).
            .task(id: "\(model.phase)-\(model.phaseEndsAt?.timeIntervalSince1970 ?? 0)") { await tickLastSeconds() }
    }

    /// The last five seconds of every night and day (discussion, voting) tick in the hand, the last one hardest.
    private func tickLastSeconds() async {
        guard [.night, .discussion, .voting].contains(model.phase), let end = model.phaseEndsAt else { return }
        for second in stride(from: 5, through: 1, by: -1) {
            let wait = end.addingTimeInterval(-Double(second)).timeIntervalSinceNow
            if wait < -0.3 { continue }
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            Haptics.tap(second == 1 ? .heavy : .medium)
        }
    }

    private var table: some View {
        GeometryReader { geo in
            let columns = BoardLayout.columns(model.otherSeats)
            let perColumn = max(columns.right.count, columns.left.count)
            let middleHeight = max(300, geo.size.height - 40 - 58 - 12)
            let scale = BoardLayout.scale(perColumn: perColumn, height: middleHeight)

            VStack(spacing: 6) {
                HStack {
                    GameMenuButton(deck: model.deck, confirmLeave: model.amAlive && model.phase != .ended, leave: model.leave)
                    Spacer()
                }
                .frame(height: 40)

                // Seats on both sides; the narrator's scroll with my card under it in the middle.
                HStack(alignment: .center, spacing: 4) {
                    SeatColumn(items: columns.right, scale: scale) { SeatView(seat: $0, model: model, showInfo: show) }
                    VStack(spacing: 6) {
                        NarratorScroll(model: model)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        MyDock(model: model, showInfo: show)
                    }
                    SeatColumn(items: columns.left, scale: scale) { SeatView(seat: $0, model: model, showInfo: show) }
                }
                .frame(height: middleHeight)

                // Chat icon bottom right; incoming messages float in on the left.
                HStack {
                    ChatButton(unread: unreadChat, action: openChat)
                    Spacer()
                }
                .frame(height: 58)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    /// Every full-screen layer, bottom to top. The phase layers hold live
    /// countdowns, so they stay in the tree and are only faded and disabled
    /// (`modalLayer`): removing one with a transition left an invisible layer
    /// swallowing every tap. The card info has no timers and is simply added
    /// and removed, without a removal transition.
    @ViewBuilder private var modals: some View {
        ZStack {
            if infoVisible, let seat = infoSeat {
                CardInfoSheet(info: model.cardInfo(for: seat)) { infoVisible = false }
            }
            JudgmentModal(model: model)
                .modalLayer(visible: model.phase == .judgment)
            MorningAnnouncement(model: model, visible: model.phase == .morning)
                .modalLayer(visible: model.phase == .morning)
            if let role = model.myRole {
                RoleRevealOverlay(role: role, model: model)
                    .modalLayer(visible: model.phase == .roleReveal)
            }
        }
    }

    /// The role reveal and the morning announcement fill the screen; the chat stays out of their way.
    private var coveredByAnnouncement: Bool { model.phase == .roleReveal || model.phase == .morning }

    private var unreadChat: Int { chatOpen ? 0 : max(0, model.chat.count - seenChat) }

    private func openChat() {
        chatOpen = true
    }

    private func closeChat() {
        seenChat = model.chat.count
        chatOpen = false
    }
}

private extension View {
    /// A full-screen layer that stays in the view tree: visible and interactive, or faded and inert.
    func modalLayer(visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            // Collapse the children too, so hidden buttons and fields leave the accessibility tree.
            .accessibilityElement(children: visible ? .contain : .ignore)
            .accessibilityHidden(!visible)
            .animation(.easeInOut(duration: 0.3), value: visible)
    }
}

/// One side of the table: seats spread evenly down the column, shrunk to fit. The lobby lays its chairs out the same way.
struct SeatColumn<Item: Identifiable, SeatContent: View>: View {
    let items: [Item]
    let scale: CGFloat
    @ViewBuilder let seat: (Item) -> SeatContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                Spacer(minLength: 0)
                seat(item)
                    .scaleEffect(scale)
                    .frame(width: BoardLayout.seatWidth * scale, height: BoardLayout.seatHeight * scale)
                    .zIndex(1)
            }
            Spacer(minLength: 0)
        }
        .frame(width: BoardLayout.seatWidth)
    }
}

#Preview("الليل") {
    RootView(store: PreviewData.store(phase: .night, role: .mafia))
}

#Preview("التصويت") {
    RootView(store: PreviewData.store(phase: .voting))
}

#Preview("النهاية") {
    RootView(store: PreviewData.store(phase: .ended))
}
