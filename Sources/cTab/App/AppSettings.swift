import CoreGraphics
import Foundation

/// 永続化するユーザー設定（UserDefaults）。
///
/// ここで扱うのは表示サイズ倍率などの非機微な設定値のみ。
/// ウィンドウタイトルや画面サムネイルなどの機微情報は対象にしない（従来どおりメモリ内のみ）。
enum AppSettings {
    private static let sizeScaleKey = "sizeScale"
    private static let showOnAllDisplaysKey = "showOnAllDisplays"

    static let defaultSizeScale: CGFloat = 1.0
    static let minSizeScale: CGFloat = 0.5
    static let maxSizeScale: CGFloat = 1.5

    /// スイッチャーを全ディスプレイに同時表示するか（既定 false = 最前面ウィンドウのある画面のみ）。
    static var showOnAllDisplays: Bool {
        get { UserDefaults.standard.bool(forKey: showOnAllDisplaysKey) }
        set { UserDefaults.standard.set(newValue, forKey: showOnAllDisplaysKey) }
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
