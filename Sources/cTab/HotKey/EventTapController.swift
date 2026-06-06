import AppKit
import CoreGraphics

/// EventTap が検知したキー操作を受け取るデリゲート。
protocol EventTapControllerDelegate: AnyObject {
    /// トリガ（修飾キー+トリガキー）が押された。`reverse` は Shift 同時押し（逆順）。
    /// 戻り値 true でイベントを消費し、macOS 標準スイッチャーを抑制する。
    func handleSwitchKey(reverse: Bool) -> Bool
    /// トリガ修飾キーが離された（ホールドモードの確定トリガ）。
    func handleTriggerReleased()
    /// Escape が押された。戻り値 true で消費。
    func handleEscape() -> Bool
    /// Return / Enter が押された（トグルモードの確定）。戻り値 true で消費。
    func handleConfirm() -> Bool
    /// インクリメンタル検索に文字が入力された。戻り値 true で消費。
    func handleSearchInput(_ text: String) -> Bool
    /// 検索クエリの末尾を削除する（Backspace）。戻り値 true で消費。
    func handleSearchBackspace() -> Bool
    /// 方向キーで選択を移動する。戻り値 true で消費。
    func handleArrow(_ direction: Direction) -> Bool
    /// 選択中ウィンドウを閉じる（Command+W）。戻り値 true で消費。
    func handleCloseSelectedWindow() -> Bool
    /// 選択中ウィンドウのアプリを終了する（Command+Q）。戻り値 true で消費。
    func handleQuitSelectedApp() -> Bool
    /// 選択中ウィンドウを最小化する（Command+M）。戻り値 true で消費。
    func handleMinimizeSelectedWindow() -> Bool
    /// 選択中ウィンドウのフルスクリーンを切り替える（Command+F）。戻り値 true で消費。
    func handleToggleFullScreen() -> Bool
    /// スイッチャーが表示中か。イベント消費要否の判断に使う。
    var isSwitcherActive: Bool { get }
}

/// CGEventTap を作成し、Command+Tab 関連のキーのみを処理する。
///
/// セキュリティ方針: 監視対象は keyDown / flagsChanged に限定し、Command+Tab・Escape 以外の
/// キーは内容を読まず素通し（pass-through）する。キー内容の保持・記録は行わない。
final class EventTapController {
    weak var delegate: EventTapControllerDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// イベントタップを作成して有効化する。Accessibility 権限が無いと失敗し false を返す。
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: selfPtr
        ) else {
            Log.hotkey.error("failed to create event tap (accessibility permission missing?)")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkey.info("event tap started")
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func reenable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkey.info("event tap re-enabled")
    }

    /// 非キャプチャクロージャなので C 関数ポインタへ変換できる。refcon から self を復元する。
    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>.fromOpaque(refcon).takeUnretainedValue()
        return controller.process(type: type, event: event)
    }

    /// consumed なら nil（イベント破棄）、そうでなければそのまま素通し。
    private func passthrough(_ event: CGEvent, consumed: Bool) -> Unmanaged<CGEvent>? {
        consumed ? nil : Unmanaged.passUnretained(event)
    }

    /// キーイベントから表示可能な文字列を取り出す。制御文字（Tab/Return/Escape 等）は nil。
    /// セキュリティ方針: スイッチャー表示中の検索にのみ使い、保持・記録はしない。
    private func printableString(from event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length)
        guard text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else { return nil }
        return text
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // タップ無効化からの自動復帰。コールバックが重いと OS にタイムアウト無効化されるため必須。
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reenable()
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags

        // トリガ設定（修飾キー・トリガキー）を毎回読む（設定変更が即時反映される）。
        let modifier = AppSettings.triggerModifier.flag
        let triggerKey = Int64(AppSettings.triggerKeyCode)

        switch type {
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if HotKeyMatcher.isSwitchTrigger(keyCode: keyCode, flags: flags, triggerKeyCode: triggerKey, modifier: modifier) {
                let consumed = delegate?.handleSwitchKey(reverse: HotKeyMatcher.isReverse(flags: flags)) ?? false
                return passthrough(event, consumed: consumed)
            }

            // 以下はスイッチャー表示中のみ消費する（非表示時はすべて素通し）。
            if delegate?.isSwitcherActive == true {
                if HotKeyMatcher.isCloseWindow(keyCode: keyCode, flags: flags, modifier: modifier) {
                    return passthrough(event, consumed: delegate?.handleCloseSelectedWindow() ?? false)
                }
                if HotKeyMatcher.isQuitApp(keyCode: keyCode, flags: flags, modifier: modifier) {
                    return passthrough(event, consumed: delegate?.handleQuitSelectedApp() ?? false)
                }
                if HotKeyMatcher.isMinimize(keyCode: keyCode, flags: flags, modifier: modifier) {
                    return passthrough(event, consumed: delegate?.handleMinimizeSelectedWindow() ?? false)
                }
                if HotKeyMatcher.isFullScreen(keyCode: keyCode, flags: flags, modifier: modifier) {
                    return passthrough(event, consumed: delegate?.handleToggleFullScreen() ?? false)
                }
                if let direction = HotKeyMatcher.arrowDirection(keyCode: keyCode) {
                    return passthrough(event, consumed: delegate?.handleArrow(direction) ?? false)
                }
                if HotKeyMatcher.isCancel(keyCode: keyCode) {
                    return passthrough(event, consumed: delegate?.handleEscape() ?? false)
                }
                if HotKeyMatcher.isConfirm(keyCode: keyCode) {
                    return passthrough(event, consumed: delegate?.handleConfirm() ?? false)
                }
                // トグルモードで修飾キーを離した後、トリガキー単独でも選択を進める（Shift で逆順）。
                if keyCode == triggerKey {
                    return passthrough(event, consumed: delegate?.handleSwitchKey(reverse: HotKeyMatcher.isReverse(flags: flags)) ?? false)
                }
                // Backspace は検索クエリを 1 文字削除する。
                if keyCode == HotKeyMatcher.deleteKeyCode {
                    return passthrough(event, consumed: delegate?.handleSearchBackspace() ?? false)
                }
                // 表示可能な文字はインクリメンタル検索へ送る（スイッチャー表示中のみ・ローカル処理のみ）。
                if let text = printableString(from: event) {
                    return passthrough(event, consumed: delegate?.handleSearchInput(text) ?? false)
                }
            }

            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            if HotKeyMatcher.isModifierReleased(flags: flags, modifier: modifier), delegate?.isSwitcherActive == true {
                delegate?.handleTriggerReleased()
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
