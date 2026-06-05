import SwiftUI

/// 設定ウィンドウの内容。権限状態・ログイン起動・使い方・再起動/終了。
struct SettingsView: View {
    let model: SettingsModel
    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    GroupBox("権限") {
                VStack(alignment: .leading, spacing: 10) {
                    PermissionRow(
                        title: "アクセシビリティ（必須）",
                        detail: "Command+Tab の傍受とウィンドウ操作に必要",
                        granted: model.accessibilityGranted,
                        openAction: Permissions.openAccessibilitySettings
                    )
                    PermissionRow(
                        title: "画面収録（任意）",
                        detail: "ウィンドウのサムネイル表示に必要",
                        granted: model.screenRecordingGranted,
                        openAction: Permissions.openScreenRecordingSettings
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox("起動") {
                Toggle("ログイン時に起動", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { enabled in
                        if enabled { LoginItem.enable() } else { LoginItem.disable() }
                        model.refresh()
                    }
                ))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox("表示") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("全ディスプレイに表示", isOn: Binding(
                        get: { model.showOnAllDisplays },
                        set: { enabled in
                            model.showOnAllDisplays = enabled
                            AppSettings.showOnAllDisplays = enabled
                        }
                    ))
                    Divider()
                    HStack {
                        Text("スイッチャーの大きさ")
                        Spacer()
                        Text("\(Int((model.sizeScale * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(model.sizeScale) },
                            set: { newValue in
                                let scale = CGFloat(newValue)
                                model.sizeScale = scale
                                AppSettings.sizeScale = scale
                            }
                        ),
                        in: Double(AppSettings.minSizeScale)...Double(AppSettings.maxSizeScale),
                        step: 0.05
                    )
                    Text("ディスプレイに応じた自動調整に、この倍率を掛けます（次回 Command+Tab から反映）。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox("アクティブディスプレイ") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("マウスのある画面のウィンドウを強調", isOn: Binding(
                        get: { model.highlightActiveDisplay },
                        set: { enabled in
                            model.highlightActiveDisplay = enabled
                            AppSettings.highlightActiveDisplay = enabled
                        }
                    ))
                    HStack {
                        Text("他画面のウィンドウの濃さ")
                        Spacer()
                        Text("\(Int((model.inactiveDisplayOpacity * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(model.inactiveDisplayOpacity) },
                            set: { newValue in
                                let opacity = CGFloat(newValue)
                                model.inactiveDisplayOpacity = opacity
                                AppSettings.inactiveDisplayOpacity = opacity
                            }
                        ),
                        in: Double(AppSettings.minInactiveDisplayOpacity)...Double(AppSettings.maxInactiveDisplayOpacity),
                        step: 0.05
                    )
                    .disabled(!model.highlightActiveDisplay)
                    Text("複数ディスプレイ時、マウスのある画面にないウィンドウの濃さ（低いほど薄い）。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox("使い方") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Command を押しながら Tab：スイッチャーを開く / 次へ")
                    Text("• Command + Shift + Tab：前へ")
                    Text("• Command を押しながら 矢印キー（←→↑↓）：グリッド上を移動")
                    Text("• Command + W：選択中のウィンドウを閉じる")
                    Text("• Command + Q：選択中のアプリを終了")
                    Text("• Command を離す：切り替え確定 / Escape：キャンセル")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
                }
                .padding(22)
            }

            Divider()

            HStack(spacing: 10) {
                Text("権限を変更したら「再起動」してください")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("再起動") { Relauncher.relaunch() }
                Button("cTab を終了") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .frame(width: 470, height: 640)
        .onAppear { model.refresh() }
        .onReceive(refreshTimer) { _ in model.refresh() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("cTab").font(.system(size: 22, weight: .semibold))
                Text("Command+Tab ウィンドウスイッチャー  v\(model.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 権限 1 項目の行（状態アイコン + 説明 + 設定を開くボタン）。
private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(granted ? "許可済み" : "開く", action: openAction)
                .disabled(granted)
        }
    }
}
