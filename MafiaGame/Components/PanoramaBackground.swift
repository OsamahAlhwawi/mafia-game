import SwiftUI

/// The home screen's slowly turning 360° view of the old town at night, like a
/// game's title menu. Uses the `home_panorama` image (a seamless 2:1
/// equirectangular panorama) when present; otherwise draws the scene in layers
/// that drift at different speeds, so it reads as a camera turning in place.
struct PanoramaBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for one full turn.
    static let turnDuration: TimeInterval = 150

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let progress = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.turnDuration) / Self.turnDuration
            if let image = ArtAssets.homePanorama {
                ImagePanorama(image: image, progress: progress)
            } else {
                DrawnPanorama(progress: progress)
            }
        }
        .ignoresSafeArea()
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

/// An equirectangular image wraps seamlessly left to right, so sliding two
/// copies side by side is a full turn. Zoomed in so the stretched poles stay off screen.
private struct ImagePanorama: View {
    let image: Image
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height * 1.4
            let width = height * 2
            HStack(spacing: 0) {
                image.resizable().frame(width: width, height: height)
                image.resizable().frame(width: width, height: height)
            }
            .offset(x: -width * progress, y: (geo.size.height - height) / 2)
        }
        .overlay(LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
    }
}

/// Parallax layers, each periodic so the loop never shows a seam.
private struct DrawnPanorama: View {
    let progress: Double

    private struct Building {
        let x: CGFloat, width: CGFloat, height: CGFloat
        let tower: Bool
        let litWindow: Bool
    }

    private struct Point { let x: CGFloat, y: CGFloat, size: CGFloat }

    /// Laid out once in units of the layer's period (0…1), seeded so it never changes.
    private static let buildings: [Building] = {
        var rng = SplitMix(seed: 7)
        var items: [Building] = []
        var x: CGFloat = 0
        while x < 1 {
            let tower = rng.unit() < 0.12
            let width = tower ? 0.018 : 0.025 + rng.unit() * 0.03
            items.append(Building(x: x, width: width, height: tower ? 0.55 + rng.unit() * 0.2 : 0.22 + rng.unit() * 0.22,
                                  tower: tower, litWindow: rng.unit() < 0.45))
            x += width - 0.001
        }
        return items
    }()

    private static let stars: [Point] = {
        var rng = SplitMix(seed: 11)
        return (0..<90).map { _ in Point(x: rng.unit(), y: rng.unit() * 0.5, size: rng.unit() < 0.15 ? 1.6 : 0.9) }
    }()

    private static let palms: [Point] = {
        var rng = SplitMix(seed: 23)
        return (0..<9).map { i in Point(x: (CGFloat(i) + rng.unit() * 0.6) / 9, y: 0, size: 0.8 + rng.unit() * 0.5) }
    }()

