import ServiceManagement

/// ログイン時の自動起動を管理する（macOS 13+ の SMAppService を使用）。
///
/// メインアプリのバンドルをログイン項目として登録する。インストール済みの `.app`
/// （例: ~/Applications/cTab.app）から起動している必要がある。
enum LoginItem {
    /// 現在自動起動が有効か。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 自動起動を有効化する。成功なら true。
    @discardableResult
    static func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            Log.general.info("login item registered")
            return true
        } catch {
            Log.general.error("failed to register login item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 自動起動を無効化する。成功なら true。
    @discardableResult
    static func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            Log.general.info("login item unregistered")
            return true
        } catch {
            Log.general.error("failed to unregister login item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 現在の状態を反転する。
    @discardableResult
    static func toggle() -> Bool {
        isEnabled ? disable() : enable()
    }
}
