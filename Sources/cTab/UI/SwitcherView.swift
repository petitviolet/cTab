import SwiftUI

/// スイッチャー UI のレイアウト定数。スケールはディスプレイごとに異なるため、描画時に引数で渡す。
enum SwitcherLayout {
    // 基準サイズ（scale=1 のとき）。
    private static let baseGridSpacing: CGFloat = 16
    private static let baseLabelHeight: CGFloat = 36
    private static let baseMaxCellWidth: CGFloat = 260
    private static let baseHeaderIconSize: CGFloat = 26
    private static let baseAppNameFontSize: CGFloat = 14

    /// 全体の基準サイズ係数（100% 表示の基準を調整）。スケール計算側で掛ける。
    static let baseSizeFactor: CGFloat = 0.75

    static func gridSpacing(_ scale: CGFloat) -> CGFloat { baseGridSpacing * scale }
    static func labelHeight(_ scale: CGFloat) -> CGFloat { baseLabelHeight * scale }
    static func maxCellWidth(_ scale: CGFloat) -> CGFloat { baseMaxCellWidth * scale }
    static func headerIconSize(_ scale: CGFloat) -> CGFloat { baseHeaderIconSize * scale }
    static func appNameFontSize(_ scale: CGFloat) -> CGFloat { baseAppNameFontSize * scale }

    // スケールしない固定値。
    static let panelCornerRadius: CGFloat = 16
    static let thumbnailCornerRadius: CGFloat = 10
    static let selectionLineWidth: CGFloat = 4
    static let screenMargin: CGFloat = 90
    /// サムネイル領域の幅/高さ比。
    static let thumbnailAspect: CGFloat = 220.0 / 140.0

    /// スケール算出の基準ディスプレイ幅（14インチ相当）と自動拡大の上限。
    private static let scaleBaselineWidth: CGFloat = 1512
    private static let maxAutoScale: CGFloat = 1.8

    /// ディスプレイ幅から表示スケールを求める。基準より大きい画面では拡大、縮小はしない。
    static func scale(forWidth width: CGFloat) -> CGFloat {
        min(max(width / scaleBaselineWidth, 1.0), maxAutoScale)
    }
}

/// 1 ディスプレイ分の確定レイアウト（配置先・グリッド寸法・スケール）。
struct ScreenLayout {
    let screenFrame: CGRect
    let columns: Int
    let rows: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let scale: CGFloat
}

/// 画面内に収まるグリッドのスイッチャー本体（AltTab 風）。横スクロールしない。
struct SwitcherView: View {
    let model: SwitcherViewModel
    let layout: ScreenLayout
    /// セルをクリックしたとき（そのウィンドウへ切り替え）。
    let onSelect: (WindowInfo) -> Void
    /// セルの閉じるボタンを押したとき（そのウィンドウを閉じる）。
    let onClose: (WindowInfo) -> Void

    var body: some View {
        let spacing = SwitcherLayout.gridSpacing(layout.scale)
        let gridColumns = Array(
            repeating: GridItem(.fixed(layout.cellWidth), spacing: spacing),
            count: max(layout.columns, 1)
        )
        let inactiveOpacity = AppSettings.highlightActiveDisplay ? AppSettings.inactiveDisplayOpacity : 1.0
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                WindowCell(
                    window: window,
                    isSelected: index == model.selectedIndex,
                    isOnActiveDisplay: isOnActiveDisplay(window),
                    inactiveDisplayOpacity: inactiveOpacity,
                    width: layout.cellWidth,
                    height: layout.cellHeight,
                    scale: layout.scale,
                    onSelect: { onSelect(window) },
                    onClose: { onClose(window) }
                )
            }
        }
        .padding(spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SwitcherLayout.panelCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    /// このウィンドウがアクティブ（マウスカーソルのある）ディスプレイにあるか。
    /// アクティブ画面が未設定、またはウィンドウの所在が不明（最小化など）なら減光しない（true 扱い）。
    private func isOnActiveDisplay(_ window: WindowInfo) -> Bool {
        model.activeScreenFrame == .zero
            || window.screenFrame == .zero
            || window.screenFrame == model.activeScreenFrame
    }
}

/// 1 ウィンドウ分のセル。上部にアプリアイコン + アプリ名（+ ウィンドウ名）、下にサムネイル。
/// クリックで切り替え、ホバーで閉じるボタンを表示する。
struct WindowCell: View {
    let window: WindowInfo
    let isSelected: Bool
    /// このウィンドウがアクティブ（マウスのある）ディスプレイにあるか。false なら減光する。
    let isOnActiveDisplay: Bool
    /// 非アクティブディスプレイのウィンドウに適用する不透明度（1.0 = 減光なし）。
    let inactiveDisplayOpacity: CGFloat
    let width: CGFloat
    let height: CGFloat
    let scale: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    /// 最小化と「非アクティブディスプレイ」の両方を反映したセルの不透明度。
    private var cellOpacity: Double {
        let minimizedFactor = window.isMinimized ? 0.55 : 1.0
        let displayFactor = isOnActiveDisplay ? 1.0 : Double(inactiveDisplayOpacity)
        return minimizedFactor * displayFactor
    }

    private var thumbnailHeight: CGFloat {
        max(height - SwitcherLayout.labelHeight(scale), 1)
    }

    /// ウィンドウ名をアプリ名の横に表示するか（空、またはアプリ名と同一なら出さない）。
    private var showsWindowTitle: Bool {
        let trimmed = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != window.appName
    }

    var body: some View {
        VStack(spacing: 6) {
            // 上部：アプリアイコン + アプリ名（+ ウィンドウ名）
            HStack(spacing: 5) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: SwitcherLayout.headerIconSize(scale), height: SwitcherLayout.headerIconSize(scale))
                }
                Text(window.appName)
                    .font(.system(size: SwitcherLayout.appNameFontSize(scale), weight: .medium))
                    .lineLimit(1)
                    .layoutPriority(1)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                if showsWindowTitle {
                    Text(window.title)
                        .font(.system(size: SwitcherLayout.appNameFontSize(scale)))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(width: width, alignment: .leading)

            // 下部：サムネイル（未取得時はアプリアイコン）
            ZStack {
                if let thumbnail = window.thumbnail {
                    Image(decorative: thumbnail, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(thumbnailHeight * 0.18)
                }
            }
            .frame(width: width, height: thumbnailHeight)
            .background(Color.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: SwitcherLayout.thumbnailCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SwitcherLayout.thumbnailCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: SwitcherLayout.selectionLineWidth)
            )
            .overlay(alignment: .topTrailing) {
                if isHovering {
                    closeButton
                }
            }
        }
        .frame(width: width, height: height)
        .opacity(cellOpacity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in isHovering = hovering }
    }

    /// ホバー時にサムネイル右上へ出す閉じるボタン。
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18 * scale))
                .foregroundStyle(.white, .black.opacity(0.55))
                .padding(6 * scale)
        }
        .buttonStyle(.plain)
        .help("このウィンドウを閉じる")
    }
}
