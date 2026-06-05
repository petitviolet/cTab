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
    /// panels と並行する各パネルの配置先ディスプレイ frame（active 切替の検索用）。
    private var panelScreenFrames: [CGRect] = []

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
    /// `activeScreenFrame` のディスプレイのパネルを key にして、その画面でマウス操作を効かせる。
    func show(layouts: [ScreenLayout], activeScreenFrame: CGRect) {
        guard !layouts.isEmpty else { hide(); return }

        // パネル枚数をディスプレイ数に合わせる。
        while panels.count < layouts.count { panels.append(makePanel()) }
        while panels.count > layouts.count { panels.removeLast().orderOut(nil) }

        for (index, layout) in layouts.enumerated() {
            let panel = panels[index]
            setRootView(of: panel, layout: layout)
            let content = contentSize(for: layout)
            let frame = NSRect(
                x: layout.screenFrame.midX - content.width / 2,
                y: layout.screenFrame.midY - content.height / 2,
                width: content.width,
                height: content.height
            )
            panel.setFrame(frame, display: true)
        }
        panelScreenFrames = layouts.map(\.screenFrame)

        // アクティブ画面のパネルを key に（無ければ先頭）。残りは表示のみ。
        let activeIndex = panelScreenFrames.firstIndex(of: activeScreenFrame) ?? 0
        for (index, panel) in panels.enumerated() {
            if index == activeIndex { panel.makeKeyAndOrderFront(nil) }
            panel.orderFrontRegardless()
        }
    }

    /// 表示中に、指定ディスプレイのパネルを key へ切り替える（マウス追従用）。
    func makeActive(screenFrame: CGRect) {
        guard let index = panelScreenFrames.firstIndex(of: screenFrame) else { return }
        panels[index].makeKeyAndOrderFront(nil)
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
    }

    /// 初回表示を速くするため、パネル（SwiftUI ホスティングビュー）を 1 枚事前生成しておく。
    /// dummy レイアウトは表示時に必ず上書きされるプレースホルダ。
    func prewarm() {
        guard panels.isEmpty else { return }
        let panel = makePanel()
        let dummy = ScreenLayout(screenFrame: .zero, columns: 1, rows: 0, cellWidth: 200, cellHeight: 160, scale: 1)
        setRootView(of: panel, layout: dummy)
        panels.append(panel)
    }

    /// パネルの SwiftUI 中身を設定する。既存の NSHostingView があれば rootView 差し替えで再利用する。
    private func setRootView(of panel: NSPanel, layout: ScreenLayout) {
        let root = SwitcherView(model: model, layout: layout, onSelect: onSelect, onClose: onClose)
        if let hosting = panel.contentView as? NSHostingView<SwitcherView> {
            hosting.rootView = root
        } else {
            panel.contentView = NSHostingView(rootView: root)
        }
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
