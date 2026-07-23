import AppKit
import SwiftUI

/// 設定ウィンドウ（通常の NSWindow）の生成・表示を管理する。
///
/// アクセサリアプリ（Dock 非表示）のままでも、`NSApp.activate()` + `makeKeyAndOrderFront`
/// でウィンドウを前面に出して操作できる。閉じてもアプリは常駐し続ける。
final class SettingsWindowController {
    private let model = SettingsModel()
    private var window: NSWindow?

    func show() {
        model.refresh()

        let window = window ?? makeWindow()
        self.window = window

        // accessory アプリでは起動直後に最前面プロセスでないことがあるため、
        // activate に加えて orderFrontRegardless で確実に前面へ出す。
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        let window = EscClosableWindow(contentViewController: hosting)
        window.title = "cTab 設定"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

/// Esc キーで閉じられるウィンドウ。
/// Esc はどのビューにも処理されなければレスポンダチェーン経由で
/// `cancelOperation` としてウィンドウに届くため、ここで閉じる。
private final class EscClosableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
