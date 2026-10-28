import SwiftUI

/// Eight-pointed star (khatam): two overlapping squares, one turned 45°.
struct KhatamStar: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) / sqrt(2)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        var path = Path(square)
        let turn = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: .pi / 4)
            .translatedBy(x: -rect.midX, y: -rect.midY)
        path.addPath(Path(square).applying(turn))
        return path
    }
}

/// Repeating khatam pattern drawn in code (no image assets).
struct KhatamPattern: View {
    var color: Color = Palette.gold
    var spacing: CGFloat = 32
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let star = spacing * 0.44
            var y: CGFloat = spacing / 2
            while y < size.height + spacing {
                var x: CGFloat = spacing / 2
                while x < size.width + spacing {
                    let rect = CGRect(x: x - star / 2, y: y - star / 2, width: star, height: star)
                    context.stroke(KhatamStar().path(in: rect), with: .color(color), lineWidth: lineWidth)
                    x += spacing
                }
                y += spacing
            }
        }
        .accessibilityHidden(true)
    }
}
