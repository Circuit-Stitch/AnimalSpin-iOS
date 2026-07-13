import SwiftUI

/// Hidden parental gate: drawing a square anywhere on the main screen opens Settings. Replaces
/// the old on-screen gear button, which a toddler could tap. The gesture is a *passive
/// observer* — it runs simultaneously with the grid's taps and scrolling and never consumes
/// touches, so animal taps still play and the grid still scrolls. (Ported from the Android
/// `MainScreen` pointer-input observer.)
extension View {
    func squareToUnlock(perform action: @escaping () -> Void) -> some View {
        modifier(SquareUnlockModifier(action: action))
    }
}

private struct SquareUnlockModifier: ViewModifier {
    let action: () -> Void
    @State private var points: [CGPoint] = []

    // 64pt minimum side — big enough that ordinary taps/short drags never qualify. (iOS points
    // are density-independent, matching the Android 64.dp threshold.)
    private let minSide: CGFloat = 64

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Reset at the START of each stroke (translation == .zero on the first event,
                    // since minimumDistance is 0), mirroring Android's fresh-per-gesture buffer.
                    // This survives a cancelled stroke that never fires onEnded (an interruption,
                    // or the ScrollView taking over) — stale points can't bleed into the next
                    // stroke and spuriously trip the gate.
                    if value.translation == .zero {
                        points = [value.location]
                    } else {
                        points.append(value.location)
                    }
                }
                .onEnded { _ in
                    if SquareDetector.isSquare(points, minSide: minSide) { action() }
                    points.removeAll()
                }
        )
    }
}

/// Detects whether a stroke traces a square-like loop — anywhere, any size, any rotation, drawn
/// clockwise or counter-clockwise. Pure functions, ported verbatim from the Android `isSquare`
/// / `rectilinearity` so the parental gate behaves identically.
enum SquareDetector {
    /// True if `points` trace a square-like loop: a closed loop with a roughly 1:1 bounding box
    /// (which holds for a square at any rotation) whose edges are "rectilinear" (all aligned to
    /// one of two perpendicular axes).
    static func isSquare(_ points: [CGPoint], minSide: CGFloat) -> Bool {
        guard points.count >= 8 else { return false }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let w = xs.max()! - xs.min()!
        let h = ys.max()! - ys.min()!
        if w < minSide || h < minSide { return false }

        // Bounding box stays ~1:1 at any rotation.
        let ratio = w / h
        if ratio < 0.5 || ratio > 2 { return false }

        // Closed loop: endpoints near each other.
        let closeDistance = hypot(points.first!.x - points.last!.x, points.first!.y - points.last!.y)
        if closeDistance > 0.40 * max(w, h) { return false }

        return rectilinearity(points) >= 0.60
    }

    /// 0…1 measure of how axis-aligned a stroke's edges are, invariant to overall rotation. Each
    /// segment direction is quadrupled — collapsing a square's four 90°-apart edge directions
    /// onto one angle — and length-weighted, so jitter barely counts. ~1 for a square/rectangle
    /// at any angle, ~0 for a circle, ~0.17 for a triangle.
    static func rectilinearity(_ points: [CGPoint]) -> CGFloat {
        var sx = 0.0
        var sy = 0.0
        var wsum = 0.0
        for i in 1..<points.count {
            let dx = Double(points[i].x - points[i - 1].x)
            let dy = Double(points[i].y - points[i - 1].y)
            let len = hypot(dx, dy)
            if len == 0 { continue }
            let angle = atan2(dy, dx) * 4.0
            sx += len * cos(angle)
            sy += len * sin(angle)
            wsum += len
        }
        return wsum == 0 ? 0 : CGFloat(hypot(sx, sy) / wsum)
    }
}
