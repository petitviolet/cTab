import os

/// アプリ全体のロガー。
///
/// セキュリティ方針: ウィンドウタイトルや入力キーなどの機微情報はログに出力しない。
/// 出力するのは件数・状態などの非機微情報に限る。
enum Log {
    private static let subsystem = "net.petitviolet.cTab"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let windows = Logger(subsystem: subsystem, category: "windows")
    static let permission = Logger(subsystem: subsystem, category: "permission")
}
