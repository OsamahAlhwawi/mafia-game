import SwiftUI

/// "الليلة 1 انتهت..." — what the night brought, on parchment for a few seconds:
/// the victim's card flips over (stained), or stays face down if nobody died.
struct MorningAnnouncement: View {
    let model: BoardViewModel
    let visible: Bool

    @State private var flipped = false
    private let ink = Color(hex: 0x3A2A17)

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.gold)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.Night.top))
                Text("الليلة \(model.round) انتهت...")
                    .font(.kufi(24, weight: 600))
                    .foregroundStyle(ink)

                cards
                    .padding(.vertical, 6)

                if let narration = model.narration {
                    Text(narration)
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 2) {
                    Text("يبدأ النهار \(model.round) خلال")
                        .font(.kufi(17, weight: 600))
                        .foregroundStyle(ink)
                    if let endsAt = model.phaseEndsAt {
                        TimelineView(.periodic(from: .now, by: 0.25)) { context in
                            Text("\(max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up))))")
                                .font(.system(size: 40, weight: .heavy).monospacedDigit())
                                .foregroundStyle(ink)
                                .contentTransition(.numericText(countsDown: true))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(ParchmentFrame())
            .padding(.horizontal, 20)
        }
        .environment(\.colorScheme, .light)
        .onChange(of: visible) { _, now in
            flipped = false
            guard now else { return }
            // Let the face-down card sit for a beat, then turn it over.
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { flipped = true }
            }
        }
    }

    @ViewBuilder private var cards: some View {
        let victims = model.lastNightVictims
        let width: CGFloat = victims.count > 1 ? 100 : 130
        if victims.isEmpty {
            CardBack(width: width).frame(width: width, height: width * 1.4)
        } else {
            HStack(spacing: 14) {
                ForEach(victims, id: \.id) { victim in
                    VStack(spacing: 6) {
                        FlipCard(
                            angle: flipped ? 180 : 0,
                            front: Group {
                                if let role = victim.role {
                                    CardFront(role: role, artwork: ArtAssets.role(role.id), width: width)
                                        .overlay(BloodSplatter(seed: victim.id).opacity(flipped ? 1 : 0))
                                } else {
                                    CardBack(width: width)
                                }
                            },
                            back: CardBack(width: width)
                        )
                        .frame(width: width, height: width * 1.4)
                        Text(victim.name).font(.system(size: 15, weight: .bold)).foregroundStyle(ink)
                    }
                }
            }
        }
    }
}
