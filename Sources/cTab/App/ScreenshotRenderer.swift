import AppKit
import SwiftUI

/// README 用スクリーンショットを実際の `SwitcherView` から描画するオフライン専用ユーティリティ。
///
/// 実行中のウィンドウは列挙せず、codex で生成した架空のサムネイル画像と実アプリアイコンを
/// 差し込んだ疑似 `WindowInfo` を並べて描画するため、利用者の実際の画面内容は一切写らない。
/// `cTab --render-screenshot <出力PNG> <サムネイルディレクトリ>` から呼ばれる。
enum ScreenshotRenderer {
    /// 1 セル分の疑似ウィンドウ定義。
    private struct FakeWindow {
        let appName: String
        let title: String
        /// アプリアイコンを引くための bundle id 候補（先に見つかったものを使う）。
        let bundleIDs: [String]
        /// サムネイル画像ファイル名（サムネイルディレクトリからの相対）。
        let thumbnailFile: String
    }

    private static let fakeWindows: [FakeWindow] = [
        FakeWindow(appName: "Safari", title: "Mountain Travel Journal",
                   bundleIDs: ["com.apple.Safari"], thumbnailFile: "ctab_thumb_1.png"),
        FakeWindow(appName: "Code", title: "SwitcherView.swift",
                   bundleIDs: ["com.microsoft.VSCode", "com.apple.dt.Xcode"], thumbnailFile: "ctab_thumb_2.png"),
        FakeWindow(appName: "Terminal", title: "~/projects — zsh",
                   bundleIDs: ["com.apple.Terminal", "com.googlecode.iterm2"], thumbnailFile: "ctab_thumb_3.png"),
        FakeWindow(appName: "Calendar", title: "July 2026",
                   bundleIDs: ["com.apple.iCal"], thumbnailFile: "ctab_thumb_4.png"),
        FakeWindow(appName: "Music", title: "Now Playing",
                   bundleIDs: ["com.apple.Music"], thumbnailFile: "ctab_thumb_5.png"),
        FakeWindow(appName: "Notes", title: "Ideas",
                   bundleIDs: ["com.apple.Notes"], thumbnailFile: "ctab_thumb_6.png"),
    ]

    /// 選択状態にするセルの index。
    private static let selectedIndex = 1

    /// エントリポイント。成功時は true、失敗時は false（呼び出し側で終了コードにする）。
    @MainActor
    static func render(outputPath: String, thumbnailDirectory: String) -> Bool {
        // README 向けに見栄えの良い外観へ固定（実利用の設定は上書きしない一時プロセスなので副作用は無い）。
        AppSettings.appearanceRaw = "dark"
        AppSettings.accentColorRaw = "purple"
        AppSettings.panelOpacity = 1.0

        let thumbDir = URL(fileURLWithPath: thumbnailDirectory, isDirectory: true)
        let windows = fakeWindows.enumerated().map { index, fake in
            makeWindowInfo(fake, id: CGWindowID(1000 + index), thumbnailDirectory: thumbDir)
        }

        let model = SwitcherViewModel()
        model.update(windows: windows, selectedIndex: selectedIndex)

        // 3 列 2 行に収まるレイアウトを算出。
        let scale: CGFloat = 1.0
        let spacing = SwitcherLayout.gridSpacing(scale)
        let labelHeight = SwitcherLayout.labelHeight(scale)
        let maxCellWidth = SwitcherLayout.maxCellWidth(scale)
        // 3 列に確実に収まる十分広い作業領域を与える（solve は領域内で最大セルを選ぶ）。
        let available = CGSize(width: 980, height: 640)
        let grid = GridLayout.solve(
            count: windows.count,
            available: available,
            spacing: spacing,
            labelHeight: labelHeight,
            thumbnailAspect: SwitcherLayout.thumbnailAspect,
            maxCellWidth: maxCellWidth
        )
        let layout = ScreenLayout(
            screenFrame: .zero,
            columns: grid.columns,
            rows: grid.rows,
            cellWidth: grid.cellWidth,
            cellHeight: grid.cellHeight,
            scale: scale
        )
        let panelSize = GridLayout.contentSize(grid, spacing: spacing)

        let margin: CGFloat = 90
        let canvasSize = CGSize(width: panelSize.width + margin * 2,
                                height: panelSize.height + margin * 2)

        let scene = ZStack {
            wallpaper
            SwitcherView(model: model, layout: layout, onSelect: { _ in }, onClose: { _ in }, onHover: { _ in })
                .frame(width: panelSize.width, height: panelSize.height)
                .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 2.0
        renderer.isOpaque = true

        guard let cgImage = renderer.cgImage else {
            FileHandle.standardError.write(Data("ImageRenderer が画像を生成できませんでした\n".utf8))
            return false
        }
        return writePNG(cgImage, to: outputPath)
    }

    /// フロスト（すりガラス）パネルが映えるカラフルなグラデーション壁紙。
    private static var wallpaper: some View {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.20, blue: 0.62),
                Color(red: 0.55, green: 0.30, blue: 0.78),
                Color(red: 0.29, green: 0.42, blue: 0.82),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 疑似 `WindowInfo` を組み立てる。thumbnail は codex 生成画像、appIcon は実アプリのアイコン。
    @MainActor
    private static func makeWindowInfo(_ fake: FakeWindow, id: CGWindowID, thumbnailDirectory: URL) -> WindowInfo {
        let thumbnail = loadCGImage(thumbnailDirectory.appendingPathComponent(fake.thumbnailFile))
        return WindowInfo(
            id: id,
            pid: 0,
            appName: fake.appName,
            bundleID: fake.bundleIDs.first,
            title: fake.title,
            appIcon: appIcon(for: fake.bundleIDs),
            // 描画専用でクリック操作はしないため、自プロセスの AX 参照をダミーとして持たせる。
            axElement: AXUIElementCreateApplication(getpid()),
            screenFrame: .zero,
            isOnOtherSpace: false,
            isMinimized: false,
            thumbnail: thumbnail
        )
    }

    /// bundle id 候補の先頭から順にインストール済みアプリのアイコンを探す。無ければ nil。
    private static func appIcon(for bundleIDs: [String]) -> NSImage? {
        for bundleID in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
    }

    private static func loadCGImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func writePNG(_ image: CGImage, to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }
}
