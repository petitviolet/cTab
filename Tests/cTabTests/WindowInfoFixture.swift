import AppKit
import ApplicationServices
@testable import cTab

/// テスト用の WindowInfo を生成するファクトリ。
/// WindowInfo は AXUIElement を必須に持つため、自プロセスの AX 要素をダミーとして使う。
enum WindowInfoFixture {
    static func make(
        id: CGWindowID = 1,
        appName: String = "TestApp",
        bundleID: String? = nil,
        title: String = "",
        screenFrame: CGRect = .zero,
        isOnOtherSpace: Bool = false,
        isMinimized: Bool = false,
        thumbnail: CGImage? = nil
    ) -> WindowInfo {
        WindowInfo(
            id: id,
            pid: getpid(),
            appName: appName,
            bundleID: bundleID,
            title: title,
            appIcon: nil,
            axElement: AXUIElementCreateApplication(getpid()),
            screenFrame: screenFrame,
            isOnOtherSpace: isOnOtherSpace,
            isMinimized: isMinimized,
            thumbnail: thumbnail
        )
    }
}
