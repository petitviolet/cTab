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
    /// 表示中だけ有効なマウス移動モニタ（アクティブ画面の追従用）。
    private var mouseMonitors: [Any] = []

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

    func handleTriggerReleased() {
        guard isSwitcherActive else { return }
        // ホールドモードのみ、修飾キーを離したら確定する。トグルモードは Return で確定。
        if AppSettings.activationMode == .hold {
            commit()
        }
    }

    func handleEscape() -> Bool {
        guard isSwitcherActive else { return false }
        close()
        return true
    }

    func handleConfirm() -> Bool {
        guard isSwitcherActive else { return false }
        commit()
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

    func handleMinimizeSelectedWindow() -> Bool {
        guard isSwitcherActive, let target = selectedWindow() else { return true }
        // 最小化して一覧から取り除く（スイッチャーは開いたまま継続）。
        if WindowActivator.minimize(target) {
            refresh(with: model.windows.filter { $0.id != target.id })
        }
        return true
    }

    func handleToggleFullScreen() -> Bool {
        guard isSwitcherActive, let target = selectedWindow() else { return true }
        // フルスクリーン切替後はそのウィンドウへ移動して確定する（アニメーションを見せる）。
        if WindowActivator.toggleFullScreen(target) {
            WindowActivator.activate(target)
            close()
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
        // 設定で OFF なら別 Space のウィンドウを除外する。
        if !AppSettings.includeOtherSpaces {
            windows = windows.filter { !$0.isOnOtherSpace }
        }
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

    /// ウィンドウ一覧をディスプレイごとに計算してパネルを表示する。
    /// close/quit 後の再表示にも使う（既存のサムネイルを保持したまま再レイアウトする）。
    private func present(_ windows: [WindowInfo], selectedIndex: Int) {
        let screens = targetScreens()
        guard !screens.isEmpty else { return }

        let layouts = screens.map { screenLayout(for: $0, windowCount: windows.count) }
        // 先頭（最前面ウィンドウのある画面）の列数を矢印ナビの基準にする。
        currentColumns = layouts.first?.columns ?? 1

        // マウスカーソルのある画面をアクティブにする（どのディスプレイでも可。無ければ先頭画面）。
        let active = mouseScreen()?.frame ?? layouts[0].screenFrame
        model.activeScreenFrame = active

        model.update(windows: windows, selectedIndex: Navigation.clamp(selectedIndex, count: windows.count))
        isSwitcherActive = true
        panel.show(layouts: layouts, activeScreenFrame: active)
        startMouseTracking()
        Log.windows.info("present on \(layouts.count, privacy: .public) display(s)")
    }

    private func mouseScreen() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }

    /// 表示中のマウス移動を監視し、別ディスプレイへ移ったらアクティブ画面を切り替える。
    /// ディスプレイが複数あるときのみ監視する（1枚なら全ウィンドウが同一画面で区別不要）。
    /// cTab はアクティブ化しない（`.nonactivatingPanel`）ためマウスイベントは他アプリへ流れる。
    /// よって global monitor だけで全位置を捕捉でき、local monitor は不要。
    private func startMouseTracking() {
        guard mouseMonitors.isEmpty, NSScreen.screens.count > 1 else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
            self?.handleMouseMoved()
        }) {
            mouseMonitors.append(global)
        }
    }

    private func stopMouseTracking() {
        mouseMonitors.forEach { NSEvent.removeMonitor($0) }
        mouseMonitors.removeAll()
    }

    private func handleMouseMoved() {
        guard isSwitcherActive,
              let frame = mouseScreen()?.frame,
              frame != model.activeScreenFrame else { return }
        model.activeScreenFrame = frame
        // パネルがある画面なら key を移す（無ければ no-op）。
        panel.makeActive(screenFrame: frame)
    }

    /// 表示する対象ディスプレイ群。全ディスプレイ設定が ON なら全画面、OFF なら最前面ウィンドウのある画面のみ。
    /// 先頭は最前面ウィンドウのある画面（key パネル兼 矢印ナビの基準）。
    private func targetScreens() -> [NSScreen] {
        let front = targetScreen()
        guard AppSettings.showOnAllDisplays else {
            return front.map { [$0] } ?? []
        }
        var screens = NSScreen.screens
        if let front, let index = screens.firstIndex(of: front) {
            screens.remove(at: index)
            screens.insert(front, at: 0)
        }
        return screens
    }

    /// スイッチャーの基準となるディスプレイ（最前面ウィンドウのある画面、無ければメイン）。
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

    /// 指定ディスプレイの確定レイアウトを計算する（スケール = 自動スケール × サイズ倍率 × 基準係数）。
    private func screenLayout(for screen: NSScreen, windowCount: Int) -> ScreenLayout {
        let visible = screen.visibleFrame.size
        let scale = SwitcherLayout.scale(forWidth: visible.width)
            * AppSettings.sizeScale
            * SwitcherLayout.baseSizeFactor
        let available = CGSize(
            width: visible.width - SwitcherLayout.screenMargin * 2,
            height: visible.height - SwitcherLayout.screenMargin * 2
        )
        let result = GridLayout.solve(
            count: windowCount,
            available: available,
            spacing: SwitcherLayout.gridSpacing(scale),
            labelHeight: SwitcherLayout.labelHeight(scale),
            thumbnailAspect: SwitcherLayout.thumbnailAspect,
            maxCellWidth: SwitcherLayout.maxCellWidth(scale)
        )
        return ScreenLayout(
            screenFrame: screen.frame,
            columns: result.columns,
            rows: result.rows,
            cellWidth: result.cellWidth,
            cellHeight: result.cellHeight,
            scale: scale
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
        stopMouseTracking()
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
