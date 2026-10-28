import SwiftUI

/// The parchment in the middle of the lobby's table, where the narrator's scroll
/// will be: the room's name, a bot for an empty seat, how many have sat down, the
/// cards in play (tap for the settings), and what we're waiting for.
struct LobbyScroll: View {
    let model: LobbyViewModel
    let rename: () -> Void
    let showSettings: () -> Void

    private let ink = Color(hex: 0x3A2A17)

    var body: some View {
        // Short phones: the same page, scrolling.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollPaper()
    }

    private var content: some View {
        VStack(spacing: 12) {
            ScrollTitle(text: "غرفة الانتظار")

            HStack(spacing: 4) {
                if model.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(ink.opacity(0.6))
                        .accessibilityLabel("غرفة خاصة")
                }
                Text(model.name)
                    .font(.kufi(19, weight: 600))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                if model.isHost {
                    Button("غيّر اسم الغرفة", systemImage: "pencil", action: rename)
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.goldDeep)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
            }

            if model.canAddBot {
                Button("أضف بوت", systemImage: "cpu", action: model.addBot)
                    .buttonStyle(InkOutlineButtonStyle(ink: ink))
            }

            Text("\(model.players.count)/\(model.capacity) لاعبين")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(ink.opacity(0.75))

            Ornament(color: ink.opacity(0.35))

            Button(action: showSettings) {
                VStack(spacing: 8) {
                    Text("البطاقات في اللعب")
                        .font(.kufi(13, weight: 600))
                        .foregroundStyle(ink.opacity(0.75))
                    DeckTokens(deck: model.deck)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("البطاقات في اللعب: \(model.deckSummary)")
            .accessibilityHint("اضغط لإعدادات الغرفة")

            Text(model.statusText)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.goldDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

/// The deck as small round tokens in the role's colours, with the count (×2) when there's more than one.
struct DeckTokens: View {
    let deck: [DeckEntry]
    var size: CGFloat = 30

    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(deck, id: \.role.id) { entry in
                let style = RoleStyle.of(entry.role.id)
                Image(systemName: style.symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .frame(width: size, height: size)
                    .background(Circle().fill(LinearGradient(colors: style.gradient, startPoint: .topTrailing, endPoint: .bottomLeading)))
                    .overlay(Circle().stroke(Color(hex: 0xB88A4A), lineWidth: 1))
                    .foregroundStyle(style.foreground)
                    .overlay(alignment: .bottomLeading) {
                        if entry.count > 1 {
                            Text("×\(entry.count)")
                                .font(.system(size: 10, weight: .heavy).monospacedDigit())
                                .padding(.horizontal, 3)
                                .background(Capsule().fill(Color(hex: 0x3A2A17)))
                                .foregroundStyle(Color(hex: 0xF4E7C9))
                                .offset(x: -6, y: 4)
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}

/// «──── ◆ ────»: a divider on parchment.
struct Ornament: View {
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(height: 1)
            Image(systemName: "suit.diamond.fill").font(.system(size: 8))
            Rectangle().fill(color).frame(height: 1)
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}

/// Lays its children out in centred rows, wrapping to the next row when one is full.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.midX - row.width / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if var last = rows.last, last.width + spacing + size.width <= width {
                last.indices.append(index)
                last.width += spacing + size.width
                last.height = max(last.height, size.height)
                rows[rows.count - 1] = last
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}
