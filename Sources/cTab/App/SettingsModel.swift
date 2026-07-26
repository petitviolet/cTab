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
    /// セキュア入力を保持しているプロセス名。nil なら正常（キー傍受が可能）。
    var secureInputHolder: String?
    /// スイッチャー表示サイズの倍率（永続化された設定値の初期反映）。
    var sizeScale: CGFloat = AppSettings.sizeScale
    /// 全ディスプレイ同時表示の ON/OFF。
    var showOnAllDisplays: Bool = AppSettings.showOnAllDisplays
    /// 別 Space のウィンドウを含めるか。
    var includeOtherSpaces: Bool = AppSettings.includeOtherSpaces
    /// トリガの修飾キー。
    var triggerModifier: TriggerModifier = AppSettings.triggerModifier
    /// トリガキーの仮想キーコード。
    var triggerKeyCode: Int = AppSettings.triggerKeyCode
    /// 起動方式（ホールド/トグル）。
    var activationMode: ActivationMode = AppSettings.activationMode
    /// 外観モード。
    var appearance: AppearanceMode = AppearanceMode(rawValue: AppSettings.appearanceRaw) ?? .system
    /// アクセントカラー。
    var accentColor: AccentColorOption = AccentColorOption(rawValue: AppSettings.accentColorRaw) ?? .system
    /// パネル背景の不透明度。
    var panelOpacity: CGFloat = AppSettings.panelOpacity
    /// アクティブディスプレイ強調の ON/OFF。
    var highlightActiveDisplay: Bool = AppSettings.highlightActiveDisplay
    /// アクティブ画面にないウィンドウへ敷く黒背景の不透明度。
    var inactiveBackgroundOpacity: CGFloat = AppSettings.inactiveBackgroundOpacity
    /// アプリショートカット（keyCode → bundle id）。
    var appHotKeys: [Int: String] = AppSettings.appHotKeys

    /// アプリショートカットを追加する（同じキーは上書き）。
    func addAppHotKey(keyCode: Int, bundleID: String) {
        updateAppHotKeys { $0[keyCode] = bundleID }
    }

    /// アプリショートカットを削除する。
    func removeAppHotKey(keyCode: Int) {
        updateAppHotKeys { $0.removeValue(forKey: keyCode) }
    }

    /// 紐づけ辞書を変更して AppSettings と画面状態の双方へ反映する。
    /// 辞書の部分更新のため、他項目の Binding 直接書き戻しパターンではなくメソッド経由にしている。
    private func updateAppHotKeys(_ mutate: (inout [Int: String]) -> Void) {
        var bindings = AppSettings.appHotKeys
        mutate(&bindings)
        AppSettings.appHotKeys = bindings
        appHotKeys = bindings
    }

    func refresh() {
        accessibilityGranted = Permissions.hasAccessibility()
        screenRecordingGranted = Permissions.hasScreenRecording()
        launchAtLogin = LoginItem.isEnabled
        secureInputHolder = Permissions.secureInputHolder()
        appHotKeys = AppSettings.appHotKeys

        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        version = "\(short) (\(build))"
    }
}
