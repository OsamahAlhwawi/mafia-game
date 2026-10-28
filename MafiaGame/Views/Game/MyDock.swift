import SwiftUI

/// My seat, under the narrator's scroll: my card (always face up, tap for its
/// explanation) with my avatar under it, like everyone else's, a little larger.
struct MyDock: View {
    let model: BoardViewModel
    let showInfo: (Seat) -> Void
    @State private var confirmingReveal = false

    static let cardWidth: CGFloat = 96
    /// Tab + card + overlapping avatar + name.
    static let height: CGFloat = ActionChip.height + cardWidth * 1.4 + 46

    var body: some View {
        if let seat = model.mySeat, let role = model.myRole {
            VStack(spacing: 0) {
                // The doctor can protect themself: the tab sits on top of my own card.
                Group {
                    if let action = seat.action {
                        Button {
                            Haptics.choose()
                            model.tap(seat)
                        } label: {
                            ActionChip(action: action, selected: seat.selected, width: Self.cardWidth)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(seat.selected ? "اخترته: \(seat.name)" : "\(action.label) \(seat.name)")
                    } else if model.canRevealRole {
                        // The mayor: show my card to everyone, once, by day.
                        Button {
                            Haptics.choose()
                            confirmingReveal = true
                        } label: {
                            ActionChip(action: Seat.Action(kind: .reveal, enabled: true), selected: false, width: Self.cardWidth)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("اكشف كرتك للكل")
                    } else {
                        Color.clear
                    }
                }
                .frame(height: ActionChip.height)
                .confirmationDialog("تكشف إنك \(role.name)؟", isPresented: $confirmingReveal, titleVisibility: .visible) {
                    Button("اكشف كرتي") { model.revealRole() }
                    Button("لا، خلّه سر", role: .cancel) {}
                } message: {
                    Text("الكل بيشوف كرتك وصوتك يصير بثلاثة، بس بتصير هدف واضح للمافيا. ما تقدر ترجع فيها.")
                }

                Button { showInfo(seat) } label: {
                    CardFront(role: role, artwork: ArtAssets.role(role.id), width: Self.cardWidth)
                        .frame(width: Self.cardWidth, height: Self.cardWidth * 1.4)
                        .overlay { if !seat.alive { BloodSplatter(seed: seat.id) } }
                        .mayorSeal(seat.voteWeight, cardWidth: Self.cardWidth)
                        .brightness(seat.alive ? 0 : -0.12)
                }
                // Votes on me, on the card's top-right corner like everyone else's.
                .overlay {
                    if let count = seat.voteCount {
                        ZStack(alignment: .topLeading) {
                            Color.clear
                            VoteBadge(count: count, night: model.phase == .night, out: seat.justOut)
                                .offset(x: Self.cardWidth - 12, y: 3)
                                .transition(.scale.combined(with: .opacity))
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .allowsHitTesting(false)
                    }
                }
                .animation(.spring(duration: 0.35), value: seat.voteCount)
                .buttonStyle(.plain)
                .shake(seat.shaking)
                .accessibilityLabel("كرتك: \(role.name)")
                .accessibilityHint("اضغط للتفاصيل")

                PlayerAvatar(name: seat.name, avatar: seat.avatar, alive: seat.alive, size: 40, showsCross: false)
                    .offset(y: -14)
                    .padding(.bottom, -14)
                    .allowsHitTesting(false)
                Text(seat.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
            }
            .frame(height: Self.height)
        }
    }
}
