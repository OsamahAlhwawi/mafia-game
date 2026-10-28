import CoreGraphics

/// Where the other players sit around the narrator's scroll: two columns,
/// right first (RTL), shrinking seats when a column gets crowded (up to 6 a side).
enum BoardLayout {
    /// Seat height at full size: card + overlapping avatar + name.
    /// Action tab + card + overlapping avatar + name.
    static let seatHeight: CGFloat = 180
    static let seatWidth: CGFloat = 100
    static let cardWidth: CGFloat = 76

    static func columns<T>(_ others: [T]) -> (right: [T], left: [T]) {
        let split = (others.count + 1) / 2
        return (Array(others.prefix(split)), Array(others.dropFirst(split)))
    }

    /// Scale for seats so `perColumn` of them fit in `height`.
    static func scale(perColumn: Int, height: CGFloat) -> CGFloat {
        guard perColumn > 0 else { return 1 }
        return min(1, height / (CGFloat(perColumn) * seatHeight))
    }
}
