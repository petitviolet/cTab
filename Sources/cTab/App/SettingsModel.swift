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
    /// 全ディスプレイ同時表示の ON/OFF。
    var showOnAllDisplays: Bool = AppSettings.showOnAllDisplays
    /// アクティブディスプレイ強調の ON/OFF。
    var highlightActiveDisplay: Bool = AppSettings.highlightActiveDisplay
    /// アクティブ画面にないウィンドウへ敷く黒背景の不透明度。
    var inactiveBackgroundOpacity: CGFloat = AppSettings.inactiveBackgroundOpacity

    func refresh() {
        accessibilityGranted = Permissions.hasAccessibility()
        screenRecordingGranted = Permissions.hasScreenRecording()
        launchAtLogin = LoginItem.isEnabled

        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        version = "\(short) (\(build))"
    }
}
