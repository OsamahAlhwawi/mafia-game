import SwiftUI

/// The game board: an old Najdi neighbourhood around a sandy square. Uses the
/// `board_day` / `board_night` images when they're in the asset catalog,
/// otherwise draws the scene in code. Day and night cross-fade.
struct BoardBackground: View {
    let theme: PhaseTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isNight = theme == .night
        ZStack {
            if let day = ArtAssets.boardDay, let night = ArtAssets.boardNight {
                day.resizable().scaledToFill()
                night.resizable().scaledToFill().opacity(isNight ? 1 : 0)
            } else {
                NajdiTownScene(night: false)
                NajdiTownScene(night: true).opacity(isNight ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .easeInOut(duration: 1.5), value: theme)
        .accessibilityHidden(true)
    }
}

/// Mud-brick houses with stepped Najdi crenellations, a watchtower, palms and lanterns.
struct NajdiTownScene: View {
    let night: Bool

    private struct Colors {
        let skyTop, skyBottom, wall, wallShade, trim, window, groundTop, groundBottom, plaza, trunk, frond: Color
    }

    private var c: Colors {
        night
            ? Colors(
                skyTop: Color(hex: 0x0B1026), skyBottom: Color(hex: 0x1B2550),
                wall: Color(hex: 0x3D3A68), wallShade: Color(hex: 0x2D2B55), trim: Color(hex: 0x23214A),
                window: Color(hex: 0xFFC56B),
                groundTop: Color(hex: 0x1F2853), groundBottom: Color(hex: 0x151C42), plaza: Color(hex: 0x27315F),
                trunk: Color(hex: 0x2A2448), frond: Color(hex: 0x1E3352)
            )
            : Colors(
                skyTop: Color(hex: 0xFFF3DA), skyBottom: Color(hex: 0xF4DDB0),
                wall: Color(hex: 0xCFA36A), wallShade: Color(hex: 0xB78953), trim: Color(hex: 0x9A6C3B),
                window: Color(hex: 0x5A3B1E),
                groundTop: Color(hex: 0xE8CC95), groundBottom: Color(hex: 0xD6B077), plaza: Color(hex: 0xF0DCAE),
                trunk: Color(hex: 0x7A5230), frond: Color(hex: 0x5F7B3A)
            )
    }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let skyline = h * 0.24

