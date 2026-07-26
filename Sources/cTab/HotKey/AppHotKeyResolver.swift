import CoreGraphics

/// アプリショートカット（キー⇔アプリ紐づけ）の判定ロジック。副作用を持たず単体テスト可能。
///
/// 発動条件はトリガ修飾キーが押されている keyDown のみ:
/// - ホールドモード中は修飾キーを押したままなので、紐づけキー単独の押下で発動する。
/// - トグルモード（修飾キー解放後）では「修飾キー+キー」で発動し、素のキーは検索入力に流れる。
enum AppHotKeyResolver {
    /// 紐づけに使えない予約キーコード。既存のスイッチャー操作（トリガ・確定・キャンセル・
    /// ウィンドウ操作・移動・検索削除）と衝突するため、設定 UI で登録を拒否する。
    static func reservedKeyCodes(triggerKeyCode: Int64) -> Set<Int64> {
        [
            triggerKeyCode,
            HotKeyMatcher.tabKeyCode, HotKeyMatcher.graveKeyCode,
            HotKeyMatcher.escapeKeyCode,
            HotKeyMatcher.returnKeyCode, HotKeyMatcher.keypadEnterKeyCode,
            HotKeyMatcher.deleteKeyCode,
            HotKeyMatcher.wKeyCode, HotKeyMatcher.qKeyCode,
            HotKeyMatcher.mKeyCode, HotKeyMatcher.fKeyCode,
            HotKeyMatcher.leftArrowKeyCode, HotKeyMatcher.rightArrowKeyCode,
            HotKeyMatcher.downArrowKeyCode, HotKeyMatcher.upArrowKeyCode,
        ]
    }

    /// 押下キーに紐づくアプリの bundle id。トリガ修飾キーが押されていなければ nil。
    static func bundleID(
        keyCode: Int64,
        flags: CGEventFlags,
        modifier: CGEventFlags,
        bindings: [Int: String]
    ) -> String? {
        guard !bindings.isEmpty, flags.contains(modifier) else { return nil }
        return bindings[Int(keyCode)]
    }

    /// 切り替え先ウィンドウの index。bundle id の並び（z-order 前提）から先頭一致を返す。
    static func firstIndex(of bundleID: String, in bundleIDs: [String?]) -> Int? {
        bundleIDs.firstIndex(of: bundleID)
    }
}
