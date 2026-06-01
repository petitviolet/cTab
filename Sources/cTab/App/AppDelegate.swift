import AppKit

/// アプリのライフサイクル。権限確認・メニューバー常駐・設定ウィンドウ・スイッチャー起動を配線する。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var switcher: SwitcherController?
    private var statusItem: NSStatusItem?
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        // アプリ起動時は設定ウィンドウを表示する（メニューバーだけでは操作しづらいため）。
        settingsWindow.show()
        startSwitcherIfPossible()
    }

    /// Dock や Finder からの再オープン時にも設定ウィンドウを表示する。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    /// Accessibility 権限があれば EventTap を開始する。無い場合は設定ウィンドウの案内に任せる。
    private func startSwitcherIfPossible() {
        guard Permissions.ensureAccessibility(prompt: true) else {
            Log.permission.error("accessibility permission not granted")
            return
        }
        let switcher = SwitcherController()
        if switcher.start() {
            self.switcher = switcher
            switcher.prewarm()
            Log.general.info("cTab ready")
        } else {
            Log.permission.error("failed to start event tap")
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⌘⇥"

        let menu = NSMenu()
        menu.addItem(withTitle: "設定を開く", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "再起動", action: #selector(restart), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "cTab を終了", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func restart() {
        Relauncher.relaunch()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
