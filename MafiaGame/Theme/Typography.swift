import SwiftUI
import UIKit

extension Font {
    /// Reem Kufi for titles and role names. The bundled file is a variable font,
    /// so the weight is set on its `wght` axis.
    static func kufi(_ size: CGFloat, weight: CGFloat = 500, relativeTo style: Font.TextStyle = .title) -> Font {
        let wghtAxis = 0x7767_6874 // 'wght'
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Reem Kufi",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight],
        ])
        let scaled = UIFontMetrics(forTextStyle: style.uiKit).scaledValue(for: size)
        return Font(UIFont(descriptor: descriptor, size: scaled))
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}
