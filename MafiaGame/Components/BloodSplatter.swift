import SwiftUI

/// A blood stain for a dead player's card, drawn in code (or the `blood_splatter`
/// image asset if present). Seeded by the player's id, so each stain looks
/// different but stays the same for that player.
struct BloodSplatter: View {
    let seed: String

    var body: some View {
        if let art = ArtAssets.bloodSplatter {
            art.resizable().scaledToFit()
        } else {
            Canvas { ctx, size in draw(&ctx, size: size) }
                .accessibilityHidden(true)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        var rng = SeededGenerator(seed: seed)
        let w = size.width, h = size.height
        // Below the role name (which sits at the top of a small card) so it stays readable.
        let r = min(w, h) * 0.21
        let center = CGPoint(x: w * (0.42 + rng.unit() * 0.16), y: h * (0.54 + rng.unit() * 0.1))
        let blood = Color(hex: 0x8E0B0B)
        let deep = Color(hex: 0x5A0505)

        // Spikes thrown out from the impact.
        for _ in 0..<(9 + rng.int(5)) {
            let angle = rng.unit() * .pi * 2
            let length = r * (0.9 + rng.unit() * 0.9)
            let width = r * (0.08 + rng.unit() * 0.08)
            var spike = Path(ellipseIn: CGRect(x: 0, y: -width / 2, width: length, height: width))
            spike = spike.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
            ctx.fill(spike, with: .color(blood))
        }

        // The main pool: overlapping blobs.
        var pool = Path()
        for _ in 0..<(7 + rng.int(3)) {
            let offset = CGPoint(x: (rng.unit() - 0.5) * r * 1.1, y: (rng.unit() - 0.5) * r * 0.9)
            let br = r * (0.38 + rng.unit() * 0.38)
            pool.addEllipse(in: CGRect(x: center.x + offset.x - br, y: center.y + offset.y - br, width: br * 2, height: br * 2))
        }
        ctx.fill(pool, with: .color(blood))

        // Drips running down.
        for _ in 0..<(2 + rng.int(2)) {
            let x = center.x + (rng.unit() - 0.5) * r * 1.2
            let length = r * (0.7 + rng.unit() * 1.2)
            let dw = r * (0.14 + rng.unit() * 0.08)
            ctx.fill(Path(roundedRect: CGRect(x: x - dw / 2, y: center.y, width: dw, height: length), cornerRadius: dw / 2), with: .color(blood))
            ctx.fill(Path(ellipseIn: CGRect(x: x - dw * 0.75, y: center.y + length - dw, width: dw * 1.5, height: dw * 1.7)), with: .color(blood))
        }

        // Droplets.
        for _ in 0..<(10 + rng.int(6)) {
            let angle = rng.unit() * .pi * 2
            let distance = r * (1.1 + rng.unit() * 0.9)
            let dr = r * (0.04 + rng.unit() * 0.08)
            let p = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - dr, y: p.y - dr, width: dr * 2, height: dr * 2)), with: .color(blood))
        }

        // Darker core and a wet highlight.
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.45, y: center.y - r * 0.35, width: r * 0.9, height: r * 0.75)), with: .color(deep.opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.42, y: center.y - r * 0.5, width: r * 0.32, height: r * 0.16)), with: .color(.white.opacity(0.22)))
    }
}

/// Small deterministic generator (SplitMix64) seeded from a string.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: String) {
        state = seed.unicodeScalars.reduce(UInt64(5381)) { ($0 &<< 5) &+ $0 &+ UInt64($1.value) }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
    mutating func int(_ upper: Int) -> Int { Int(next() % UInt64(upper)) }
}

#Preview {
    HStack {
        ForEach(["p1", "p2", "p3"], id: \.self) { id in
            CardFront(role: PreviewData.doctorRole, width: 90)
                .frame(width: 90, height: 126)
                .overlay(BloodSplatter(seed: id))
        }
    }
    .padding()
    .background(Palette.Night.top)
}
