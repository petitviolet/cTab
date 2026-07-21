#!/usr/bin/env bash
set -euo pipefail

# README 用スクリーンショット（docs/screenshot.png）を実際の SwitcherView から描画する。
# ウィンドウ内容は実画面ではなく、codex で生成した架空アプリ画面のサムネイルを使う。
#
# 使い方: scripts/generate_screenshot.sh <サムネイルディレクトリ>
#   サムネイルディレクトリには ctab_thumb_1.png 〜 ctab_thumb_6.png（各 1536x1024）を置く。
#   codex での生成手順は下記コメント参照。
#
# サムネイル生成（codex サブスクリプション経由・API 課金なし）:
#   codex exec --skip-git-repo-check --sandbox workspace-write "$(cat prompt.txt)" < /dev/null
#   prompt には「6 枚の架空アプリ画面（ブラウザ/エディタ/ターミナル/カレンダー/音楽/メモ）を
#   built-in image_gen(size 1536x1024) で 1 枚ずつ生成し ctab_thumb_N.png に保存」を指示する。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THUMB_DIR="${1:?usage: $0 <サムネイルディレクトリ>}"
OUT="$ROOT/docs/screenshot.png"

swift build -c debug
"$ROOT/.build/debug/cTab" --render-screenshot "$OUT" "$THUMB_DIR"

# README 向けに幅 1600px へ軽量化。
sips --resampleWidth 1600 "$OUT" --out "$OUT" >/dev/null
echo "Generated $OUT"
