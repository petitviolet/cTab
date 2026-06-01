import CoreGraphics
import Foundation
import Observation

/// 設定ウィンドウが表示する状態。`refresh()` で最新化する。
@Observable
final class SettingsModel {
    var accessibilityGranted = false
    var screenRecordingGranted = false
    var launchAtLogin = false
    var version = "-"
    /// スイッチャー表示サイズの倍率（永続化された設定値の初期反映）。
    var sizeScale: CGFloat = AppSettings.sizeScale

    func refresh() {
        accessibilityGranted = Permissions.hasAccessibility()
        screenRecordingGranted = Permissions.hasScreenRecording()
        launchAtLogin = LoginItem.isEnabled

        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        version = "\(short) (\(build))"
    }
}
