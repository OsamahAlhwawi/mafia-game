import SwiftUI

/// A player's place at the table: their card, avatar, name and whatever this
/// phase lets me do to them (kill / protect / inspect / vote).
struct SeatView: View {
    let seat: Seat
    let model: BoardViewModel
    let showInfo: (Seat) -> Void
    var cardWidth: CGFloat = BoardLayout.cardWidth

    var body: some View {
        VStack(spacing: 0) {
            card
            .frame(width: BoardLayout.seatWidth, height: cardWidth * 1.4)
            .overlay(alignment: .topLeading) { badges }
            // Room for the action tab, which sits right on top of the card.
            .padding(.top, ActionChip.height)

            PlayerAvatar(name: seat.name, avatar: seat.avatar, alive: seat.alive, size: 42, showsCross: false)
                .overlay(Circle().stroke(ringColor, lineWidth: seat.selected ? 3 : 0))
                .overlay(alignment: .bottomTrailing) {
                    if !seat.connected && seat.alive {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 10, weight: .bold))
                            .padding(3)
                            .background(Circle().fill(Palette.danger))
                            .foregroundStyle(.white)
                    }
                }
                .offset(y: -15)
                .padding(.bottom, -15)

            Text(seat.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.black.opacity(0.5)))
                .foregroundStyle(.white)
                .padding(.top, 2)
        }
        .frame(width: BoardLayout.seatWidth, height: BoardLayout.seatHeight)
        .contentShape(Rectangle())
        .onTapGesture { showInfo(seat) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("اضغط لتعريف الكرت")
        .accessibilityAddTraits(.isButton)
        // The verb sits on top of the card as its own button.
        .overlay(alignment: .top) {
            if let action = seat.action {
                Button {
                    Haptics.choose()
                    model.tap(seat)
                } label: {
                    ActionChip(action: action, selected: seat.selected, width: cardWidth)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(seat.selected ? "اخترته: \(seat.name)" : "\(action.label) \(seat.name)")
            }
        }
        // After the tab, so the tab never covers the count.
        .overlay { voteBadge }
        .animation(.spring(duration: 0.35), value: seat)
    }

    private var faceRole: RoleInfo? {
        if case let .role(role) = seat.face { role } else { nil }
    }

    @ViewBuilder private var card: some View {
        FlipCard(
            angle: faceRole == nil ? 0 : 180,
            front: Group {
                if let role = faceRole {
                    CardFront(role: role, artwork: ArtAssets.role(role.id), width: cardWidth)
                } else {
                    Color.clear
                }
            },
            back: CardBack(width: cardWidth)
        )
        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: faceRole)
        .frame(width: cardWidth, height: cardWidth * 1.4)
        .overlay {
            if !seat.alive {
                BloodSplatter(seed: seat.id)
                    .transition(.scale(scale: 0.3).combined(with: .opacity).animation(.spring(duration: 0.5).delay(0.45)))
            }
        }
        .brightness(seat.alive ? 0 : -0.12)
        .mayorSeal(seat.voteWeight, cardWidth: cardWidth)
        .shake(seat.shaking)
        .scaleEffect(seat.justOut || seat.accused ? 1.08 : 1)
        .shadow(color: seat.justOut ? Palette.danger.opacity(0.9) : seat.accused ? Palette.gold : .clear, radius: 10)
        .overlay(alignment: .top) {
            if seat.accused {
                Text("متّهم")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Capsule().fill(Palette.gold))
                    .foregroundStyle(Palette.Day.text)
                    .offset(y: -10)
            }
        }
    }

    @ViewBuilder private var badges: some View {
        HStack(spacing: 2) {
            if let mafia = seat.inspectedMafia {
                Image(systemName: mafia ? "theatermasks.fill" : "checkmark.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(mafia ? Palette.danger : Color(hex: 0x2A66AB)))
                    .foregroundStyle(.white)
            }
        }
        .offset(x: (BoardLayout.seatWidth - cardWidth) / 2 - 8, y: ActionChip.height + 4)
    }

    /// Votes on this player, on the card's top-right corner: blood red for the
    /// mafia's picks at night, gold for the day's votes.
    @ViewBuilder private var voteBadge: some View {
        if let count = seat.voteCount {
            // A seat-sized layer laid out left to right, so the count lands on the card's
            // physical top-right corner (the card is centered in the seat, under the tab).
            ZStack(alignment: .topLeading) {
                Color.clear
                VoteBadge(count: count, night: model.phase == .night, out: seat.justOut)
                    // Just under the tab, half over the card's right edge: nothing can cover it.
                    .offset(x: (BoardLayout.seatWidth + cardWidth) / 2 - 12, y: ActionChip.height + 3)
                    .transition(.scale.combined(with: .opacity))
            }
            .environment(\.layoutDirection, .leftToRight)
            .allowsHitTesting(false)
        }
    }

    private var ringColor: Color {
        switch seat.action?.kind {
        case .kill?, .vote?: Palette.danger
        case .protect?: Color(hex: 0x2FA36B)
        case .inspect?: Color(hex: 0x2F74C0)
        case .shoot?: Color(hex: 0x5A6C94)
        default: Palette.gold
        }
    }

    private var accessibilityText: String {
        var parts = [seat.name]
        if !seat.alive { parts.append("خارج اللعبة") }
        if seat.accused { parts.append("متّهم") }
        if case let .role(role) = seat.face { parts.append(role.name) }
        if let count = seat.voteCount { parts.append("\(count) أصوات") }
        if let weight = seat.voteWeight { parts.append("صوته بـ\(weight)") }
        if !seat.picks.isEmpty { parts.append("اختاره: " + seat.picks.joined(separator: "، ")) }
        if let mafia = seat.inspectedMafia { parts.append(mafia ? "تحقيقك: مافيا" : "تحقيقك: مو مافيا") }
        return parts.joined(separator: "، ")
    }
}

