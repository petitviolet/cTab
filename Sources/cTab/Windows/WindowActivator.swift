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

    /// ウィンドウを最小化する。実行できたら true。
    @discardableResult
    static func minimize(_ window: WindowInfo) -> Bool {
        let err = AXUIElementSetAttributeValue(window.axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        if err != .success {
            Log.windows.error("failed to minimize window: \(err.rawValue, privacy: .public)")
            return false
        }
        return true
    }

    /// ウィンドウのフルスクリーン状態を切り替える。切り替えられたら true。
    /// 非公開の kAXFullScreenAttribute を優先し、無ければフルスクリーンボタンの押下にフォールバックする。
    @discardableResult
    static func toggleFullScreen(_ window: WindowInfo) -> Bool {
        let attribute = "AXFullScreen" as CFString
        var current: CFTypeRef?
        if AXUIElementCopyAttributeValue(window.axElement, attribute, &current) == .success,
           let isFull = current as? Bool {
            let next: CFTypeRef = isFull ? kCFBooleanFalse : kCFBooleanTrue
            let err = AXUIElementSetAttributeValue(window.axElement, attribute, next)
            if err == .success { return true }
            Log.windows.error("failed to set fullscreen: \(err.rawValue, privacy: .public)")
        }

        // フォールバック: フルスクリーンボタン（緑ボタン）を押下する。
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window.axElement, "AXFullScreenButton" as CFString, &button) == .success,
              let button, CFGetTypeID(button) == AXUIElementGetTypeID() else {
            return false
        }
        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }
}
