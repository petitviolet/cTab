import CoreGraphics
import Observation

/// スイッチャー UI の共有状態（全ディスプレイのパネルが同じインスタンスを参照する）。
/// レイアウト（列数・セルサイズ・スケール）はディスプレイごとに異なるため、ここには持たせない。
@Observable
final class SwitcherViewModel {
    var windows: [WindowInfo] = []
    var selectedIndex: Int = 0
    /// 現在アクティブ（マウスカーソルのある）ディスプレイの frame。これ以外の画面のパネルは減光する。
    var activeScreenFrame: CGRect = .zero
    /// インクリメンタル検索のクエリ。空なら検索バー非表示。
    var searchQuery: String = ""

    func update(windows: [WindowInfo], selectedIndex: Int) {
        self.windows = windows
        self.selectedIndex = selectedIndex
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
