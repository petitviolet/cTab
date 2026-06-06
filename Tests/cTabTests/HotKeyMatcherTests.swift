import XCTest
import CoreGraphics
@testable import cTab

final class HotKeyMatcherTests: XCTestCase {
    private let cmd: CGEventFlags = .maskCommand

    func testSwitchTriggerRequiresModifierAndTriggerKey() {
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: .maskCommand, triggerKeyCode: 0x30, modifier: cmd))
        // 修飾なしの Tab は対象外
        XCTAssertFalse(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: [], triggerKeyCode: 0x30, modifier: cmd))
        // 修飾付きでも別キーは対象外
        XCTAssertFalse(HotKeyMatcher.isSwitchTrigger(keyCode: 0x00, flags: .maskCommand, triggerKeyCode: 0x30, modifier: cmd))
    }

    func testSwitchTriggerWithCustomModifierAndKey() {
        // Option + ` をトリガにした場合
        let opt: CGEventFlags = .maskAlternate
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x32, flags: .maskAlternate, triggerKeyCode: 0x32, modifier: opt))
        // Command 押下では発火しない
        XCTAssertFalse(HotKeyMatcher.isSwitchTrigger(keyCode: 0x32, flags: .maskCommand, triggerKeyCode: 0x32, modifier: opt))
    }

    func testReverseDetectsShift() {
        XCTAssertTrue(HotKeyMatcher.isReverse(flags: [.maskCommand, .maskShift]))
        XCTAssertFalse(HotKeyMatcher.isReverse(flags: [.maskCommand]))
    }

    func testModifierReleased() {
        XCTAssertTrue(HotKeyMatcher.isModifierReleased(flags: [], modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isModifierReleased(flags: [.maskCommand], modifier: cmd))
    }

    func testReverseSwitchTriggerIsStillSwitchTrigger() {
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: [.maskCommand, .maskShift], triggerKeyCode: 0x30, modifier: cmd))
    }

    func testSwitchTriggerToleratesExtraModifiers() {
        XCTAssertTrue(HotKeyMatcher.isSwitchTrigger(keyCode: 0x30, flags: [.maskCommand, .maskAlternate], triggerKeyCode: 0x30, modifier: cmd))
    }

    func testModifierReleasedWhenOnlyShiftRemains() {
        XCTAssertTrue(HotKeyMatcher.isModifierReleased(flags: [.maskShift], modifier: cmd))
    }

    func testIsCancelDetectsEscape() {
        XCTAssertTrue(HotKeyMatcher.isCancel(keyCode: 0x35))
        XCTAssertFalse(HotKeyMatcher.isCancel(keyCode: 0x30))
    }

    func testIsConfirmDetectsReturnAndEnter() {
        XCTAssertTrue(HotKeyMatcher.isConfirm(keyCode: 0x24))
        XCTAssertTrue(HotKeyMatcher.isConfirm(keyCode: 0x4C))
        XCTAssertFalse(HotKeyMatcher.isConfirm(keyCode: 0x30))
    }

    func testArrowDirectionMapping() {
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7B), .left)
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7C), .right)
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7D), .down)
        XCTAssertEqual(HotKeyMatcher.arrowDirection(keyCode: 0x7E), .up)
        XCTAssertNil(HotKeyMatcher.arrowDirection(keyCode: 0x30))
    }

    func testCloseWindowRequiresModifierAndW() {
        XCTAssertTrue(HotKeyMatcher.isCloseWindow(keyCode: 0x0D, flags: .maskCommand, modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isCloseWindow(keyCode: 0x0D, flags: [], modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isCloseWindow(keyCode: 0x0C, flags: .maskCommand, modifier: cmd))
    }

    func testQuitAppRequiresModifierAndQ() {
        XCTAssertTrue(HotKeyMatcher.isQuitApp(keyCode: 0x0C, flags: .maskCommand, modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isQuitApp(keyCode: 0x0C, flags: [], modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isQuitApp(keyCode: 0x0D, flags: .maskCommand, modifier: cmd))
    }

    func testMinimizeRequiresModifierAndM() {
        XCTAssertTrue(HotKeyMatcher.isMinimize(keyCode: 0x2E, flags: .maskCommand, modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isMinimize(keyCode: 0x2E, flags: [], modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isMinimize(keyCode: 0x0D, flags: .maskCommand, modifier: cmd))
    }

    func testFullScreenRequiresModifierAndF() {
        XCTAssertTrue(HotKeyMatcher.isFullScreen(keyCode: 0x03, flags: .maskCommand, modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isFullScreen(keyCode: 0x03, flags: [], modifier: cmd))
        XCTAssertFalse(HotKeyMatcher.isFullScreen(keyCode: 0x2E, flags: .maskCommand, modifier: cmd))
    }

    func testTriggerModifierFlags() {
        XCTAssertEqual(TriggerModifier.command.flag, .maskCommand)
        XCTAssertEqual(TriggerModifier.option.flag, .maskAlternate)
        XCTAssertEqual(TriggerModifier.control.flag, .maskControl)
    }
}
