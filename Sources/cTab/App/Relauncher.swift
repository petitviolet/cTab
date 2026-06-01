import AppKit

/// アプリを再起動する。
///
/// 自プロセスの終了を待ってから `open` し直す子シェルを起動することで、
/// 新旧2つのインスタンスが同時に EventTap を張る競合を避ける。
enum Relauncher {
    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [
            "-c",
            "while /bin/kill -0 \(pid) >/dev/null 2>&1; do sleep 0.2; done; /usr/bin/open \"\(bundlePath)\""
        ]

        do {
            try task.run()
        } catch {
            Log.general.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        NSApp.terminate(nil)
    }
}
