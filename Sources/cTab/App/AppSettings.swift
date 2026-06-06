import CoreGraphics
import Foundation

/// 永続化するユーザー設定（UserDefaults）。
///
/// ここで扱うのは表示サイズ倍率などの非機微な設定値のみ。
/// ウィンドウタイトルや画面サムネイルなどの機微情報は対象にしない（従来どおりメモリ内のみ）。
enum AppSettings {
    private static let sizeScaleKey = "sizeScale"
    private static let showOnAllDisplaysKey = "showOnAllDisplays"
    private static let highlightActiveDisplayKey = "highlightActiveDisplay"
    private static let inactiveBackgroundOpacityKey = "inactiveBackgroundOpacity"

    static let defaultSizeScale: CGFloat = 1.0
    static let minSizeScale: CGFloat = 0.5
    static let maxSizeScale: CGFloat = 1.5

    /// アクティブ画面にないウィンドウへ敷く黒背景の不透明度（1.0 = 設定上の最大）。
    static let defaultInactiveBackgroundOpacity: CGFloat = 1.0
    static let minInactiveBackgroundOpacity: CGFloat = 0.3
    static let maxInactiveBackgroundOpacity: CGFloat = 1.0
    /// 黒さの基準係数。以前の 100% が濃すぎたため 0.5 に調整（以前の 50% を新しい 100% に）。
    /// 設定値（inactiveBackgroundOpacity）にこれを掛けた値を実際の黒背景の不透明度として使う。
    static let inactiveBackgroundFactor: CGFloat = 0.5

    /// 実際に黒背景へ適用する不透明度（設定値 × 基準係数）。
    static var effectiveInactiveBackgroundOpacity: CGFloat {
        inactiveBackgroundOpacity * inactiveBackgroundFactor
    }

    /// スイッチャーを全ディスプレイに同時表示するか（既定 false = 最前面ウィンドウのある画面のみ）。
    static var showOnAllDisplays: Bool {
        get { UserDefaults.standard.bool(forKey: showOnAllDisplaysKey) }
        set { UserDefaults.standard.set(newValue, forKey: showOnAllDisplaysKey) }
    }

    /// 複数ディスプレイ時、マウスのある画面にあるウィンドウを強調（他画面を減光）するか（既定 true）。
    static var highlightActiveDisplay: Bool {
        get { (UserDefaults.standard.object(forKey: highlightActiveDisplayKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: highlightActiveDisplayKey) }
    }

    /// アクティブ画面にないウィンドウへ敷く黒背景の不透明度（高いほど黒い）。
    static var inactiveBackgroundOpacity: CGFloat {
        get {
            guard let value = UserDefaults.standard.object(forKey: inactiveBackgroundOpacityKey) as? Double else {
                return defaultInactiveBackgroundOpacity
            }
            return clampInactiveBackgroundOpacity(CGFloat(value))
        }
        set { UserDefaults.standard.set(Double(clampInactiveBackgroundOpacity(newValue)), forKey: inactiveBackgroundOpacityKey) }
    }

    static func clampInactiveBackgroundOpacity(_ value: CGFloat) -> CGFloat {
        min(max(value, minInactiveBackgroundOpacity), maxInactiveBackgroundOpacity)
    }

    /// スイッチャー表示サイズの倍率。ディスプレイに応じた自動スケールに掛ける。
    static var sizeScale: CGFloat {
        get {
            guard let value = UserDefaults.standard.object(forKey: sizeScaleKey) as? Double else {
                return defaultSizeScale
            }
            return clampSizeScale(CGFloat(value))
        }
        set {
            UserDefaults.standard.set(Double(clampSizeScale(newValue)), forKey: sizeScaleKey)
        }
    }

    static func clampSizeScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minSizeScale), maxSizeScale)
    }
}
