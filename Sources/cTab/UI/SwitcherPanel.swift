import AppKit
import SwiftUI

/// スイッチャーを表示する非アクティブパネル群。ディスプレイごとに 1 枚ずつ生成し、状態は共有する。
///
/// `.nonactivatingPanel` によりフォアグラウンドアプリのアクティブ状態を奪わないため、
/// ユーザーが押している Command が論理的に保持され、EventTap が後続の Tab / flagsChanged を受け取れる。
final class SwitcherPanel {
    private let model: SwitcherViewModel
    private let onSelect: (WindowInfo) -> Void
    private let onClose: (WindowInfo) -> Void
    private var panels: [NSPanel] = []

    init(
        model: SwitcherViewModel,
        onSelect: @escaping (WindowInfo) -> Void,
        onClose: @escaping (WindowInfo) -> Void
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onClose = onClose
    }

    /// 各ディスプレイのレイアウトに合わせてパネルを表示する（要素数だけパネルを用意）。
    func show(layouts: [ScreenLayout]) {
        guard !layouts.isEmpty else { hide(); return }

        // パネル枚数をディスプレイ数に合わせる。
        while panels.count < layouts.count { panels.append(makePanel()) }
        while panels.count > layouts.count { panels.removeLast().orderOut(nil) }

        for (index, layout) in layouts.enumerated() {
            let panel = panels[index]
            panel.contentView = NSHostingView(
                rootView: SwitcherView(model: model, layout: layout, onSelect: onSelect, onClose: onClose)
            )
            let content = contentSize(for: layout)
            let frame = NSRect(
                x: layout.screenFrame.midX - content.width / 2,
                y: layout.screenFrame.midY - content.height / 2,
                width: content.width,
                height: content.height
            )
            panel.setFrame(frame, display: true)
        }

        // 先頭（最前面ウィンドウのある画面）を key にしてマウス操作を受け取りやすくする。
        for (index, panel) in panels.enumerated() {
            if index == 0 { panel.makeKeyAndOrderFront(nil) }
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
    }

    /// 初回表示を速くするため、パネル（SwiftUI ホスティングビュー）を 1 枚事前生成しておく。
    func prewarm() {
        guard panels.isEmpty else { return }
        let panel = makePanel()
        let dummy = ScreenLayout(screenFrame: .zero, columns: 1, rows: 0, cellWidth: 200, cellHeight: 160, scale: 1)
        panel.contentView = NSHostingView(
            rootView: SwitcherView(model: model, layout: dummy, onSelect: onSelect, onClose: onClose)
        )
        panels.append(panel)
    }

    private func contentSize(for layout: ScreenLayout) -> CGSize {
        let result = GridLayout.Result(
            columns: layout.columns, rows: layout.rows,
            cellWidth: layout.cellWidth, cellHeight: layout.cellHeight
        )
        return GridLayout.contentSize(result, spacing: SwitcherLayout.gridSpacing(layout.scale))
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        // マウスのホバー（onHover）を受け取るために mouseMoved イベントを有効化する。
        panel.acceptsMouseMovedEvents = true
        return panel
    }
}
