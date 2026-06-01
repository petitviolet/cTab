import AppKit
import ApplicationServices
import CoreGraphics

/// TCC 権限の確認・要求・設定画面誘導。
///
/// 本アプリが必要とする権限:
/// - Accessibility: CGEventTap によるキー傍受と、AXUIElement によるウィンドウ操作の双方に必須。
/// - Screen Recording: ウィンドウサムネイル取得（ScreenCaptureKit）に必要。未付与でもアイコン表示で縮退動作する。
enum Permissions {
    // MARK: - Accessibility

    static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    /// Accessibility 権限を確認する。`prompt` が true なら未付与時にシステムダイアログを表示する。
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        open(settings: "Privacy_Accessibility")
    }

    // MARK: - Screen Recording

    static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Screen Recording 権限を要求する（初回はシステムダイアログ）。
    @discardableResult
    static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        open(settings: "Privacy_ScreenCapture")
    }

    // MARK: - Helpers

    private static func open(settings anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