/// The number of votes on a card: blood red for the mafia's picks at night (and
/// for whoever the vote just put out), gold for the day's votes.
struct VoteBadge: View {
    let count: Int
    let night: Bool
    var out = false

    var body: some View {
        Text(verbatim: String(count))
            .font(.system(size: 13, weight: .heavy).monospacedDigit())
            .frame(width: 24, height: 24)
            .background(
                Circle().fill(night || out
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xC0141F), Color(hex: 0x5E0008)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Palette.gold))
            )
            .overlay(Circle().stroke(night ? Color(hex: 0xFF5A5F).opacity(0.6) : .clear, lineWidth: 1))
            .foregroundStyle(night || out ? .white : Palette.Day.text)
            .shadow(color: night ? Color(hex: 0xB00010).opacity(0.8) : .black.opacity(0.3), radius: night ? 5 : 2)
    }
}

/// The revealed mayor's gold wax seal: how many votes their vote is worth.
struct MayorSeal: View {
    let weight: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0xF3D58A), Palette.gold, Palette.goldDeep],
                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75
            ))
            Circle()
                .strokeBorder(Palette.Day.text.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .padding(size * 0.11)
            Text(weight.formatted(.number.locale(Locale(identifier: "ar-SA"))))
                .font(.kufi(size * 0.46, weight: 700))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .offset(y: size >= 36 ? -size * 0.1 : 0)
            // The word only where it can still be read (my own, larger card).
            if size >= 36 {
                Text("أصوات")
                    .font(.system(size: size * 0.16, weight: .bold))
                    .offset(y: size * 0.21)
            }
        }
        .foregroundStyle(Palette.Day.text)
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }
}

extension View {
    /// The mayor's seal hanging off the card's physical bottom-left corner, clear of
    /// the role name on top and the vote count on the top-right.
    @ViewBuilder func mayorSeal(_ weight: Int?, cardWidth: CGFloat) -> some View {
        let size = (cardWidth * 0.4).rounded()
        overlay {
            if let weight {
                ZStack(alignment: .bottomLeading) {
                    Color.clear
                    MayorSeal(weight: weight, size: size)
                        .offset(x: -size * 0.25, y: size * 0.25)
                        .transition(.scale.combined(with: .opacity))
                }
                .environment(\.layoutDirection, .leftToRight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

/// The verb on a seat — «اقتل», «احمِ», «حقق», «صوّت» — as a tab sitting exactly on
/// top of the card, the same width, so it never covers the card itself.
struct ActionChip: View {
    static let height: CGFloat = 26

    let action: Seat.Action
    let selected: Bool
    var width: CGFloat = BoardLayout.cardWidth

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7)
    }

    var body: some View {
        Text(action.label)
            .font(.system(size: 14, weight: .heavy))
            .fixedSize()
            .frame(width: width, height: Self.height)
            .background(shape.fill(tint))
            .overlay(shape.inset(by: 1).stroke(.white, lineWidth: selected ? 2 : 0))
            .foregroundStyle(.white)
            .opacity(action.enabled || selected ? 1 : 0.45)
    }

    private var tint: Color {
        switch action.kind {
        case .kill, .vote: Palette.danger
        case .protect: Color(hex: 0x237F52)
        case .inspect: Color(hex: 0x2A66AB)
        case .shoot: Color(hex: 0x34405A)
        case .reveal, .other: Palette.goldDeep
        }
    }
}

/// A nervous tremble every second or so (the accused defending themself).
struct ShakeModifier: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One tremble every `period` seconds, lasting `burst`; on the clock, so every device shakes together.
    static let period: TimeInterval = 1.1
    static let burst: TimeInterval = 0.5

    func body(content: Content) -> some View {
        Group {
            if active && !reduceMotion {
                TimelineView(.animation) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period)
                    let angle = cycle < Self.burst ? sin(cycle * 2 * .pi * 7) * 6 * (1 - cycle / Self.burst) : 0
                    content.rotationEffect(.degrees(angle))
                }
            } else {
                content
            }
        }
        // The phone trembles with the card: a hard knock as each tremble starts, then a softer one.
        // (Haptics aren't motion, so they stay on with Reduce Motion.)
        .task(id: active) {
            guard active else { return }
            while !Task.isCancelled {
                let now = Date().timeIntervalSinceReferenceDate
                try? await Task.sleep(for: .seconds(Self.period - now.truncatingRemainder(dividingBy: Self.period)))
                guard !Task.isCancelled else { return }
                Haptics.tap(.heavy)
                try? await Task.sleep(for: .seconds(0.15))
                guard !Task.isCancelled else { return }
                Haptics.tap(.rigid)
            }
        }
    }
}

extension View {
    func shake(_ active: Bool) -> some View { modifier(ShakeModifier(active: active)) }
}
