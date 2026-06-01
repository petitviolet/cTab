import AppKit
import SwiftUI

/// スイッチャーを表示する非アクティブパネル。
///
/// `.nonactivatingPanel` によりフォアグラウンドアプリのアクティブ状態を奪わないため、
/// ユーザーが押している Command が論理的に保持され、EventTap が後続の Tab / flagsChanged を受け取れる。
final class SwitcherPanel {
    private let model: SwitcherViewModel
    private let onSelect: (WindowInfo) -> Void
    private let onClose: (WindowInfo) -> Void
    private var panel: NSPanel?

    init(
        model: SwitcherViewModel,
        onSelect: @escaping (WindowInfo) -> Void,
        onClose: @escaping (WindowInfo) -> Void
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onClose = onClose
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        layout(panel)
        // key にするとマウスのクリック/ホバーを受け取れる。`.nonactivatingPanel` のため
        // アプリ自体はアクティブ化しない（Command 保持・EventTap はそのまま機能）。
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    /// パネル（SwiftUI ホスティングビュー）を事前生成しておく。画面には出さない。
    /// 初回表示時の SwiftUI ウォームアップによるラグを避けるために使う。
    func prewarm() {
        if panel == nil {
            panel = makePanel()
        }
    }

    func hide() {
        panel?.orderOut(nil)
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
        panel.contentView = NSHostingView(
            rootView: SwitcherView(model: model, onSelect: onSelect, onClose: onClose)
        )
        return panel
    }

    /// グリッドの実寸でパネルをサイズし、対象ディスプレイの中央に配置する。
    private func layout(_ panel: NSPanel) {
        let columns = max(model.columns, 1)
        let rows = max(GridLayout.rowCount(count: model.windows.count, columns: columns), 1)
        let result = GridLayout.Result(columns: columns, rows: rows, cellWidth: model.cellWidth, cellHeight: model.cellHeight)
        let content = GridLayout.contentSize(result, spacing: SwitcherLayout.gridSpacing)

        // present() が決めた対象ディスプレイ（マウスのある画面）の中央へ。未設定なら main。
        let screenFrame = model.screenFrame != .zero ? model.screenFrame : (NSScreen.main?.frame ?? .zero)

        let frame = NSRect(
            x: screenFrame.midX - content.width / 2,
            y: screenFrame.midY - content.height / 2,
            width: content.width,
            height: content.height
        )
        panel.setFrame(frame, display: true)
    }
}
