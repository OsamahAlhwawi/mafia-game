import SwiftUI
import UIKit

/// Optional illustrated art. Drop `<name>.webp` into `Resources/Art` (or an
/// image set with that name into Assets.xcassets) and it replaces the art
/// drawn in code; nothing else changes. Prompts and sizes: docs/art-prompts.md.
@MainActor
enum ArtAssets {
    /// Decoded once per name; `nil` entries remember that an image is missing.
    private static var cache: [String: UIImage?] = [:]

    static func image(_ name: String) -> Image? {
        if let cached = cache[name] { return cached.map(Image.init(uiImage:)) }
        let image = UIImage(named: name)
            ?? Bundle.main.url(forResource: name, withExtension: "webp").flatMap { UIImage(contentsOfFile: $0.path) }
        cache[name] = image
        return image.map(Image.init(uiImage:))
    }

    static var boardDay: Image? { image("board_day") }
    static var boardNight: Image? { image("board_night") }
    static var cardBack: Image? { image("card_back") }
    /// Transparent PNG/WebP laid over a dead player's card.
    static var bloodSplatter: Image? { image("blood_splatter") }
    /// Seamless 2:1 equirectangular panorama for the home screen's turning background.
    static var homePanorama: Image? { image("home_panorama") }

    /// `role_mafia`, `role_doctor`, …
    static func role(_ id: RoleID) -> Image? { image("role_\(id.rawValue)") }
}
