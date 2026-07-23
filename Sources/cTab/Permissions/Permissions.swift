import AppKit
import ApplicationServices
import CoreGraphics
import IOKit

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

    // MARK: - Secure Keyboard Entry（セキュア入力）

    /// セキュア入力を保持しているプロセスの表示名。保持者がいなければ nil（正常）。
    ///
    /// セキュア入力が有効な間はセッション内の CGEventTap にキーイベントが配送されず、
    /// cTab のトリガが一切反応しなくなる。パスワード入力欄を持つアプリ（Terminal、
    /// ブラウザ等）が保持し、異常終了すると死んだ PID を指したまま残る（stuck）ことがある。
    static func secureInputHolder() -> String? {
        guard let pid = secureInputHolderPID() else { return nil }
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.localizedName ?? "PID \(pid)"
        }
        // NSRunningApplication で引けない = GUI 外プロセスか、既に終了した PID（stuck 状態）。
        return kill(pid, 0) == 0 ? "PID \(pid) のプロセス" : "終了済みプロセス（PID \(pid)）"
    }

    /// IORegistry の IOConsoleUsers から kCGSSessionSecureInputPID を読む。無ければ nil。
    private static func secureInputHolderPID() -> pid_t? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        guard let users = IORegistryEntryCreateCFProperty(
            root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [[String: Any]] else { return nil }
        for user in users {
            if let pid = user["kCGSSessionSecureInputPID"] as? Int, pid > 0 {
                return pid_t(pid)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func open(settings anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
