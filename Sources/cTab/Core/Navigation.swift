import Foundation

/// グリッド上の移動方向。
enum Direction {
    case left, right, up, down
}

/// 選択インデックスの巡回ロジック。AppKit に依存しない純ロジックなので単体テスト可能。
enum Navigation {
    /// 次のインデックス（末尾の次は先頭へ循環）。
    static func nextIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }

    /// 前のインデックス（先頭の前は末尾へ循環）。
    static func previousIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current - 1 + count) % count
    }

    /// スイッチャーを開いた直後の初期選択位置。
    /// 標準の Command+Tab と同様、ウィンドウが複数あるときは「直前のウィンドウ」（index 1）を選ぶ。
    static func initialIndex(count: Int) -> Int {
        count > 1 ? 1 : 0
    }

    /// インデックスを有効範囲に丸める。
    static func clamp(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    /// グリッド上を方向キーで移動する。
    /// 左右は ±1（巡回）、上下は ±列数（端では移動先が無ければその場に留まる）。
    static func move(current: Int, count: Int, columns: Int, direction: Direction) -> Int {
        guard count > 0 else { return 0 }
        let cols = max(columns, 1)
        switch direction {
        case .right:
            return nextIndex(current: current, count: count)
        case .left:
            return previousIndex(current: current, count: count)
        case .down:
            let target = current + cols
            return target < count ? target : current
        case .up:
            let target = current - cols
            return target >= 0 ? target : current
        }
    }
}
