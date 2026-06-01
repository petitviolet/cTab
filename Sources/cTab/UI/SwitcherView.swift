import SwiftUI

/// スイッチャー UI のレイアウト定数。ビュー・パネル・グリッド計算で共有する。
///
/// 表示先ディスプレイの幅に応じて `currentScale` を掛け、解像度の異なるディスプレイでも
/// 見た目の大きさが揃うようにする。`currentScale` は present() でメインスレッドから設定し、
/// 同じくメインスレッドの描画で同期的に読み出すため、単純な可変 static にしている。
enum SwitcherLayout {
    static var currentScale: CGFloat = 1

    /// 全体の基準サイズ係数。元の 100% が大きかったため 0.75 に調整（現在の 75% を新しい 100% に）。
    /// present() で currentScale に掛けるため、これに連動して全要素が一律に縮む。
    static let baseSizeFactor: CGFloat = 0.75

    // 基準サイズ（scale=1 のとき）。currentScale を掛けてディスプレイに合わせる。
    private static let baseGridSpacing: CGFloat = 16
    private static let baseLabelHeight: CGFloat = 36
    private static let baseMaxCellWidth: CGFloat = 260
    private static let baseHeaderIconSize: CGFloat = 26
    private static let baseAppNameFontSize: CGFloat = 14

    static var gridSpacing: CGFloat { baseGridSpacing * currentScale }
    /// 各セル上部のヘッダー（アプリアイコン + アプリ名）に確保する高さ。
    static var labelHeight: CGFloat { baseLabelHeight * currentScale }
    static var maxCellWidth: CGFloat { baseMaxCellWidth * currentScale }
    static var headerIconSize: CGFloat { baseHeaderIconSize * currentScale }
    static var appNameFontSize: CGFloat { baseAppNameFontSize * currentScale }

    // スケールしない固定値。
    static let panelCornerRadius: CGFloat = 16
    static let thumbnailCornerRadius: CGFloat = 10
    static let selectionLineWidth: CGFloat = 4
    static let screenMargin: CGFloat = 90
    /// サムネイル領域の幅/高さ比。
    static let thumbnailAspect: CGFloat = 220.0 / 140.0

    /// ディスプレイ幅から表示スケールを求める。基準（14インチ相当）より大きい画面では拡大、縮小はしない。
    static func scale(forWidth width: CGFloat) -> CGFloat {
        let baseline: CGFloat = 1512
        return min(max(width / baseline, 1.0), 1.8)
    }
}

/// 画面内に収まるグリッドのスイッチャー本体（AltTab 風）。横スクロールしない。
struct SwitcherView: View {
    let model: SwitcherViewModel
    /// セルをクリックしたとき（そのウィンドウへ切り替え）。
    let onSelect: (WindowInfo) -> Void
    /// セルの閉じるボタンを押したとき（そのウィンドウを閉じる）。
    let onClose: (WindowInfo) -> Void

    var body: some View {
        let gridColumns = Array(
            repeating: GridItem(.fixed(model.cellWidth), spacing: SwitcherLayout.gridSpacing),
            count: max(model.columns, 1)
        )
        LazyVGrid(columns: gridColumns, spacing: SwitcherLayout.gridSpacing) {
            ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                WindowCell(
                    window: window,
                    isSelected: index == model.selectedIndex,
                    width: model.cellWidth,
                    height: model.cellHeight,
                    onSelect: { onSelect(window) },
                    onClose: { onClose(window) }
                )
            }
        }
        .padding(SwitcherLayout.gridSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SwitcherLayout.panelCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

/// 1 ウィンドウ分のセル。上部にアプリアイコン + アプリ名、下にサムネイル。サイズは可変。
/// クリックで切り替え、ホバーで閉じるボタンを表示する。
struct WindowCell: View {
    let window: WindowInfo
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    private var thumbnailHeight: CGFloat {
        max(height - SwitcherLayout.labelHeight, 1)
    }

    /// ウィンドウ名をアプリ名の横に表示するか（空、またはアプリ名と同一なら出さない）。
    private var showsWindowTitle: Bool {
        let trimmed = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != window.appName
    }

    var body: some View {
        VStack(spacing: 6) {
            // 上部：アプリアイコン + アプリ名（+ ウィンドウ名）を表示（ディスプレイに応じてスケール）
            HStack(spacing: 5) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: SwitcherLayout.headerIconSize, height: SwitcherLayout.headerIconSize)
                }
                Text(window.appName)
                    .font(.system(size: SwitcherLayout.appNameFontSize, weight: .medium))
                    .lineLimit(1)
                    .layoutPriority(1)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                if showsWindowTitle {
                    Text(window.title)
                        .font(.system(size: SwitcherLayout.appNameFontSize))
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
        .opacity(window.isMinimized ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in isHovering = hovering }
    }

    /// ホバー時にサムネイル右上へ出す閉じるボタン。
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18 * SwitcherLayout.currentScale))
                .foregroundStyle(.white, .black.opacity(0.55))
                .padding(6 * SwitcherLayout.currentScale)
        }
        .buttonStyle(.plain)
        .help("このウィンドウを閉じる")
    }
}
