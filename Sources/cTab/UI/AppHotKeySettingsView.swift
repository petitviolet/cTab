import AppKit
import Carbon.HIToolbox
import SwiftUI
import UniformTypeIdentifiers

/// 設定画面「アプリショートカット」セクション。
/// スイッチャー表示中にキー 1 つで指定アプリへ切り替える紐づけ（keyCode ⇔ bundle id）を管理する。
struct AppHotKeySettingsView: View {
    let model: SettingsModel

    /// キャプチャ済みの追加待ちキーコード。nil なら未キャプチャ。
    @State private var pendingKeyCode: Int?
    /// キーキャプチャ中か（次の keyDown を 1 つ取り込む）。
    @State private var isCapturing = false
    /// 追加対象アプリの bundle id。
    @State private var pendingBundleID: String?
    /// キャプチャや追加操作のエラーメッセージ。
    @State private var errorMessage: String?
    /// 実行中アプリの選択肢（表示時に取得）。
    @State private var runningApps: [(bundleID: String, name: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スイッチャー表示中にキーを押すと、紐づけたアプリのウィンドウへ即切り替えます（ホールド中はキー単独、トグル中は修飾キー+キー）")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 登録済み一覧
            ForEach(model.appHotKeys.sorted(by: { $0.key < $1.key }), id: \.key) { keyCode, bundleID in
                bindingRow(keyCode: keyCode, bundleID: bundleID)
            }

            Divider()

            // 追加フォーム: キーキャプチャ + アプリ選択 + 追加
            HStack(spacing: 8) {
                Button(captureButtonTitle) {
                    isCapturing = true
                    errorMessage = nil
                }
                .disabled(isCapturing)

                Picker("", selection: appSelection) {
                    Text("アプリを選択").tag(String?.none)
                    ForEach(runningApps, id: \.bundleID) { app in
                        Text(app.name).tag(String?.some(app.bundleID))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)

                Button("その他…") { chooseAppFromPanel() }

                Button("追加") { addBinding() }
                    .disabled(pendingKeyCode == nil || pendingBundleID == nil)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
            }
        }
        .onAppear { reloadRunningApps() }
        // キーキャプチャ: セクション内にフォーカス可能な透明レイヤを置かず、ローカルモニタで次の 1 打鍵を拾う。
        .background(KeyCaptureMonitor(isCapturing: $isCapturing) { keyCode in
            captured(keyCode: keyCode)
        })
    }

    private var captureButtonTitle: String {
        if isCapturing { return "キーを押してください…" }
        if let keyCode = pendingKeyCode { return "キー: \(KeyCodeLabel.label(for: keyCode))" }
        return "キーを記録"
    }

    private var appSelection: Binding<String?> {
        Binding(get: { pendingBundleID }, set: { pendingBundleID = $0 })
    }

    private func bindingRow(keyCode: Int, bundleID: String) -> some View {
        HStack(spacing: 8) {
            Text(KeyCodeLabel.label(for: keyCode))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(minWidth: 28)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.15)))
            if let icon = appIcon(for: bundleID) {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            Text(appDisplayName(for: bundleID))
                .font(.system(size: 12))
            Text(bundleID)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                model.removeAppHotKey(keyCode: keyCode)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("この紐づけを削除")
        }
    }

    private func captured(keyCode: Int) {
        let reserved = AppHotKeyResolver.reservedKeyCodes(triggerKeyCode: Int64(AppSettings.triggerKeyCode))
        if reserved.contains(Int64(keyCode)) {
            errorMessage = "このキーはスイッチャー操作に予約されているため使えません"
            pendingKeyCode = nil
        } else {
            errorMessage = nil
            pendingKeyCode = keyCode
        }
    }

    private func addBinding() {
        guard let keyCode = pendingKeyCode, let bundleID = pendingBundleID else { return }
        model.addAppHotKey(keyCode: keyCode, bundleID: bundleID)
        pendingKeyCode = nil
        pendingBundleID = nil
        errorMessage = nil
    }

    private func chooseAppFromPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            errorMessage = "選択したアプリの bundle identifier を取得できませんでした"
            return
        }
        // Picker の選択肢に無いアプリでも選択状態を表せるよう、一覧に加える。
        if !runningApps.contains(where: { $0.bundleID == bundleID }) {
            let name = FileManager.default.displayName(atPath: url.path)
            runningApps.append((bundleID: bundleID, name: name))
            runningApps.sort { $0.name < $1.name }
        }
        pendingBundleID = bundleID
    }

    private func reloadRunningApps() {
        // 同一 bundle id の複数プロセス（アプリ二重起動等）があるため、bundle id で重複排除する
        // （ForEach の id 重複による未定義動作を避ける）。
        var seen = Set<String>()
        var apps: [(bundleID: String, name: String)] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier, seen.insert(bundleID).inserted else { continue }
            apps.append((bundleID: bundleID, name: app.localizedName ?? bundleID))
        }
        // 登録済みだが起動していないアプリも一覧に含める（行表示との整合）。
        for bundleID in model.appHotKeys.values where seen.insert(bundleID).inserted {
            apps.append((bundleID: bundleID, name: appDisplayName(for: bundleID)))
        }
        runningApps = apps.sorted { $0.name < $1.name }
    }

    private func appDisplayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// キャプチャ中のみ NSEvent ローカルモニタを張り、次の keyDown を 1 つだけ取り込む補助ビュー。
/// 設定ウィンドウ内のイベントのみ対象（ローカルモニタ）なので、他アプリのキーには一切触れない。
private struct KeyCaptureMonitor: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onCapture: (Int) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.setCapturing(isCapturing)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator {
        private let parent: KeyCaptureMonitor
        private var monitor: Any?

        init(parent: KeyCaptureMonitor) {
            self.parent = parent
        }

        func setCapturing(_ capturing: Bool) {
            if capturing, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self else { return event }
                    let keyCode = Int(event.keyCode)
                    DispatchQueue.main.async {
                        self.parent.onCapture(keyCode)
                        self.parent.isCapturing = false
                    }
                    self.remove()
                    return nil  // キャプチャした打鍵はウィンドウへ流さない
                }
            } else if !capturing {
                remove()
            }
        }

        private func remove() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            remove()
        }
    }
}

/// keyCode を現在のキーボードレイアウトで表示用文字列へ変換する。
enum KeyCodeLabel {
    static func label(for keyCode: Int) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "#\(keyCode)"
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataRef).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { buffer -> String in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return "#\(keyCode)"
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let error = UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, chars.count, &length, &chars
            )
            guard error == noErr, length > 0 else { return "#\(keyCode)" }
            let text = String(utf16CodeUnits: chars, count: length)
            return text.uppercased()
        }
    }
}
