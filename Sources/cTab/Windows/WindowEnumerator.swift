import AppKit
import ApplicationServices
import CoreGraphics

/// AXUIElement から対応する CGWindowID を取得する非公開 API。
/// HIServices に実体があり、AltTab をはじめ多くのウィンドウ管理アプリで利用される定番の手法。
/// AX ウィンドウと ScreenCaptureKit の SCWindow（windowID で識別）を突き合わせるために必要。
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

/// 全アプリの可視ウィンドウを Accessibility API で列挙する。
enum WindowEnumerator {
    private static let standardWindowSubrole = "AXStandardWindow"

    /// AX メッセージのタイムアウト（秒）。応答しないアプリ 1 つで列挙全体が固まるのを防ぐ。
    /// これを設定しないと既定タイムアウト（数秒）まで同期で待たされ、Command+Tab のラグになる。
    private static let messagingTimeout: Float = 0.25

    /// 1 ウィンドウあたりに読む属性（role / subrole / title / minimized）。
    private static let windowAttributes = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute,
    ]

    /// 通常アプリ（`.regular`）の標準ウィンドウを列挙する。最小化ウィンドウも含む。
    static func enumerate() -> [WindowInfo] {
        let start = CFAbsoluteTimeGetCurrent()
        var result: [WindowInfo] = []

        // CGWindowList から重なり順（front-to-back）と各ウィンドウの矩形を先に取得する。
        let onScreen = onScreenInfo()

        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for app in apps {
            let pid = app.processIdentifier
            guard pid > 0 else { continue }

            let appElement = AXUIElementCreateApplication(pid)
            // タイムアウト設定はローカル処理（IPC なし）。以降この要素宛の AX 呼び出しに適用される。
            AXUIElementSetMessagingTimeout(appElement, messagingTimeout)

            var windowsValue: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
            guard err == .success, let axWindows = windowsValue as? [AXUIElement] else { continue }

            let appName = app.localizedName ?? "Unknown"
            let icon = app.icon

            for axWindow in axWindows {
                AXUIElementSetMessagingTimeout(axWindow, messagingTimeout)
                guard let info = makeWindowInfo(axWindow, pid: pid, appName: appName, icon: icon, onScreen: onScreen) else { continue }
                result.append(info)
            }
        }

        // 画面の重なり順（front-to-back）で並べ替える。先頭が最前面（=現在のウィンドウ）になり、
        // 標準 Command+Tab と同じく「直前のウィンドウ」を初期選択（index 1）できる。
        // z-order に現れないウィンドウ（最小化など）は末尾に回す。
        let sorted = result.sorted { lhs, rhs in
            (onScreen.order[lhs.id] ?? Int.max) < (onScreen.order[rhs.id] ?? Int.max)
        }

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        Log.windows.info("enumerated \(sorted.count, privacy: .public) windows in \(elapsedMs, privacy: .public) ms")
        return sorted
    }

    /// 1 ウィンドウ分の属性を読み、標準ウィンドウなら WindowInfo を作る。対象外なら nil。
    private static func makeWindowInfo(_ window: AXUIElement, pid: pid_t, appName: String, icon: NSImage?, onScreen: (order: [CGWindowID: Int], bounds: [CGWindowID: CGRect])) -> WindowInfo? {
        let role: String?
        let subrole: String?
        let title: String
        let minimized: Bool

        // まず role / subrole / title / minimized を 1 回の IPC でまとめて取得する。
        if let batched = batchedAttributes(of: window, windowAttributes) {
            role = batched[kAXRoleAttribute] as? String
            subrole = batched[kAXSubroleAttribute] as? String
            title = (batched[kAXTitleAttribute] as? String) ?? ""
            minimized = (batched[kAXMinimizedAttribute] as? Bool) ?? false
        } else {
            // バッチ取得に失敗した場合のみ個別取得にフォールバック（取りこぼし防止）。
            role = stringAttribute(window, kAXRoleAttribute)
            subrole = stringAttribute(window, kAXSubroleAttribute)
            title = stringAttribute(window, kAXTitleAttribute) ?? ""
            minimized = boolAttribute(window, kAXMinimizedAttribute) ?? false
        }

        // 標準ウィンドウのみ採用（role が AXWindow、subrole があれば標準ウィンドウ）。
        guard role == (kAXWindowRole as String) else { return nil }
        if let subrole, subrole != standardWindowSubrole { return nil }

        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else { return nil }

        // CGWindowList の矩形から、このウィンドウが乗っているディスプレイを求める（不明なら .zero）。
        let screenFrame = onScreen.bounds[windowID].map { displayFrame(containing: $0) } ?? CGRect.zero
        // 現在の Space の画面上にも無く、最小化でもないウィンドウは別 Space にあると推定する。
        let onOtherSpace = onScreen.order[windowID] == nil && !minimized

        return WindowInfo(
            id: windowID,
            pid: pid,
            appName: appName,
            title: title,
            appIcon: icon,
            axElement: window,
            screenFrame: screenFrame,
            isOnOtherSpace: onOtherSpace,
            isMinimized: minimized,
            thumbnail: nil
        )
    }

    /// 複数の AX 属性を 1 回の IPC でまとめて取得する。呼び出し自体が失敗したら nil。
    /// 個々の属性が無い場合はそのキーが入らない（呼び出しは成功扱い）。
    private static func batchedAttributes(of element: AXUIElement, _ names: [String]) -> [String: Any]? {
        var valuesRef: CFArray?
        let err = AXUIElementCopyMultipleAttributeValues(
            element,
            names as CFArray,
            AXCopyMultipleAttributeOptions(rawValue: 0),
            &valuesRef
        )
        guard err == .success, let values = valuesRef as? [AnyObject], values.count == names.count else {
            return nil
        }

        var result: [String: Any] = [:]
        for (index, name) in names.enumerated() {
            // 取得失敗の属性は AXValue(error 型) が入るため、String/Bool として読めるものだけ採用する。
            let value = values[index]
            if let string = value as? String {
                result[name] = string
            } else if let bool = value as? Bool {
                result[name] = bool
            }
        }
        return result
    }

    /// CGWindowList から可視ウィンドウの重なり順（front-to-back）と矩形を取得する。
    private static func onScreenInfo() -> (order: [CGWindowID: Int], bounds: [CGWindowID: CGRect]) {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return ([:], [:])
        }
        var order: [CGWindowID: Int] = [:]
        var bounds: [CGWindowID: CGRect] = [:]
        for (index, info) in infoList.enumerated() {
            guard let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { continue }
            let id = CGWindowID(number)
            order[id] = index
            if let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
               let rect = CGRect(dictionaryRepresentation: boundsDict) {
                bounds[id] = rect
            }
        }
        return (order, bounds)
    }

    /// CG 座標（左上原点・y 下向き）の矩形の中心が乗っているディスプレイの frame を返す。
    private static func displayFrame(containing cgBounds: CGRect) -> CGRect {
        // CG 座標を AppKit 座標（左下原点）へ変換するため、メニューバー画面（原点 (0,0)）の高さで反転する。
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        guard let primaryHeight = primary?.frame.height else { return .zero }
        let center = CGPoint(x: cgBounds.midX, y: primaryHeight - cgBounds.midY)
        return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }?.frame ?? .zero
    }

    // MARK: - 個別取得フォールバック

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }
}
