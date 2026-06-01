import CoreGraphics
import Observation

/// スイッチャー UI の状態。SwiftUI が監視する。
@Observable
final class SwitcherViewModel {
    var windows: [WindowInfo] = []
    var selectedIndex: Int = 0
    var columns: Int = 1
    var cellWidth: CGFloat = 220
    var cellHeight: CGFloat = 170
    /// パネルを中央配置する対象ディスプレイの frame。
    var screenFrame: CGRect = .zero

    func update(windows: [WindowInfo], selectedIndex: Int, layout: GridLayout.Result, screenFrame: CGRect) {
        self.windows = windows
        self.selectedIndex = selectedIndex
        self.columns = layout.columns
        self.cellWidth = layout.cellWidth
        self.cellHeight = layout.cellHeight
        self.screenFrame = screenFrame
    }

    /// 非同期に取得したサムネイルを該当ウィンドウへ反映する。
    /// 配列を作り直して再代入することで、SwiftUI への変更通知を確実にする。
    func setThumbnail(_ image: CGImage, for id: CGWindowID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        var updated = windows
        updated[index].thumbnail = image
        windows = updated
    }
}
