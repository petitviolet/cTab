import CoreGraphics

/// スイッチャーのトリガ／操作に使う修飾キー。
enum TriggerModifier: String, CaseIterable, Identifiable {
    case command, option, control

    var id: String { rawValue }

    var flag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .option: return .maskAlternate
        case .control: return .maskControl
        }
    }

    var displayName: String {
        switch self {
        case .command: return "Command (⌘)"
        case .option: return "Option (⌥)"
        case .control: return "Control (⌃)"
        }
    }
}

/// トリガ判定ロジック。CGEventFlags のみに依存し副作用を持たないため単体テスト可能。
///
/// セキュリティ方針: ここでは「設定されたトリガ／操作キーに合致するか」だけを判定する。
/// 合致しないイベントのキーコード等は保持・記録しない（キーロガー化の回避）。
enum HotKeyMatcher {
    /// Tab キーの仮想キーコード（kVK_Tab）。
    static let tabKeyCode: Int64 = 0x30
    /// バッククォート `（kVK_ANSI_Grave）。トリガキーの選択肢。
    static let graveKeyCode: Int64 = 0x32
    /// Escape キーの仮想キーコード（kVK_Escape）。
    static let escapeKeyCode: Int64 = 0x35
    /// Return キーの仮想キーコード（kVK_Return / kVK_ANSI_KeypadEnter）。
    static let returnKeyCode: Int64 = 0x24
    static let keypadEnterKeyCode: Int64 = 0x4C
    /// Delete（Backspace）キーの仮想キーコード（kVK_Delete）。
    static let deleteKeyCode: Int64 = 0x33
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

    /// 設定された修飾キーを押しながらトリガキーを叩いたか。
    static func isSwitchTrigger(keyCode: Int64, flags: CGEventFlags, triggerKeyCode: Int64, modifier: CGEventFlags) -> Bool {
        keyCode == triggerKeyCode && flags.contains(modifier)
    }

    /// 逆方向（Shift 同時押し）か。
    static func isReverse(flags: CGEventFlags) -> Bool {
        flags.contains(.maskShift)
    }

    /// トリガ修飾キーが離されたか（flagsChanged で確定トリガとして使う）。
    static func isModifierReleased(flags: CGEventFlags, modifier: CGEventFlags) -> Bool {
        !flags.contains(modifier)
    }

    /// キャンセル（Escape）か。
    static func isCancel(keyCode: Int64) -> Bool {
        keyCode == escapeKeyCode
    }

    /// 確定（Return / Enter）か。
    static func isConfirm(keyCode: Int64) -> Bool {
        keyCode == returnKeyCode || keyCode == keypadEnterKeyCode
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

    /// 修飾キー+W（選択ウィンドウを閉じる）か。
    static func isCloseWindow(keyCode: Int64, flags: CGEventFlags, modifier: CGEventFlags) -> Bool {
        keyCode == wKeyCode && flags.contains(modifier)
    }

    /// 修飾キー+Q（選択アプリを終了する）か。
    static func isQuitApp(keyCode: Int64, flags: CGEventFlags, modifier: CGEventFlags) -> Bool {
        keyCode == qKeyCode && flags.contains(modifier)
    }

    /// 修飾キー+M（選択ウィンドウを最小化する）か。
    static func isMinimize(keyCode: Int64, flags: CGEventFlags, modifier: CGEventFlags) -> Bool {
        keyCode == mKeyCode && flags.contains(modifier)
    }

    /// 修飾キー+F（選択ウィンドウのフルスクリーンを切り替える）か。
    static func isFullScreen(keyCode: Int64, flags: CGEventFlags, modifier: CGEventFlags) -> Bool {
        keyCode == fKeyCode && flags.contains(modifier)
    }
}
