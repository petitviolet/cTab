import CoreGraphics

/// windowID をキーにサムネイルを保持するメモリキャッシュ。
///
/// スイッチャーを開いた瞬間に前回取得済みのサムネイルを即表示し、裏で最新化するために使う。
/// 現存しないウィンドウのエントリは prune で破棄するため、サイズは「現在開いているウィンドウ数」程度に収まる。
///
/// セキュリティ方針: 画像はメモリ内のみで保持し、ディスク保存・ネットワーク送信は行わない。
final class ThumbnailCache {
    private var images: [CGWindowID: CGImage] = [:]

    func image(for id: CGWindowID) -> CGImage? {
        images[id]
    }

    func store(_ image: CGImage, for id: CGWindowID) {
        images[id] = image
    }

    /// 引数に含まれない windowID のエントリを破棄する（メモリ肥大と閉じたウィンドウのゴースト表示を防ぐ）。
    func prune(keeping ids: Set<CGWindowID>) {
        images = images.filter { ids.contains($0.key) }
    }

    func removeAll() {
        images.removeAll()
    }
}
