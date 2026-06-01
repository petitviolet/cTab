import XCTest
@testable import cTab

final class NavigationTests: XCTestCase {
    func testNextIndexWraps() {
        XCTAssertEqual(Navigation.nextIndex(current: 0, count: 3), 1)
        XCTAssertEqual(Navigation.nextIndex(current: 2, count: 3), 0)
    }

    func testPreviousIndexWraps() {
        XCTAssertEqual(Navigation.previousIndex(current: 0, count: 3), 2)
        XCTAssertEqual(Navigation.previousIndex(current: 2, count: 3), 1)
    }

    func testNavigationWithEmptyList() {
        XCTAssertEqual(Navigation.nextIndex(current: 0, count: 0), 0)
        XCTAssertEqual(Navigation.previousIndex(current: 0, count: 0), 0)
    }

    func testInitialIndexSelectsPreviousWindow() {
        XCTAssertEqual(Navigation.initialIndex(count: 3), 1)
        XCTAssertEqual(Navigation.initialIndex(count: 1), 0)
        XCTAssertEqual(Navigation.initialIndex(count: 0), 0)
    }

    func testClamp() {
        XCTAssertEqual(Navigation.clamp(5, count: 3), 2)
        XCTAssertEqual(Navigation.clamp(-1, count: 3), 0)
        XCTAssertEqual(Navigation.clamp(1, count: 3), 1)
        XCTAssertEqual(Navigation.clamp(0, count: 0), 0)
    }

    func testSingleElementStaysZero() {
        XCTAssertEqual(Navigation.nextIndex(current: 0, count: 1), 0)
        XCTAssertEqual(Navigation.previousIndex(current: 0, count: 1), 0)
    }

    func testReverseInitialSelectionPicksLastIndex() {
        // 逆順起動の初期選択 previousIndex(current: 0) は末尾になる。
        XCTAssertEqual(Navigation.previousIndex(current: 0, count: 3), 2)
    }

    func testClampWithNegativeCount() {
        XCTAssertEqual(Navigation.clamp(0, count: -1), 0)
    }

    func testForwardCycleReturnsToStart() {
        var index = 0
        for _ in 0..<3 {
            index = Navigation.nextIndex(current: index, count: 3)
        }
        XCTAssertEqual(index, 0)
    }

    // MARK: - move (grid)

    func testMoveRightWrapsLikeNext() {
        XCTAssertEqual(Navigation.move(current: 6, count: 7, columns: 3, direction: .right), 0)
        XCTAssertEqual(Navigation.move(current: 0, count: 7, columns: 3, direction: .right), 1)
    }

    func testMoveLeftWrapsLikePrevious() {
        XCTAssertEqual(Navigation.move(current: 0, count: 7, columns: 3, direction: .left), 6)
    }

    func testMoveDownAddsColumns() {
        XCTAssertEqual(Navigation.move(current: 0, count: 7, columns: 3, direction: .down), 3)
    }

    func testMoveDownStaysWhenNoRowBelow() {
        // 5 + 3 = 8 >= 7 のため移動先なし
        XCTAssertEqual(Navigation.move(current: 5, count: 7, columns: 3, direction: .down), 5)
    }

    func testMoveUpSubtractsColumns() {
        XCTAssertEqual(Navigation.move(current: 3, count: 7, columns: 3, direction: .up), 0)
    }

    func testMoveUpStaysOnTopRow() {
        XCTAssertEqual(Navigation.move(current: 1, count: 7, columns: 3, direction: .up), 1)
    }

    func testMoveWithEmptyList() {
        XCTAssertEqual(Navigation.move(current: 0, count: 0, columns: 3, direction: .down), 0)
    }
}
