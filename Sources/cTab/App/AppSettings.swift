import CoreGraphics
import Foundation

/// スイッチャーの起動方式。
enum ActivationMode: String, CaseIterable, Identifiable {
    /// 修飾キーを押している間だけ表示し、離すと確定（標準の Command+Tab と同じ）。
    case hold
    /// 一度トリガを押すと開いたまま。修飾キーを離しても確定せず、Return で確定・Escape でキャンセル。
    case toggle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hold: return "ホールド（離して確定）"
        case .toggle: return "トグル（Return で確定）"
        }
    }
}

/// 永続化するユーザー設定（UserDefaults）。
///
/// ここで扱うのは表示サイズ倍率などの非機微な設定値のみ。
/// ウィンドウタイトルや画面サムネイルなどの機微情報は対象にしない（従来どおりメモリ内のみ）。
enum AppSettings {
    private static let sizeScaleKey = "sizeScale"
    private static let showOnAllDisplaysKey = "showOnAllDisplays"
    private static let highlightActiveDisplayKey = "highlightActiveDisplay"
    private static let inactiveBackgroundOpacityKey = "inactiveBackgroundOpacity"
    private static let includeOtherSpacesKey = "includeOtherSpaces"
    private static let triggerModifierKey = "triggerModifier"
    private static let triggerKeyCodeKey = "triggerKeyCode"
    private static let activationModeKey = "activationMode"
    private static let appearanceKey = "appearance"
    private static let accentColorKey = "accentColor"
    private static let panelOpacityKey = "panelOpacity"

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

    /// 別 Space にあるウィンドウも一覧に含めるか（既定 true）。
    static var includeOtherSpaces: Bool {
        get { (UserDefaults.standard.object(forKey: includeOtherSpacesKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: includeOtherSpacesKey) }
    }

    /// スイッチャーのトリガに使う修飾キー（既定 Command）。
    static var triggerModifier: TriggerModifier {
        get { TriggerModifier(rawValue: UserDefaults.standard.string(forKey: triggerModifierKey) ?? "") ?? .command }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: triggerModifierKey) }
    }

    /// スイッチャーのトリガに使うキーの仮想キーコード（既定 Tab=0x30、ほかに ` =0x32）。
    static var triggerKeyCode: Int {
        get { (UserDefaults.standard.object(forKey: triggerKeyCodeKey) as? Int) ?? Int(HotKeyMatcher.tabKeyCode) }
        set { UserDefaults.standard.set(newValue, forKey: triggerKeyCodeKey) }
    }

    /// スイッチャーの起動方式（既定 hold）。
    static var activationMode: ActivationMode {
        get { ActivationMode(rawValue: UserDefaults.standard.string(forKey: activationModeKey) ?? "") ?? .hold }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: activationModeKey) }
    }

    // MARK: - テーマ／外観（enum は UI 層で解釈する。ここでは raw 値のみ保持）

    static let defaultPanelOpacity: CGFloat = 1.0
    static let minPanelOpacity: CGFloat = 0.5
    static let maxPanelOpacity: CGFloat = 1.0

    /// 外観モードの raw 値（既定 "system"）。
    static var appearanceRaw: String {
        get { UserDefaults.standard.string(forKey: appearanceKey) ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: appearanceKey) }
    }

    /// アクセントカラーの raw 値（既定 "system"）。
    static var accentColorRaw: String {
        get { UserDefaults.standard.string(forKey: accentColorKey) ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: accentColorKey) }
    }

    /// パネル背景の不透明度（低いほど透ける）。
    static var panelOpacity: CGFloat {
        get {
            guard let value = UserDefaults.standard.object(forKey: panelOpacityKey) as? Double else {
                return defaultPanelOpacity
            }
            return clampPanelOpacity(CGFloat(value))
        }
        set { UserDefaults.standard.set(Double(clampPanelOpacity(newValue)), forKey: panelOpacityKey) }
    }

    static func clampPanelOpacity(_ value: CGFloat) -> CGFloat {
        min(max(value, minPanelOpacity), maxPanelOpacity)
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
