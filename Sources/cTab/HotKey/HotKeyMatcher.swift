import CoreGraphics

/// Command+Tab トリガの判定ロジック。CGEventFlags のみに依存し副作用を持たないため単体テスト可能。
///
/// セキュリティ方針: ここでは「Command+Tab に合致するか」だけを判定する。
/// 合致しないイベントのキーコード等は保持・記録しない（キーロガー化の回避）。
enum HotKeyMatcher {
    /// Tab キーの仮想キーコード（kVK_Tab）。
    static let tabKeyCode: Int64 = 0x30
    /// Escape キーの仮想キーコード（kVK_Escape）。
    static let escapeKeyCode: Int64 = 0x35
    /// W キーの仮想キーコード（kVK_ANSI_W）。
    static let wKeyCode: Int64 = 0x0D
    /// Q キーの仮想キーコード（kVK_ANSI_Q）。
    static let qKeyCode: Int64 = 0x0C
    /// M キーの仮想キーコード（kVK_ANSI_M）。
    static let mKeyCode: Int64 = 0x2E
    /// F キーの仮想キーコード（kVK_ANSI_F）。
    static let fKeyCode: Int64 = 0x03
    /// 矢印キーの仮想キーコード（kVK_LeftArrow/RightArrow/DownArrow/UpArrow）。
    static let leftArrowKeyCode: Int64 = 0x7B
    static let rightArrowKeyCode: Int64 = 0x7C
    static let downArrowKeyCode: Int64 = 0x7D
    static let upArrowKeyCode: Int64 = 0x7E

    /// Command を押しながら Tab を叩いたか。
    static func isSwitchTrigger(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == tabKeyCode && flags.contains(.maskCommand)
    }

    /// 逆方向（Shift 同時押し）か。
    static func isReverse(flags: CGEventFlags) -> Bool {
        flags.contains(.maskShift)
    }

    /// Command が離されたか（flagsChanged で確定トリガとして使う）。
    static func isCommandReleased(flags: CGEventFlags) -> Bool {
        !flags.contains(.maskCommand)
    }

    /// キャンセル（Escape）か。
    static func isCancel(keyCode: Int64) -> Bool {
        keyCode == escapeKeyCode
    }

    /// 矢印キーに対応する移動方向。矢印以外なら nil。
    static func arrowDirection(keyCode: Int64) -> Direction? {
        switch keyCode {
        case leftArrowKeyCode: return .left
        case rightArrowKeyCode: return .right
        case downArrowKeyCode: return .down
        case upArrowKeyCode: return .up
        default: return nil
        }
    }

    /// Command+W（選択ウィンドウを閉じる）か。
    static func isCloseWindow(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == wKeyCode && flags.contains(.maskCommand)
    }

    /// Command+Q（選択アプリを終了する）か。
    static func isQuitApp(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == qKeyCode && flags.contains(.maskCommand)
    }

    /// Command+M（選択ウィンドウを最小化する）か。
    static func isMinimize(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == mKeyCode && flags.contains(.maskCommand)
    }

    /// Command+F（選択ウィンドウのフルスクリーンを切り替える）か。
    static func isFullScreen(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == fKeyCode && flags.contains(.maskCommand)
    }
}
