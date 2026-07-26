import CoreGraphics
import XCTest
@testable import cTab

final class AppHotKeyResolverTests: XCTestCase {
    private let bindings: [Int: String] = [
        0x01: "com.example.editor",  // S
        0x11: "com.example.terminal",  // T
    ]

    // MARK: - bundleID(keyCode:flags:modifier:bindings:)

    func testBoundKeyWithModifierResolves() {
        let bundleID = AppHotKeyResolver.bundleID(
            keyCode: 0x01, flags: .maskCommand, modifier: .maskCommand, bindings: bindings
        )
        XCTAssertEqual(bundleID, "com.example.editor")
    }

    func testWithoutModifierDoesNotResolve() {
        let bundleID = AppHotKeyResolver.bundleID(
            keyCode: 0x01, flags: [], modifier: .maskCommand, bindings: bindings
        )
        XCTAssertNil(bundleID)
    }

    func testUnboundKeyDoesNotResolve() {
        let bundleID = AppHotKeyResolver.bundleID(
            keyCode: 0x02, flags: .maskCommand, modifier: .maskCommand, bindings: bindings
        )
        XCTAssertNil(bundleID)
    }

    func testEmptyBindingsDoesNotResolve() {
        let bundleID = AppHotKeyResolver.bundleID(
            keyCode: 0x01, flags: .maskCommand, modifier: .maskCommand, bindings: [:]
        )
        XCTAssertNil(bundleID)
    }

    func testOtherModifierConfigurationsResolve() {
        // Option をトリガ修飾キーに設定している場合は Option 押下で発動する。
        let bundleID = AppHotKeyResolver.bundleID(
            keyCode: 0x11, flags: [.maskAlternate, .maskShift], modifier: .maskAlternate, bindings: bindings
        )
        XCTAssertEqual(bundleID, "com.example.terminal")
    }

    // MARK: - firstIndex(of:in:)

    func testFirstIndexPicksFrontmostMatch() {
        let ids: [String?] = ["com.a", "com.example.editor", nil, "com.example.editor"]
        XCTAssertEqual(AppHotKeyResolver.firstIndex(of: "com.example.editor", in: ids), 1)
    }

    func testFirstIndexReturnsNilWhenAbsent() {
        let ids: [String?] = ["com.a", nil]
        XCTAssertNil(AppHotKeyResolver.firstIndex(of: "com.example.editor", in: ids))
    }

    // MARK: - reservedKeyCodes

    func testReservedKeyCodesContainSwitcherControls() {
        let reserved = AppHotKeyResolver.reservedKeyCodes(triggerKeyCode: HotKeyMatcher.tabKeyCode)
        for keyCode in [
            HotKeyMatcher.tabKeyCode, HotKeyMatcher.graveKeyCode, HotKeyMatcher.escapeKeyCode,
            HotKeyMatcher.returnKeyCode, HotKeyMatcher.keypadEnterKeyCode, HotKeyMatcher.deleteKeyCode,
            HotKeyMatcher.wKeyCode, HotKeyMatcher.qKeyCode, HotKeyMatcher.mKeyCode, HotKeyMatcher.fKeyCode,
            HotKeyMatcher.leftArrowKeyCode, HotKeyMatcher.rightArrowKeyCode,
            HotKeyMatcher.downArrowKeyCode, HotKeyMatcher.upArrowKeyCode,
        ] {
            XCTAssertTrue(reserved.contains(keyCode), "keyCode \(keyCode) should be reserved")
        }
    }

    func testReservedKeyCodesIncludeCustomTrigger() {
        let custom: Int64 = 0x26  // J
        XCTAssertTrue(AppHotKeyResolver.reservedKeyCodes(triggerKeyCode: custom).contains(custom))
    }

    // MARK: - AppSettings.parseAppHotKeys（永続化の検証）

    func testParseAppHotKeysAcceptsValidEntries() {
        let raw: [String: Any] = ["1": "com.example.editor", "17": "com.example.terminal"]
        XCTAssertEqual(AppSettings.parseAppHotKeys(raw), [1: "com.example.editor", 17: "com.example.terminal"])
    }

    func testParseAppHotKeysRejectsInvalidEntries() {
        let raw: [String: Any] = [
            "abc": "com.example.editor",  // 数値でないキー
            "-1": "com.example.editor",   // 負のキーコード
            "2": "",                       // 空の bundle id
            "3": 42,                       // 文字列でない値
            "4": "com.example.ok",
        ]
        XCTAssertEqual(AppSettings.parseAppHotKeys(raw), [4: "com.example.ok"])
    }

    func testParseAppHotKeysRejectsReservedKeyCodes() {
        // 予約キー（Tab / Escape / W など）への紐づけは外部書き換え等で入っても読み込み時に捨てる。
        let raw: [String: Any] = [
            String(HotKeyMatcher.tabKeyCode): "com.example.a",
            String(HotKeyMatcher.escapeKeyCode): "com.example.b",
            String(HotKeyMatcher.wKeyCode): "com.example.c",
            "4": "com.example.ok",
        ]
        XCTAssertEqual(AppSettings.parseAppHotKeys(raw), [4: "com.example.ok"])
    }
}
