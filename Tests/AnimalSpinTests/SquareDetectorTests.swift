import XCTest
import CoreGraphics
@testable import AnimalSpin

/// Verifies the parental-gate stroke classifier behaves like the Android original: squares (any
/// rotation) pass; circles, lines, tiny strokes, and short strokes don't.
final class SquareDetectorTests: XCTestCase {

    private func square(side: CGFloat, origin: CGPoint = .zero, rotation: CGFloat = 0) -> [CGPoint] {
        // Walk the perimeter with several samples per edge, optionally rotated about its centre.
        let corners = [
            CGPoint(x: 0, y: 0), CGPoint(x: side, y: 0),
            CGPoint(x: side, y: side), CGPoint(x: 0, y: side), CGPoint(x: 0, y: 0),
        ]
        var pts: [CGPoint] = []
        for e in 0..<4 {
            let a = corners[e], b = corners[e + 1]
            for s in 0..<10 {
                let t = CGFloat(s) / 10
                pts.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        pts.append(corners[0])
        let c = CGPoint(x: side / 2, y: side / 2)
        return pts.map { p in
            let dx = p.x - c.x, dy = p.y - c.y
            let rx = dx * cos(rotation) - dy * sin(rotation)
            let ry = dx * sin(rotation) + dy * cos(rotation)
            return CGPoint(x: origin.x + c.x + rx, y: origin.y + c.y + ry)
        }
    }

    func testAxisAlignedSquarePasses() {
        XCTAssertTrue(SquareDetector.isSquare(square(side: 200), minSide: 64))
    }

    func testRotatedSquarePasses() {
        XCTAssertTrue(SquareDetector.isSquare(square(side: 200, rotation: .pi / 5), minSide: 64))
    }

    func testCircleFails() {
        let pts = (0..<48).map { i -> CGPoint in
            let a = CGFloat(i) / 48 * 2 * .pi
            return CGPoint(x: 100 + 100 * cos(a), y: 100 + 100 * sin(a))
        }
        XCTAssertFalse(SquareDetector.isSquare(pts, minSide: 64))
    }

    func testVerticalScrollLineFails() {
        let pts = (0..<40).map { CGPoint(x: 10, y: CGFloat($0) * 10) }
        XCTAssertFalse(SquareDetector.isSquare(pts, minSide: 64))
    }

    func testTooSmallFails() {
        XCTAssertFalse(SquareDetector.isSquare(square(side: 40), minSide: 64))
    }

    func testTooFewPointsFails() {
        let pts = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]
        XCTAssertFalse(SquareDetector.isSquare(pts, minSide: 64))
    }

    func testTap(/* single point */) {
        XCTAssertFalse(SquareDetector.isSquare([CGPoint(x: 50, y: 50)], minSide: 64))
    }
}
