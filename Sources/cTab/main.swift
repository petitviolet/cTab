import AppKit

// README 用スクリーンショット生成モード（オフライン専用・実ウィンドウは列挙しない）。
//   cTab --render-screenshot <出力PNG> <サムネイルディレクトリ>
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--render-screenshot" {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let ok = MainActor.assumeIsolated {
        ScreenshotRenderer.render(
            outputPath: CommandLine.arguments[2],
            thumbnailDirectory: CommandLine.arguments[3]
        )
    }
    exit(ok ? 0 : 1)
}

// エントリポイント。Dock にアイコンを出さない accessory アプリとして起動する。
// 実際のホットキー/UI 配線は AppDelegate に集約する。
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
