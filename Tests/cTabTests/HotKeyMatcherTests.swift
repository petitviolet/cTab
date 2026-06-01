import XCTest
import CoreGraphics
@testable import cTab

final class HotKeyMatcherTests: XCTestCase {
    func testSwitchTriggerRequiresCommandAndTab() {
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: .maskCommand))
        // Command なしの Tab は対象外
        XCTAssertFalse(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: []))
        // Command 付きでも別キーは対象外
        XCTAssertFalse(HotKeyMatcher.isSwitchTrigger(keyCode: 0x00, flags: .maskCommand))
    }

    func testReverseDetectsShift() {
        XCTAssertTrue(HotKeyMatcher.isReverse(flags: [.maskCommand, .maskShift]))
        XCTAssertFalse(HotKeyMatcher.isReverse(flags: [.maskCommand]))
    }

    func testCommandReleased() {
        XCTAssertTrue(HotKeyMatcher.isCommandReleased(flags: []))
        XCTAssertFalse(HotKeyMatcher.isCommandReleased(flags: [.maskCommand]))
    }

    func testReverseSwitchTriggerIsStillSwitchTrigger() {
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: [.maskCommand, .maskShift]))
    }

    func testSwitchTriggerToleratesExtraModifiers() {
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: [.maskCommand, .maskAlternate]))
    }

    func testCommandReleasedWhenOnlyShiftRemains() {
        XCTAssertTrue(HotKeyMatcher.isCommandReleased(flags: [.maskShift]))
    }

    func testIsCancelDetectsEscape() {
        XCTAssertTrue(HotKeyMatcher.isCancel(keyCode: 0x35))
        XCTAssertFalse(HotKeyMatcher.isCancel(keyCode: 0x30))
    }

    func testArrowDirectionMapping() {
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7B), .left)
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7C), .right)
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7D), .down)
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7E), .up)
        XCTAssertNil(HotKeyMatcher.arrowDirection(keyCode: 0x30))
    }

    func testCloseWindowRequiresCommandAndW() {
        XCTAssertTrue(HotKeyMatcher.isCloseWindow(keyCode: 0x0D, flags: .maskCommand))
        XCTAssertFalse(HotKeyMatcher.isCloseWindow(keyCode: 0x0D, flags: []))
        XCTAssertFalse(HotKeyMatcher.isCloseWindow(keyCode: 0x0C, flags: .maskCommand))
    }

    func testQuitAppRequiresCommandAndQ() {
        XCTAssertTrue(HotKeyMatcher.isQuitApp(keyCode: 0x0C, flags: .maskCommand))
        XCTAssertFalse(HotKeyMatcher.isQuitApp(keyCode: 0x0C, flags: []))
        XCTAssertFalse(HotKeyMatcher.isQuitApp(keyCode: 0x0D, flags: .maskCommand))
    }
}