    private static let lanterns: [CGFloat] = (0..<10).map { (CGFloat($0) + 0.5) / 10 }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let horizon = h * 0.46
            // One full turn shows four screens of houses; layers further away move less.
            let period = w * 4

            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x050816), Color(hex: 0x111A42), Color(hex: 0x1F2A5A)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

            drawStars(&ctx, size: size, offset: progress * period * 0.35, period: period)
            drawMoon(&ctx, size: size, offset: progress * period * 0.35, period: period)
            drawDunes(&ctx, size: size, horizon: horizon, offset: progress * period * 0.6, period: period * 0.75)

            // Ground under the houses.
            ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x171E46), Color(hex: 0x080B1C)]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))

            drawBuildings(&ctx, size: size, base: horizon + 6, offset: progress * period, period: period)
            drawLanterns(&ctx, size: size, y: horizon + h * 0.06, offset: progress * period * 1.25, period: period * 1.25)
            drawPalms(&ctx, size: size, base: horizon + h * 0.09, offset: progress * period * 1.6, period: period * 1.6)

            // Darken the bottom so the menu reads clearly.
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [.clear, .black.opacity(0.5)]),
                startPoint: CGPoint(x: 0, y: h * 0.55), endPoint: CGPoint(x: 0, y: h)))
        }
    }

    /// Screen x positions for a point at `unitX` in a layer scrolled by `offset`;
    /// drawn twice near the wrap so it never pops.
    private func positions(_ unitX: CGFloat, period: CGFloat, offset: Double, width: CGFloat, margin: CGFloat) -> [CGFloat] {
        var x = (unitX * period - CGFloat(offset)).truncatingRemainder(dividingBy: period)
        if x < 0 { x += period }
        return [x, x - period].filter { $0 > -margin && $0 < width + margin }
    }

    private func drawStars(_ ctx: inout GraphicsContext, size: CGSize, offset: Double, period: CGFloat) {
        for star in Self.stars {
            for x in positions(star.x, period: period, offset: offset, width: size.width, margin: 4) {
                let r = star.size
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: star.y * size.height - r, width: r * 2, height: r * 2)),
                         with: .color(Palette.Night.text.opacity(0.85)))
            }
        }
    }

    private func drawMoon(_ ctx: inout GraphicsContext, size: CGSize, offset: Double, period: CGFloat) {
        let r = size.width * 0.06
        for x in positions(0.18, period: period, offset: offset, width: size.width, margin: r * 4) {
            let c = CGPoint(x: x, y: size.height * 0.13)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 4, y: c.y - r * 4, width: r * 8, height: r * 8)),
                     with: .radialGradient(Gradient(colors: [Palette.Night.moon.opacity(0.22), .clear]), center: c, startRadius: 0, endRadius: r * 4))
            var moon = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 1.25, width: r * 2, height: r * 2)))
            ctx.fill(moon, with: .color(Palette.Night.moon))
        }
    }

    /// Low dunes on the horizon: a sum of sines whose period divides the layer's, so it loops.
    private func drawDunes(_ ctx: inout GraphicsContext, size: CGSize, horizon: CGFloat, offset: Double, period: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 8 {
            let u = (x + CGFloat(offset)) / period * 2 * .pi
            let y = horizon - size.height * 0.05 - 16 * sin(u * 3) - 9 * sin(u * 7 + 1.3) - 5 * sin(u * 13 + 0.4)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 8
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(hex: 0x141C44)))
    }

    private func drawBuildings(_ ctx: inout GraphicsContext, size: CGSize, base: CGFloat, offset: Double, period: CGFloat) {
        let unit = size.height * 0.28
        for b in Self.buildings {
            let bw = b.width * period, bh = b.height * unit
            for x in positions(b.x, period: period, offset: offset, width: size.width, margin: bw + 10) {
                let rect = CGRect(x: x, y: base - bh, width: bw, height: bh)
                if b.tower {
                    var tower = Path()
                    tower.move(to: CGPoint(x: rect.minX + bw * 0.08, y: rect.minY))
                    tower.addLine(to: CGPoint(x: rect.maxX - bw * 0.08, y: rect.minY))
                    tower.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    tower.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    tower.closeSubpath()
                    ctx.fill(tower, with: .color(Color(hex: 0x2A2852)))
                } else {
                    ctx.fill(Path(rect), with: .color(Color(hex: 0x302E5C)))
                    ctx.fill(Path(CGRect(x: rect.maxX - bw * 0.2, y: rect.minY, width: bw * 0.2, height: bh)), with: .color(Color(hex: 0x252350)))
                }
                // Stepped Najdi crenellations along the roof.
                let step = max(5, bw * 0.13)
                var cx = rect.minX + (b.tower ? bw * 0.08 : 0)
                let end = rect.maxX - (b.tower ? bw * 0.08 : 0)
                while cx + step <= end + 0.5 {
                    var tri = Path()
                    tri.move(to: CGPoint(x: cx, y: rect.minY))
                    tri.addLine(to: CGPoint(x: cx + step / 2, y: rect.minY - step))
                    tri.addLine(to: CGPoint(x: cx + step, y: rect.minY))
                    tri.closeSubpath()
                    ctx.fill(tri, with: .color(Color(hex: 0x302E5C)))
                    cx += step * 1.25
                }
                // A window, warmly lit in some houses.
                let ws = max(5, bw * 0.16)
                let wc = CGPoint(x: rect.midX - bw * 0.05, y: rect.minY + bh * (b.tower ? 0.25 : 0.45))
                let window = CGRect(x: wc.x - ws / 2, y: wc.y - ws / 2, width: ws, height: ws)
                if b.litWindow {
                    ctx.fill(Path(ellipseIn: window.insetBy(dx: -ws * 1.6, dy: -ws * 1.6)),
                             with: .radialGradient(Gradient(colors: [Color(hex: 0xFFB347).opacity(0.35), .clear]), center: wc, startRadius: 0, endRadius: ws * 2.2))
                    ctx.fill(Path(window), with: .color(Color(hex: 0xFFC56B)))
                } else {
                    ctx.fill(Path(window), with: .color(Color(hex: 0x1C1A3E)))
                }
            }
        }
    }

    private func drawLanterns(_ ctx: inout GraphicsContext, size: CGSize, y: CGFloat, offset: Double, period: CGFloat) {
        for unitX in Self.lanterns {
            for x in positions(unitX, period: period, offset: offset, width: size.width, margin: 50) {
                let glow = CGPoint(x: x, y: y - 34)
                ctx.fill(Path(ellipseIn: CGRect(x: glow.x - 46, y: glow.y - 46, width: 92, height: 92)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFB347).opacity(0.4), .clear]), center: glow, startRadius: 0, endRadius: 46))
                ctx.fill(Path(CGRect(x: x - 1.5, y: y - 28, width: 3, height: 32)), with: .color(Color(hex: 0x0E1230)))
                ctx.fill(Path(roundedRect: CGRect(x: x - 6, y: y - 42, width: 12, height: 15), cornerRadius: 2), with: .color(Color(hex: 0xFFC56B)))
            }
        }
    }

    private func drawPalms(_ ctx: inout GraphicsContext, size: CGSize, base: CGFloat, offset: Double, period: CGFloat) {
        let silhouette = Color(hex: 0x070A1A)
        for palm in Self.palms {
            let height = size.height * 0.3 * palm.size
            for x in positions(palm.x, period: period, offset: offset, width: size.width, margin: height) {
                let root = CGPoint(x: x, y: base)
                let top = CGPoint(x: x + height * 0.1, y: base - height)
                var trunk = Path()
                trunk.move(to: root)
                trunk.addQuadCurve(to: top, control: CGPoint(x: x - height * 0.12, y: base - height * 0.5))
                ctx.stroke(trunk, with: .color(silhouette), style: StrokeStyle(lineWidth: height * 0.06, lineCap: .round))
                for k in 0..<8 {
                    let angle = Double(k) / 7 * .pi * 1.15 + .pi * 0.93
                    let len = height * 0.45
                    let tip = CGPoint(x: top.x + cos(angle) * len, y: top.y + sin(angle) * len * 0.55 + len * 0.28)
                    var frond = Path()
                    frond.move(to: top)
                    frond.addQuadCurve(to: tip, control: CGPoint(x: top.x + cos(angle) * len * 0.6, y: top.y + sin(angle) * len * 0.6 - len * 0.22))
                    ctx.stroke(frond, with: .color(silhouette), style: StrokeStyle(lineWidth: height * 0.045, lineCap: .round))
                }
            }
        }
    }
}

/// Deterministic generator so the drawn town is the same every launch.
private struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func unit() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) >> 11) / CGFloat(1 << 53)
    }
}

#Preview {
    PanoramaBackground()
}
