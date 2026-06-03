import XCTest
import CoreGraphics
@testable import cTab

final class SwitcherViewModelTests: XCTestCase {
    func testUpdateReplacesWindowsAndIndex() {
        let model = SwitcherViewModel()
        model.update(
            windows: [WindowInfoFixture.make(id: 1), WindowInfoFixture.make(id: 2)],
            selectedIndex: 1
        )
        XCTAssertEqual(model.windows.count, 2)
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testSetThumbnailUpdatesMatchingWindow() {
        let model = SwitcherViewModel()
        model.update(
            windows: [WindowInfoFixture.make(id: 1), WindowInfoFixture.make(id: 2)],
            selectedIndex: 0
        )
        model.setThumbnail(Self.makeImage(), for: 2)
        XCTAssertNil(model.windows[0].thumbnail)
        XCTAssertNotNil(model.windows[1].thumbnail)
    }

    func testSetThumbnailIgnoresUnknownID() {
        let model = SwitcherViewModel()
        model.update(windows: [WindowInfoFixture.make(id: 1)], selectedIndex: 0)
        model.setThumbnail(Self.makeImage(), for: 999)
        XCTAssertNil(model.windows[0].thumbnail)
    }

    private static func makeImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}
