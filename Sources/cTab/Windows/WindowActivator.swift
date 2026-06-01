import AppKit
import ApplicationServices

/// 選択されたウィンドウへの操作（前面化・クローズ・アプリ終了）。
enum WindowActivator {
    static func activate(_ window: WindowInfo) {
        // 最小化されていれば先に復元する（復元前に raise しても効かないため順序が重要）。
        if window.isMinimized {
            let err = AXUIElementSetAttributeValue(window.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            if err != .success {
                Log.windows.error("failed to unminimize window: \(err.rawValue, privacy: .public)")
            }
        }

        // 対象ウィンドウをメインウィンドウに指定し、最前面化する。
        AXUIElementSetAttributeValue(window.axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        let raiseErr = AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)
        if raiseErr != .success {
            Log.windows.error("failed to raise window: \(raiseErr.rawValue, privacy: .public)")
        }

        // アプリ自体をアクティブ化（フォーカスを移す）。
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate()
        }

        Log.windows.info("activated window of pid \(window.pid, privacy: .public)")
    }

    /// ウィンドウを閉じる（クローズボタンを押下する）。閉じる操作を実行できたら true。
    @discardableResult
    static func close(_ window: WindowInfo) -> Bool {
        var button: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(window.axElement, kAXCloseButtonAttribute as CFString, &button)
        guard err == .success, let button, CFGetTypeID(button) == AXUIElementGetTypeID() else {
            Log.windows.error("close button not found: \(err.rawValue, privacy: .public)")
            return false
        }
        let closeButton = button as! AXUIElement
        let pressErr = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        if pressErr != .success {
            Log.windows.error("failed to press close button: \(pressErr.rawValue, privacy: .public)")
            return false
        }
        return true
    }

    /// ウィンドウのアプリを終了する（graceful）。終了要求を送れたら true。
    @discardableResult
    static func quit(_ window: WindowInfo) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return false }
        let requested = app.terminate()
        Log.windows.info("requested quit for pid \(window.pid, privacy: .public)")
        return requested
    }
}
