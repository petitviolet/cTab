import CoreGraphics
import Foundation

/// ウィンドウ数と利用可能領域から、画面内に収まるグリッドの列数・セルサイズを決める純ロジック。
/// サムネイルができるだけ大きくなる列数を選ぶ。AppKit 非依存なので単体テスト可能。
enum GridLayout {
    struct Result: Equatable {
        let columns: Int
        let rows: Int
        let cellWidth: CGFloat
        let cellHeight: CGFloat
    }

    /// - Parameters:
    ///   - available: グリッドを収める領域（外周マージンを除いたサイズ）。
    ///   - spacing: セル間・外周の間隔。
    ///   - labelHeight: 各セルのタイトルラベル高さ。
    ///   - thumbnailAspect: サムネイル領域の幅/高さ比。
    ///   - maxCellWidth: セル幅の上限（少数ウィンドウ時に巨大化させない）。
    ///
    /// 各列数で「幅・高さ両制約に収まるセル幅」を求め、最大のものを選ぶ。
    /// 結果は常に available 内に収まる（下限クランプはしない＝多数時はセルが小さくなる）。
    static func solve(
        count: Int,
        available: CGSize,
        spacing: CGFloat,
        labelHeight: CGFloat,
        thumbnailAspect: CGFloat,
        maxCellWidth: CGFloat
    ) -> Result {
        func cellHeight(for width: CGFloat) -> CGFloat {
            width / thumbnailAspect + labelHeight
        }

        guard count > 0 else {
            return Result(columns: 1, rows: 0, cellWidth: maxCellWidth, cellHeight: cellHeight(for: maxCellWidth))
        }

        var bestColumns = 1
        var bestCellWidth: CGFloat = 0

        for columns in 1...count {
            let rows = rowCount(count: count, columns: columns)
            // 幅の制約から決まるセル幅
            let widthConstrained = (available.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
            // 高さの制約から決まるセル幅
            let availableCellHeight = (available.height - spacing * CGFloat(rows + 1)) / CGFloat(rows)
            let heightConstrained = (availableCellHeight - labelHeight) * thumbnailAspect
            let cellWidth = min(widthConstrained, heightConstrained)
            if cellWidth > bestCellWidth {
                bestCellWidth = cellWidth
                bestColumns = columns
            }
        }

        let columns = bestColumns
        let rows = rowCount(count: count, columns: columns)
        // 上限のみクランプ。下限は設けないため、はみ出しは起きない（0 以下だけ回避）。
        let cellWidth = max(min(bestCellWidth, maxCellWidth), 1)
        return Result(columns: columns, rows: rows, cellWidth: cellWidth, cellHeight: cellHeight(for: cellWidth))
    }

    /// グリッド全体の実寸（外周マージン込み）。
    static func contentSize(_ result: Result, spacing: CGFloat) -> CGSize {
        let width = CGFloat(result.columns) * result.cellWidth + spacing * CGFloat(result.columns + 1)
        let height = CGFloat(result.rows) * result.cellHeight + spacing * CGFloat(result.rows + 1)
        return CGSize(width: width, height: height)
    }

    static func rowCount(count: Int, columns: Int) -> Int {
        guard columns > 0 else { return count }
        return Int((Double(count) / Double(columns)).rounded(.up))
    }
}
