import CoreGraphics

/// Pure geometry for the main animal grid, split out from `MainView` so it can be unit-tested
/// without a running view hierarchy.
enum GridLayout {
    /// Columns for a screen-filling grid (iPad): the divisor of `count` whose resulting cells come
    /// out closest to square. Because the chosen column count divides `count`, every row is full —
    /// there is never a blank cell. Square photos in near-square cells also crop the least, which
    /// is what keeps animals' heads and noses from being cut off. For the 24-animal roster this is
    /// 4 columns in portrait and 6 in landscape.
    static func fillingColumns(for size: CGSize, count: Int) -> Int {
        guard count > 0 else { return 1 }
        let divisors = (1...count).filter { count % $0 == 0 }
        return divisors.min {
            squareness(columns: $0, count: count, size: size)
                < squareness(columns: $1, count: count, size: size)
        } ?? 1
    }

    /// Columns for the scrollable phone grid: how many ~200pt cells fit across, minimum 2 — so
    /// cells stay finger-big and the grid scrolls when the rows overflow.
    static func scrollingColumns(forWidth width: CGFloat) -> Int {
        max(Int(width / 200), 2)
    }

    /// How far a `columns`-wide grid's cells stray from square, as a ratio ≥ 1 (1 = a perfect
    /// square, larger = more lopsided). Used to rank candidate column counts.
    static func squareness(columns: Int, count: Int, size: CGSize) -> CGFloat {
        let rows = CGFloat((count + columns - 1) / columns)   // ceil(count / columns)
        let ratio = (size.width / CGFloat(columns)) / (size.height / rows)
        return ratio >= 1 ? ratio : 1 / ratio
    }
}
