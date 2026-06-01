import AppKit

// エントリポイント。Dock にアイコンを出さない accessory アプリとして起動する。
// 実際のホットキー/UI 配線は AppDelegate に集約する。
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
