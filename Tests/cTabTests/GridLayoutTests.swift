import XCTest
import CoreGraphics
@testable import cTab

final class GridLayoutTests: XCTestCase {
    private let spacing: CGFloat = 16
    private let labelHeight: CGFloat = 30
    private let aspect: CGFloat = 220.0 / 140.0
    private let maxCell: CGFloat = 260

    private func solve(count: Int, available: CGSize) -> GridLayout.Result {
        GridLayout.solve(
            count: count,
            available: available,
            spacing: spacing,
            labelHeight: labelHeight,
            thumbnailAspect: aspect,
            maxCellWidth: maxCell
        )
    }

    func testSingleWindowUsesOneColumnClampedToMax() {
        let result = solve(count: 1, available: CGSize(width: 2000, height: 1200))
        XCTAssertEqual(result.columns, 1)
        XCTAssertEqual(result.rows, 1)
        XCTAssertEqual(result.cellWidth, maxCell, accuracy: 0.5)
    }

    func testGridFitsWithinAvailableArea() {
        // 少数〜多数まで、また小画面でも常に available 内に収まること（下限クランプ廃止の回帰防止）。
        let areas = [
            CGSize(width: 1600, height: 1000),
            CGSize(width: 1280, height: 720)
        ]
        for available in areas {
            for count in [2, 4, 6, 9, 12, 16, 30, 64, 100] {
                let result = solve(count: count, available: available)
                let size = GridLayout.contentSize(result, spacing: spacing)
                XCTAssertLessThanOrEqual(size.width, available.width + 0.5, "count=\(count) width overflow on \(available)")
                XCTAssertLessThanOrEqual(size.height, available.height + 0.5, "count=\(count) height overflow on \(available)")
                XCTAssertGreaterThanOrEqual(result.columns * result.rows, count, "count=\(count) cells insufficient")
            }
        }
    }

    func testRowsCoverAllItems() {
        let result = solve(count: 7, available: CGSize(width: 1600, height: 1000))
        XCTAssertGreaterThanOrEqual(result.columns * result.rows, 7)
    }

    func testZeroCountReturnsNoRows() {
        let result = solve(count: 0, available: CGSize(width: 1600, height: 1000))
        XCTAssertEqual(result.rows, 0)
    }

    func testRowCount() {
        XCTAssertEqual(GridLayout.rowCount(count: 7, columns: 3), 3)
        XCTAssertEqual(GridLayout.rowCount(count: 6, columns: 3), 2)
        XCTAssertEqual(GridLayout.rowCount(count: 1, columns: 3), 1)
    }
}
