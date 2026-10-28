import SwiftUI

/// The room before a game, laid out as the table it will be played on: a face-down
/// card on every chair, the room's scroll in the middle (name, code, cards in play),
/// my chair under it with the leader's start button, and the chat. The ⋯ opens the
/// room's settings.
struct LobbyView: View {
    @State private var model: LobbyViewModel
    /// The table's model, for the chat: it works here exactly as in the game.
    @State private var table: BoardViewModel
    // `-devOpenSettings YES` opens the settings on launch (screenshots during development).
    @State private var showSettings = UserDefaults.standard.string(forKey: "devOpenSettings") == "YES"
    @State private var showDeck = false
    @State private var showDevMenu = false
    @State private var managing: PublicPlayer?
    @State private var renaming = false
    @State private var draftName = ""
    @State private var chatOpen = false
    @State private var seenChat = 0

    init(store: GameStore) {
        _model = State(initialValue: LobbyViewModel(store: store))
        _table = State(initialValue: BoardViewModel(store: store))
    }

    var body: some View {
        tableView
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(alignment: .bottomTrailing) {
                ChatFeed(model: table)
                    .opacity(chatOpen ? 0 : 1)
                    .padding(.bottom, 10)
                    .padding(.trailing, 10)
            }
            .overlay {
                if chatOpen {
                    ChatOverlay(model: table) {
                        seenChat = table.chat.count
                        chatOpen = false
                    }
                }
            }
            .overlay {
                if showSettings {
                    // The page animates itself in and out; it's simply added and removed.
                    RoomSettingsModal(
                        model: model,
                        close: { showSettings = false },
                        openDeck: { showDeck = true },
                        openDevTools: { showDevMenu = true }
                    )
                }
            }
            .onChange(of: table.chat.count) { _, count in if chatOpen { seenChat = count } }
            .fullScreenCover(isPresented: $showDeck) {
                DeckSheet(deck: model.deck)
            }
            .sheet(isPresented: $showDevMenu) {
                DevMenuView(model: model)
                    .presentationDetents([.medium])
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .confirmationDialog(managing?.name ?? "", isPresented: Binding(get: { managing != nil }, set: { if !$0 { managing = nil } }), titleVisibility: .visible, presenting: managing) { player in
                if !player.isBot {
                    Button("سلّمه قيادة الغرفة") { model.makeHost(player) }
                }
                Button(player.isBot ? "شيل البوت" : "اطرده (ما يرجع قبل ساعة)", role: .destructive) { model.kick(player) }
                Button("إلغاء", role: .cancel) {}
            }
            .alert("اسم الغرفة", isPresented: $renaming) {
                TextField("غرفة \(model.me?.name ?? "")", text: $draftName)
                Button("حفظ") { model.rename(draftName) }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("اتركه فاضي ويرجع للاسم الافتراضي.")
            }
    }

    /// The same geometry as the game's table, so nobody moves when the game starts.
    private var tableView: some View {
        GeometryReader { geo in
            let columns = BoardLayout.columns(model.otherSeats)
            let perColumn = max(columns.right.count, columns.left.count)
            let middleHeight = max(300, geo.size.height - 40 - 58 - 12)
            let scale = BoardLayout.scale(perColumn: perColumn, height: middleHeight)

            VStack(spacing: 6) {
                HStack {
                    Button { showSettings = true } label: {
                        MenuDots()
                    }
                    .accessibilityLabel("إعدادات الغرفة")
                    Spacer()
                }
                .frame(height: 40)

                HStack(alignment: .center, spacing: 4) {
                    SeatColumn(items: columns.right, scale: scale, seat: chair)
                    VStack(spacing: 6) {
                        LobbyScroll(model: model, rename: startRenaming) { showSettings = true }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        myChair
                    }
                    SeatColumn(items: columns.left, scale: scale, seat: chair)
                }
                .frame(height: middleHeight)

                HStack {
                    ChatButton(unread: unreadChat) { chatOpen = true }
                    Spacer()
                }
                .frame(height: 58)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    private func startRenaming() {
        draftName = model.name
        renaming = true
    }

    private var unreadChat: Int { chatOpen ? 0 : max(0, table.chat.count - seenChat) }

    @ViewBuilder private func chair(_ seat: LobbySeat) -> some View {
        switch seat {
        case let .player(player):
            Button { if model.canManage(player) { managing = player } } label: {
                LobbyChair(player: player)
            }
            .buttonStyle(.plain)
            // Not `.disabled`: that would grey the cards out for everyone but the leader.
            .allowsHitTesting(model.canManage(player))
            .accessibilityHint(model.canManage(player) ? "اضغط لخيارات القائد" : "")
        case .empty:
            Button(action: model.addBot) {
                EmptyChair()
            }
            .buttonStyle(.plain)
            .disabled(!model.canAddBot)
            .accessibilityLabel("مقعد فاضي، أضف بوت")
        }
    }

    /// My face-down card under the scroll, a little larger, and the leader's start button under it.
    @ViewBuilder private var myChair: some View {
        if let me = model.me {
            VStack(spacing: 6) {
                LobbyChair(player: me, cardWidth: MyDock.cardWidth)
                    .frame(height: MyDock.height)
                if model.isHost {
                    Button("ابدأ اللعبة", action: model.start)
                        .buttonStyle(GoldButtonStyle())
                        .disabled(!model.canStart)
                }
            }
        }
    }
}

/// A seated player: a face-down card with their avatar on it and their name, the
/// leader's crown above it. Sized like the game's seats so the table doesn't shift.
private struct LobbyChair: View {
    let player: PublicPlayer
    var cardWidth: CGFloat = BoardLayout.cardWidth

    private var avatarSize: CGFloat { cardWidth > BoardLayout.cardWidth ? 40 : 42 }

    var body: some View {
        VStack(spacing: 0) {
            // The crown sits where the game puts the action tab.
            Group {
                if player.isHost {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.gold)
                        .shadow(color: .black.opacity(0.7), radius: 2)
                } else {
                    Color.clear
                }
            }
            .frame(height: ActionChip.height)

            CardBack(width: cardWidth)
                .frame(width: cardWidth, height: cardWidth * 1.4)
                .overlay {
                    if player.pending {
                        Text("على النتيجة")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.7)))
                            .foregroundStyle(.white)
                    }
                }

            PlayerAvatar(name: player.name, avatar: player.avatar, size: avatarSize, showsCross: false)
                .overlay(alignment: .bottomTrailing) {
                    if player.isBot {
                        Image(systemName: "cpu").font(.system(size: 10, weight: .bold))
                            .padding(3).background(Circle().fill(Palette.Night.surface)).foregroundStyle(Palette.Night.muted)
                    } else if !player.connected {
                        Image(systemName: "wifi.slash").font(.system(size: 10, weight: .bold))
                            .padding(3).background(Circle().fill(Palette.danger)).foregroundStyle(.white)
                    }
                }
                .offset(y: -15)
                .padding(.bottom, -15)

            Text(player.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.black.opacity(0.5)))
                .foregroundStyle(.white)
                .padding(.top, 2)
        }
        .frame(width: max(BoardLayout.seatWidth, cardWidth), height: cardWidth == BoardLayout.cardWidth ? BoardLayout.seatHeight : nil)
        .opacity(player.pending || !player.connected ? 0.55 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        var parts = [player.name]
        if player.isHost { parts.append("قائد الغرفة") }
        if player.isBot { parts.append("بوت") }
        if player.pending { parts.append("لسه على شاشة النتيجة") }
        if !player.connected { parts.append("غير متصل") }
        return parts.joined(separator: "، ")
    }
}

/// A free chair: the outline of a card, waiting. Tapping it seats a bot.
private struct EmptyChair: View {
    private let width = BoardLayout.cardWidth

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: ActionChip.height)
            RoundedRectangle(cornerRadius: CardMetrics.corner(width))
                .fill(.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: CardMetrics.corner(width))
                    .strokeBorder(Palette.gold.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .frame(width: width, height: width * 1.4)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 24))
                        Text("أضف بوت")
                            .font(.kufi(13, weight: 600))
                    }
                    .foregroundStyle(Palette.gold.opacity(0.85))
                }
            Text("كرسي فاضي")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.black.opacity(0.35)))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 8)
        }
        .frame(width: BoardLayout.seatWidth, height: BoardLayout.seatHeight, alignment: .top)
        .contentShape(Rectangle())
    }
}

#Preview("القائد") {
    RootView(store: PreviewData.store(phase: .lobby))
}
