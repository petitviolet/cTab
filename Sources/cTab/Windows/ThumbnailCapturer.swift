import CoreGraphics
import ScreenCaptureKit

/// ScreenCaptureKit を使ってウィンドウのサムネイルを取得する。
///
/// セキュリティ方針: 取得した画像はメモリ内のみで扱い、ディスク保存やネットワーク送信は行わない。
/// Screen Recording 権限が無い場合は空を返し、呼び出し側はアイコン表示で縮退する。
enum ThumbnailCapturer {
    /// 指定した CGWindowID 群のサムネイルを並行取得する。
    /// - Parameter maxDimension: 長辺の最大ピクセル数（縮小してキャプチャコストを抑える）。
    static func captureThumbnails(for windowIDs: [CGWindowID], maxDimension: CGFloat = 480) async -> [CGWindowID: CGImage] {
        guard !windowIDs.isEmpty else { return [:] }

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            Log.windows.info("screen recording unavailable; skipping thumbnails")
            return [:]
        }

        let wanted = Set(windowIDs)
        let targets = content.windows.filter { wanted.contains($0.windowID) }

        var results: [CGWindowID: CGImage] = [:]
        await withTaskGroup(of: (CGWindowID, CGImage?).self) { group in
            for scWindow in targets {
                group.addTask {
                    (scWindow.windowID, await capture(scWindow, maxDimension: maxDimension))
                }
            }
            for await (id, image) in group {
                if let image {
                    results[id] = image
                }
            }
        }
        return results
    }

    private static func capture(_ window: SCWindow, maxDimension: CGFloat) async -> CGImage? {
        let width = window.frame.width
        let height = window.frame.height
        guard width > 1, height > 1 else { return nil }

        let scale = min(1.0, maxDimension / max(width, height))
        let config = SCStreamConfiguration()
        config.width = max(1, Int(width * scale))
        config.height = max(1, Int(height * scale))
        config.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
