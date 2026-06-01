import XCTest
import CoreGraphics
@testable import cTab

final class ThumbnailCacheTests: XCTestCase {
    func testStoreAndRetrieve() {
        let cache = ThumbnailCache()
        cache.store(Self.makeImage(), for: 1)
        XCTAssertNotNil(cache.image(for: 1))
        XCTAssertNil(cache.image(for: 2))
    }

    func testPruneEvictsMissingWindows() {
        let cache = ThumbnailCache()
        cache.store(Self.makeImage(), for: 1)
        cache.store(Self.makeImage(), for: 2)
        cache.prune(keeping: [1])
        XCTAssertNotNil(cache.image(for: 1))
        XCTAssertNil(cache.image(for: 2))
    }

    func testRemoveAll() {
        let cache = ThumbnailCache()
        cache.store(Self.makeImage(), for: 1)
        cache.removeAll()
        XCTAssertNil(cache.image(for: 1))
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
