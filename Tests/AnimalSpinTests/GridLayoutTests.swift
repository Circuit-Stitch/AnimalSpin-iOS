import CoreGraphics
import XCTest
@testable import AnimalSpin

/// The main grid must tile the whole iPad screen with no blank cell and with near-square cells (so
/// the square animal photos aren't cropped through their heads). This pins the column choice for
/// the real device sizes: 4 columns in portrait, 6 in landscape, for the 24-animal roster.
final class GridLayoutTests: XCTestCase {

    private let count = Animal.allCases.count

    func testRosterIs24() {
        // The chosen 4×6 / 6×4 grids assume exactly 24 animals; guard that assumption.
        XCTAssertEqual(count, 24)
    }

    func testPortraitIPadUsesFourColumns() {
        // 12.9", 11", 10.9", and mini portrait point sizes.
        for size in [CGSize(width: 1024, height: 1366),
                     CGSize(width: 834, height: 1194),
                     CGSize(width: 820, height: 1180),
                     CGSize(width: 744, height: 1133)] {
            XCTAssertEqual(GridLayout.fillingColumns(for: size, count: count), 4,
                           "portrait \(size) should be 4 columns")
        }
    }

    func testLandscapeIPadUsesSixColumns() {
        for size in [CGSize(width: 1366, height: 1024),
                     CGSize(width: 1194, height: 834),
                     CGSize(width: 1180, height: 820),
                     CGSize(width: 1133, height: 744)] {
            XCTAssertEqual(GridLayout.fillingColumns(for: size, count: count), 6,
                           "landscape \(size) should be 6 columns")
        }
    }

    func testFillingGridNeverLeavesABlankCell() {
        // Whatever column count is picked, it divides the roster exactly (every row full).
        for size in [CGSize(width: 1024, height: 1366), CGSize(width: 1366, height: 1024),
                     CGSize(width: 834, height: 1194), CGSize(width: 1194, height: 834)] {
            let columns = GridLayout.fillingColumns(for: size, count: count)
            XCTAssertEqual(count % columns, 0,
                           "\(columns) columns leaves a partial last row for \(size)")
        }
    }

    func testFillingGridPicksTheMostSquareOption() {
        // The winning column count's cells are at least as square as every alternative divisor's.
        let size = CGSize(width: 1024, height: 1366)
        let best = GridLayout.fillingColumns(for: size, count: count)
        let bestScore = GridLayout.squareness(columns: best, count: count, size: size)
        for columns in (1...count).filter({ count % $0 == 0 }) {
            XCTAssertLessThanOrEqual(
                bestScore, GridLayout.squareness(columns: columns, count: count, size: size))
        }
        // 4×6 cells on a 1024×1366 screen are within ~15% of square.
        XCTAssertLessThan(bestScore, 1.15)
    }

    func testScrollingColumnsForPhone() {
        XCTAssertEqual(GridLayout.scrollingColumns(forWidth: 393), 2)   // iPhone portrait → 2 fat cols
        XCTAssertEqual(GridLayout.scrollingColumns(forWidth: 200), 2)   // clamped to min 2
        XCTAssertEqual(GridLayout.scrollingColumns(forWidth: 1024), 5)  // ~200pt cells
    }
}
