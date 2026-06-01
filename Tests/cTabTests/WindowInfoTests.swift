import XCTest
@testable import cTab

final class WindowInfoTests: XCTestCase {
    func testDisplayTitleUsesTitleWhenPresent() {
        let window = WindowInfoFixture.make(appName: "Safari", title: "Apple")
        XCTAssertEqual(window.displayTitle, "Apple")
    }

    func testDisplayTitleFallsBackToAppNameWhenEmpty() {
        let window = WindowInfoFixture.make(appName: "Safari", title: "")
        XCTAssertEqual(window.displayTitle, "Safari")
    }

    func testDisplayTitleFallsBackWhenWhitespaceOnly() {
        let window = WindowInfoFixture.make(appName: "Safari", title: "   ")
        XCTAssertEqual(window.displayTitle, "Safari")
    }
}
