import AppKit
import ApplicationServices

/// 切り替え対象となる 1 つのウィンドウを表すモデル。
///
/// `id` は CoreGraphics のウィンドウ ID。`axElement` は前面化操作に使う Accessibility 参照。
/// `thumbnail` はサムネイル取得（非同期）が完了するまで nil。
struct WindowInfo: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let appIcon: NSImage?
    let axElement: AXUIElement
    var isMinimized: Bool
    var thumbnail: CGImage?

    /// 一覧に表示するラベル。タイトルが空（空白のみを含む）ならアプリ名で代替。
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appName : title
    }
}