            // Sky and ground.
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: skyline)), with: .linearGradient(
                Gradient(colors: [c.skyTop, c.skyBottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: skyline)))
            ctx.fill(Path(CGRect(x: 0, y: skyline, width: w, height: h - skyline)), with: .linearGradient(
                Gradient(colors: [c.groundTop, c.groundBottom]), startPoint: CGPoint(x: 0, y: skyline), endPoint: CGPoint(x: 0, y: h)))

            if night { drawStars(&ctx, w: w, h: skyline) }
            drawCelestial(&ctx, w: w, skyline: skyline)
            drawSkyline(&ctx, w: w, base: skyline)

            // The square where the narrator's scroll sits.
            let plaza = CGRect(x: w * 0.2, y: skyline + h * 0.04, width: w * 0.6, height: h * 0.52)
            ctx.fill(Path(roundedRect: plaza, cornerRadius: w * 0.12), with: .color(c.plaza.opacity(0.75)))
            ctx.stroke(Path(roundedRect: plaza.insetBy(dx: 6, dy: 6), cornerRadius: w * 0.11),
                       with: .color(c.trim.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))

            for (x, y, s) in [(0.07, 0.36, 1.0), (0.95, 0.33, 0.9), (0.05, 0.80, 1.1), (0.96, 0.78, 1.0)] {
                drawPalm(&ctx, at: CGPoint(x: w * x, y: h * y), height: w * 0.26 * s)
            }
            for (x, y) in [(0.2, 0.3), (0.8, 0.3), (0.2, 0.79), (0.8, 0.79)] {
                drawLantern(&ctx, at: CGPoint(x: w * x, y: h * y))
            }

            // Soft vignette to pull the eye to the middle.
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(night ? 0.45 : 0.18)]),
                center: CGPoint(x: w / 2, y: h * 0.5), startRadius: w * 0.45, endRadius: h * 0.75))
        }
    }

    private func drawStars(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        for i in 0..<28 {
            let x = CGFloat((i * 73) % 100) / 100 * w
            let y = CGFloat((i * 37) % 100) / 100 * h * 0.85
            let r: CGFloat = i % 5 == 0 ? 1.4 : 0.9
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(Palette.Night.text.opacity(0.8)))
        }
    }

    private func drawCelestial(_ ctx: inout GraphicsContext, w: CGFloat, skyline: CGFloat) {
        let center = CGPoint(x: w * 0.5, y: skyline * 0.42)
        if night {
            let r = w * 0.06
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 3, y: center.y - r * 3, width: r * 6, height: r * 6)),
                     with: .radialGradient(Gradient(colors: [Palette.Night.moon.opacity(0.25), .clear]), center: center, startRadius: 0, endRadius: r * 3))
            var moon = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: center.x - r * 0.45, y: center.y - r * 1.25, width: r * 2, height: r * 2)))
            ctx.fill(moon, with: .color(Palette.Night.moon))
        } else {
            let r = w * 0.065
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 3, y: center.y - r * 3, width: r * 6, height: r * 6)),
                     with: .radialGradient(Gradient(colors: [Palette.Day.sun.opacity(0.35), .clear]), center: center, startRadius: 0, endRadius: r * 3))
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(Palette.Day.sun))
        }
    }

    /// A row of houses along the top, with a taller watchtower (مربّعة).
    private func drawSkyline(_ ctx: inout GraphicsContext, w: CGFloat, base: CGFloat) {
        let heights: [CGFloat] = [0.55, 0.75, 0.6, 0.9, 0.5, 0.7, 0.62, 0.8, 0.55]
        let widths: [CGFloat] = [0.12, 0.1, 0.13, 0.09, 0.12, 0.1, 0.12, 0.1, 0.12]
        var x: CGFloat = -w * 0.02
        let unit = base * 0.32
        for (i, hFrac) in heights.enumerated() {
            let bw = widths[i] * w
            let bh = unit * hFrac + unit * 0.4
            let rect = CGRect(x: x, y: base - bh, width: bw, height: bh)
            drawHouse(&ctx, rect: rect, lit: i % 3 != 1)
            x += bw - 1
            if i == 3 {
                // Watchtower: slightly tapered, taller.
                let tw = w * 0.07, th = unit * 1.9
                var tower = Path()
                tower.move(to: CGPoint(x: x + tw * 0.08, y: base - th))
                tower.addLine(to: CGPoint(x: x + tw * 0.92, y: base - th))
                tower.addLine(to: CGPoint(x: x + tw, y: base))
                tower.addLine(to: CGPoint(x: x, y: base))
                tower.closeSubpath()
                ctx.fill(tower, with: .color(c.wallShade))
                drawCrenellations(&ctx, from: x + tw * 0.08, to: x + tw * 0.92, y: base - th, size: tw * 0.16)
                for k in 0..<3 {
                    drawWindow(&ctx, at: CGPoint(x: x + tw / 2, y: base - th + tw * (0.5 + CGFloat(k) * 0.55)), size: tw * 0.18, lit: k == 0)
                }
                x += tw - 1
            }
        }
        // Base line where houses meet the square.
        ctx.fill(Path(CGRect(x: 0, y: base - 2, width: w, height: 4)), with: .color(c.trim.opacity(0.6)))
    }

    private func drawHouse(_ ctx: inout GraphicsContext, rect: CGRect, lit: Bool) {
        ctx.fill(Path(rect), with: .color(c.wall))
        // Shaded side gives a bit of depth.
        ctx.fill(Path(CGRect(x: rect.maxX - rect.width * 0.18, y: rect.minY, width: rect.width * 0.18, height: rect.height)), with: .color(c.wallShade))
        // Trim band under the roof line.
        ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY + rect.width * 0.12, width: rect.width, height: 2)), with: .color(c.trim.opacity(0.7)))
        drawCrenellations(&ctx, from: rect.minX, to: rect.maxX, y: rect.minY, size: max(5, rect.width * 0.12))
        // Triangular vents and a window, typical of Najdi facades.
        let s = rect.width * 0.12
        for k in 0..<3 {
            var tri = Path()
            let cx = rect.minX + rect.width * (0.25 + CGFloat(k) * 0.22)
            let ty = rect.minY + rect.width * 0.22
            tri.move(to: CGPoint(x: cx, y: ty))
            tri.addLine(to: CGPoint(x: cx + s / 2, y: ty + s * 0.8))
            tri.addLine(to: CGPoint(x: cx - s / 2, y: ty + s * 0.8))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(c.trim.opacity(0.8)))
        }
        drawWindow(&ctx, at: CGPoint(x: rect.midX - rect.width * 0.08, y: rect.maxY - rect.height * 0.42), size: s * 1.4, lit: lit)
        // Wooden door.
        let door = CGRect(x: rect.midX - s * 0.6 + rect.width * 0.12, y: rect.maxY - s * 2.4, width: s * 1.3, height: s * 2.4)
        ctx.fill(Path(roundedRect: door, cornerRadius: 1.5), with: .color(night ? c.trim : Color(hex: 0x7A4E26)))
    }

    private func drawCrenellations(_ ctx: inout GraphicsContext, from x0: CGFloat, to x1: CGFloat, y: CGFloat, size: CGFloat) {
        var x = x0
        while x + size <= x1 + 0.5 {
            var step = Path()
            step.move(to: CGPoint(x: x, y: y))
            step.addLine(to: CGPoint(x: x + size / 2, y: y - size))
            step.addLine(to: CGPoint(x: x + size, y: y))
            step.closeSubpath()
            ctx.fill(step, with: .color(c.wall))
            x += size * 1.25
        }
    }

    private func drawWindow(_ ctx: inout GraphicsContext, at p: CGPoint, size: CGFloat, lit: Bool) {
        let rect = CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
        if night && lit {
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: -size, dy: -size)),
                     with: .radialGradient(Gradient(colors: [c.window.opacity(0.35), .clear]), center: p, startRadius: 0, endRadius: size * 1.5))
            ctx.fill(Path(rect), with: .color(c.window))
        } else {
            ctx.fill(Path(rect), with: .color(night ? c.trim : c.window))
        }
    }

    private func drawPalm(_ ctx: inout GraphicsContext, at base: CGPoint, height: CGFloat) {
        let top = CGPoint(x: base.x + height * 0.08, y: base.y - height)
        var trunk = Path()
        trunk.move(to: base)
        trunk.addQuadCurve(to: top, control: CGPoint(x: base.x - height * 0.12, y: base.y - height * 0.5))
        ctx.stroke(trunk, with: .color(c.trunk), style: StrokeStyle(lineWidth: height * 0.07, lineCap: .round))
        for k in 0..<7 {
            let angle = Double(k) / 6 * .pi * 1.1 + .pi * 0.95
            let len = height * 0.42
            let tip = CGPoint(x: top.x + cos(angle) * len, y: top.y + sin(angle) * len * 0.55 + len * 0.25)
            var frond = Path()
            frond.move(to: top)
            frond.addQuadCurve(to: tip, control: CGPoint(x: top.x + cos(angle) * len * 0.6, y: top.y + sin(angle) * len * 0.6 - len * 0.2))
            ctx.stroke(frond, with: .color(c.frond), style: StrokeStyle(lineWidth: height * 0.05, lineCap: .round))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: top.x - height * 0.05, y: top.y - height * 0.03, width: height * 0.1, height: height * 0.1)), with: .color(c.trunk))
    }

    private func drawLantern(_ ctx: inout GraphicsContext, at p: CGPoint) {
        let pole = Path(CGRect(x: p.x - 1.2, y: p.y - 26, width: 2.4, height: 30))
        ctx.fill(pole, with: .color(c.trim))
        let box = CGRect(x: p.x - 5, y: p.y - 38, width: 10, height: 13)
        if night {
            let glow = CGPoint(x: box.midX, y: box.midY)
            ctx.fill(Path(ellipseIn: box.insetBy(dx: -34, dy: -34)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFB347).opacity(0.45), .clear]), center: glow, startRadius: 0, endRadius: 40))
            ctx.fill(Path(roundedRect: box, cornerRadius: 2), with: .color(Color(hex: 0xFFC56B)))
        } else {
            ctx.fill(Path(roundedRect: box, cornerRadius: 2), with: .color(c.trim))
        }
    }
}

#Preview {
    HStack(spacing: 0) {
        NajdiTownScene(night: false)
        NajdiTownScene(night: true)
    }
    .ignoresSafeArea()
}
