import AppKit

/// EventTap・ウィンドウ列挙・パネル表示・前面化を束ねるオーケストレーター。
///
/// すべてのコールバックはメイン RunLoop（メインスレッド）上で呼ばれる前提。
final class SwitcherController: EventTapControllerDelegate {
    private let model = SwitcherViewModel()
    private lazy var panel = SwitcherPanel(
        model: model,
        onSelect: { [weak self] window in self?.selectWithMouse(window) },
        onClose: { [weak self] window in self?.closeWithMouse(window) }
    )
    private let eventTap = EventTapController()
    private let thumbnailCache = ThumbnailCache()
    private var thumbnailTask: Task<Void, Never>?
    private var didRequestScreenRecording = false
    private var currentColumns = 1

    private(set) var isSwitcherActive = false

    /// EventTap を開始する。Accessibility 権限が無いと false。
    func start() -> Bool {
        eventTap.delegate = self
        return eventTap.start()
    }

    /// 初回 Command+Tab を速くするため、起動後にパネル(SwiftUI)と AX 接続を事前に温める。
    /// ホットパスを塞がないようメインスレッドの次サイクルで実行する。
    func prewarm() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panel.prewarm()
            _ = WindowEnumerator.enumerate()
        }
    }

    // MARK: - EventTapControllerDelegate

    func handleSwitchKey(reverse: Bool) -> Bool {
        if isSwitcherActive {
            advance(reverse: reverse)
        } else {
            open(reverse: reverse)
        }
        return true
    }

    func handleCommandReleased() {
        guard isSwitcherActive else { return }
        commit()
    }

    func handleEscape() -> Bool {
        guard isSwitcherActive else { return false }
        close()
        return true
    }

    func handleArrow(_ direction: Direction) -> Bool {
        guard isSwitcherActive else { return false }
        let count = model.windows.count
        guard count > 0 else { return true }
        model.selectedIndex = Navigation.move(
            current: model.selectedIndex,
            count: count,
            columns: currentColumns,
            direction: direction
        )
        return true
    }

    func handleCloseSelectedWindow() -> Bool {
        guard isSwitcherActive, let target = selectedWindow() else { return true }
        if WindowActivator.close(target) {
            refresh(with: model.windows.filter { $0.id != target.id })
        }
        return true
    }

    func handleQuitSelectedApp() -> Bool {
        guard isSwitcherActive, let target = selectedWindow() else { return true }
        if WindowActivator.quit(target) {
            refresh(with: model.windows.filter { $0.pid != target.pid })
        }
        return true
    }

    // MARK: - マウス操作

    /// セルをクリックしたとき：そのウィンドウへ切り替えてスイッチャーを閉じる。
    private func selectWithMouse(_ window: WindowInfo) {
        guard isSwitcherActive else { return }
        WindowActivator.activate(window)
        close()
    }

    /// セルの閉じるボタンを押したとき：そのウィンドウを閉じ、一覧を更新する（切り替えはしない）。
    private func closeWithMouse(_ window: WindowInfo) {
        guard isSwitcherActive else { return }
        if WindowActivator.close(window) {
            refresh(with: model.windows.filter { $0.id != window.id })
        }
    }

    // MARK: - Private

    private func open(reverse: Bool) {
        var windows = WindowEnumerator.enumerate()
        guard !windows.isEmpty else { return }

        // 現存ウィンドウだけキャッシュを残し、取得済みサムネイルを即時反映する。
        thumbnailCache.prune(keeping: Set(windows.map(\.id)))
        for index in windows.indices {
            windows[index].thumbnail = thumbnailCache.image(for: windows[index].id)
        }

        let initialIndex = reverse
            ? Navigation.previousIndex(current: 0, count: windows.count)
            : Navigation.initialIndex(count: windows.count)

        present(windows, selectedIndex: initialIndex)
        // 裏で最新サムネイルを取得し、キャッシュと表示を更新する。
        startThumbnailCapture(for: windows)
    }

    /// ウィンドウ一覧をグリッド計算してパネルを表示する。
    /// close/quit 後の再表示にも使う（既存のサムネイルを保持したまま再レイアウトする）。
    private func present(_ windows: [WindowInfo], selectedIndex: Int) {
        let screen = targetScreen()
        let screenFrame = screen?.frame ?? .zero
        let visible = screen?.visibleFrame.size ?? CGSize(width: 1440, height: 900)

        // 表示先ディスプレイの自動スケール × 設定のサイズ倍率 × 基準サイズ係数（描画前に設定）。
        SwitcherLayout.currentScale = SwitcherLayout.scale(forWidth: visible.width)
            * AppSettings.sizeScale
            * SwitcherLayout.baseSizeFactor

        let layout = solveLayout(count: windows.count, visible: visible)
        currentColumns = layout.columns
        model.update(
            windows: windows,
            selectedIndex: Navigation.clamp(selectedIndex, count: windows.count),
            layout: layout,
            screenFrame: screenFrame
        )
        isSwitcherActive = true
        panel.show()
        Log.windows.info("present scale \(Int(SwitcherLayout.currentScale * 100), privacy: .public)% on \(Int(visible.width), privacy: .public)pt")
    }

    /// スイッチャーを表示する対象ディスプレイ（最前面ウィンドウのある画面、無ければメイン）。
    private func targetScreen() -> NSScreen? {
        frontmostWindowScreen() ?? NSScreen.main
    }

    /// 最前面の通常ウィンドウ（z-order 先頭の layer 0）が乗っているディスプレイを返す。
    private func frontmostWindowScreen() -> NSScreen? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in infoList {
            // layer 0 = 通常ウィンドウ（メニューバー等の特殊レイヤーを除外）。先頭が最前面。
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            return screen(containing: bounds)
        }
        return nil
    }

    /// CG 座標（左上原点・y 下向き）の矩形の中心が乗っている NSScreen を返す。
    private func screen(containing cgRect: CGRect) -> NSScreen? {
        // CG 座標を AppKit 座標（左下原点・y 上向き）へ変換するため、メニューバー画面（原点が (0,0)）の高さで反転する。
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        guard let primaryHeight = primary?.frame.height else { return nil }
        let point = CGPoint(x: cgRect.midX, y: primaryHeight - cgRect.midY)
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// close/quit でウィンドウが減った後の再表示。残りが空ならスイッチャーを閉じる。
    private func refresh(with windows: [WindowInfo]) {
        if windows.isEmpty {
            close()
        } else {
            present(windows, selectedIndex: model.selectedIndex)
        }
    }

    private func selectedWindow() -> WindowInfo? {
        let index = Navigation.clamp(model.selectedIndex, count: model.windows.count)
        return model.windows.indices.contains(index) ? model.windows[index] : nil
    }

    private func solveLayout(count: Int, visible: CGSize) -> GridLayout.Result {
        let available = CGSize(
            width: visible.width - SwitcherLayout.screenMargin * 2,
            height: visible.height - SwitcherLayout.screenMargin * 2
        )
        return GridLayout.solve(
            count: count,
            available: available,
            spacing: SwitcherLayout.gridSpacing,
            labelHeight: SwitcherLayout.labelHeight,
            thumbnailAspect: SwitcherLayout.thumbnailAspect,
            maxCellWidth: SwitcherLayout.maxCellWidth
        )
    }

    private func advance(reverse: Bool) {
        let count = model.windows.count
        guard count > 0 else { return }
        model.selectedIndex = reverse
            ? Navigation.previousIndex(current: model.selectedIndex, count: count)
            : Navigation.nextIndex(current: model.selectedIndex, count: count)
    }

    private func commit() {
        let windows = model.windows
        let index = Navigation.clamp(model.selectedIndex, count: windows.count)
        if windows.indices.contains(index) {
            WindowActivator.activate(windows[index])
        }
        close()
    }

    private func close() {
        isSwitcherActive = false
        panel.hide()
        // 進行中のサムネイル取得はキャンセルしない。完了させてキャッシュを温めておくことで、
        // 素早く開閉してもキャッシュが蓄積される。古いタスクは次回 open の startThumbnailCapture が置き換える。
    }

    private func startThumbnailCapture(for windows: [WindowInfo]) {
        // サムネイル用 Screen Recording 権限を初回のみ要求する（未許可ならアイコン表示で縮退）。
        if !didRequestScreenRecording, !Permissions.hasScreenRecording() {
            didRequestScreenRecording = true
            Permissions.requestScreenRecording()
        }

        thumbnailTask?.cancel()
        let ids = windows.map(\.id)
        thumbnailTask = Task { [weak self] in
            let thumbnails = await ThumbnailCapturer.captureThumbnails(for: ids)
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for (id, image) in thumbnails {
                    self.thumbnailCache.store(image, for: id)
                    self.model.setThumbnail(image, for: id)
                }
            }
        }
    }
}
