# cTab 仕様書

> English version: [specification_en.md](specification_en.md)
> 対象バージョン: cTab 0.1.0

---

## 1. 概要

cTab は macOS 標準の Command+Tab（アプリ単位）を置き換え、**ウィンドウ単位**で切り替えるスイッチャーアプリです。修飾キーを押しながらトリガキーを叩くとサムネイル付きのグリッドが表示され、選択したウィンドウを前面化します。Dock にアイコンを出さないメニューバー常駐型（アクセサリアプリ）です。

---

## 2. 動作環境

| 項目 | 内容 |
| --- | --- |
| OS | macOS 14 以降（開発・検証は macOS 26） |
| ツールチェーン | Swift 6（Xcode 26 同梱） |
| 依存 | Apple システムフレームワークのみ。第三者ライブラリなし。 |
| 権限 | アクセシビリティ（必須）、画面収録（任意・サムネイル用） |

---

## 3. 機能要件

### 3.1 ウィンドウ切り替え

- 通常アプリ（`activationPolicy == .regular`）の標準ウィンドウを列挙する。最小化ウィンドウも含む。
- 画面の重なり順（front-to-back）で並べ、先頭が最前面ウィンドウ。初期選択は「直前のウィンドウ」（index 1）。
- 選択を確定するとそのウィンドウを前面化し、必要なら最小化を復元、アプリをアクティブ化する。

### 3.2 トリガとナビゲーション

| 操作 | 既定 | 説明 |
| --- | --- | --- |
| 開く・次へ | `Command`+`Tab` | スイッチャー表示／選択を進める |
| 前へ | `Command`+`Shift`+`Tab` | 逆順 |
| 移動 | `Command`+`←→↑↓` | グリッド上を移動 |
| 確定 | `Command` を離す（ホールド時）、`Return`（トグル時） | |
| キャンセル | `Escape` | |

トリガの修飾キー（Command / Option / Control）とキー（Tab / `）は設定で変更でき、変更は即時反映される。Command 以外にすれば標準の Command+Tab を残せる。

### 3.3 起動方式

- **ホールド**（既定）：修飾キーを押している間だけ表示し、離すと確定（標準と同じ）。
- **トグル**：一度開くと修飾キーを離しても開いたまま。`Return` で確定、`Escape` でキャンセル、トリガキー単独でも選択を進められる。マウス・矢印・検索でゆっくり選べる。

### 3.4 インクリメンタル検索

スイッチャー表示中に文字を入力すると、アプリ名・ウィンドウ名で大文字小文字を無視して絞り込む。`Backspace` で 1 文字削除。検索バーにクエリを表示。トグルモードと相性が良い。トリガキーを ` にした場合、`（と ~）は検索に入力できない。

### 3.5 ウィンドウ操作

| 操作 | キー | 説明 |
| --- | --- | --- |
| 閉じる | `Command`+`W` | 選択ウィンドウを閉じる（クローズボタン押下） |
| アプリ終了 | `Command`+`Q` | 選択アプリを graceful 終了 |
| 最小化 | `Command`+`M` | 選択ウィンドウを最小化 |
| フルスクリーン | `Command`+`F` | フルスクリーン切替（AXFullScreen、なければボタン押下） |

操作キーの修飾キーはトリガ修飾キーに追従する（例: トリガが Option なら Option+W で閉じる）。閉じる・終了・最小化を実行するとそのウィンドウは一覧から外れ、スイッチャーは開いたまま継続する。母集合が空になれば自動的に閉じる。

### 3.6 マウス操作

セルをクリックでそのウィンドウへ切り替え。セルにホバーすると右上に閉じるボタン（×）が出て、押すとそのウィンドウを閉じる。マウス操作はマウスカーソルのある画面のパネルで有効。

### 3.7 サムネイル

ScreenCaptureKit でウィンドウのプレビューを取得する。windowID ごとにメモリキャッシュし、開いた瞬間に前回分を即表示して裏で最新化する。連続バックグラウンド撮影はしないため、画面収録インジケータの常時表示や電池消費はない。画面収録権限が無い場合や取得前はアプリアイコンで代替する。

### 3.8 レイアウトと表示サイズ

ウィンドウ数と表示先ディスプレイの作業領域から、画面内に収まる列数・セルサイズを算出する（横スクロールしない）。表示先ディスプレイの幅に応じて自動拡大し、設定のスライダーで倍率（50〜150%）を掛けられる。

### 3.9 マルチディスプレイ

- 既定では「最前面ウィンドウのある画面」に表示する。設定で全ディスプレイ同時表示を有効化でき、各画面は自分の解像度に合わせてサイズ調整、選択状態は同期する。
- **アクティブディスプレイの識別**：マウスカーソルのある画面にないウィンドウのセルに黒背景を敷いて見分けやすくする。マウス移動にリアルタイム追従する。ON/OFF と黒さ（背景不透明度）は設定可能。

### 3.10 Space

別 Space にあるウィンドウ（現在の Space の画面上に無く、最小化でもないもの）も一覧に含める／除外する設定がある（既定: 含める）。別 Space のウィンドウを選ぶとその Space に切り替わる。

### 3.11 テーマ / 外観

外観（システム / ライト / ダーク）、選択枠のアクセントカラー、パネル背景の不透明度を設定できる。

### 3.12 その他

ログイン時の自動起動（`SMAppService`）、設定ウィンドウ、メニューバーメニュー（設定を開く / 再起動 / 終了）。

---

## 4. アーキテクチャ

### 4.1 データフロー

```
トリガキー
  → EventTapController（CGEventTap が傍受しイベント消費）
  → SwitcherController.open（WindowEnumerator で列挙）
  → SwitcherPanel.show（ディスプレイごとに NSPanel + SwiftUI）
  → Tab/矢印/検索で選択更新
  → 修飾キー解放 or Return で確定
  → WindowActivator（AX 前面化 + アプリ activate）
```

### 4.2 モジュール構成

```
Sources/cTab/
├── main.swift                 エントリ（accessory アプリ起動）
├── App/
│   ├── AppDelegate.swift      権限確認・メニューバー・設定ウィンドウ・配線
│   ├── AppSettings.swift      UserDefaults による設定の永続化
│   ├── SettingsWindowController.swift / SettingsModel.swift  設定ウィンドウ
│   ├── LoginItem.swift        ログイン項目（SMAppService）
│   └── Relauncher.swift       アプリ再起動
├── HotKey/
│   ├── HotKeyMatcher.swift    トリガ／操作キーの判定（純ロジック・テスト対象）
│   └── EventTapController.swift   CGEventTap 生成・イベント傍受/復帰
├── Windows/
│   ├── WindowInfo.swift       ウィンドウモデル
│   ├── WindowEnumerator.swift AX 列挙（+ 非公開 API で CGWindowID）
│   ├── WindowActivator.swift  前面化・閉じる・終了・最小化・フルスクリーン
│   ├── ThumbnailCapturer.swift / ThumbnailCache.swift   サムネイル取得とキャッシュ
├── UI/
│   ├── SwitcherViewModel.swift   @Observable 共有状態
│   ├── SwitcherView.swift     SwiftUI グリッド・検索バー・テーマ
│   ├── SwitcherPanel.swift    NSPanel（ディスプレイごと）
│   └── SwitcherController.swift  オーケストレーター
└── Core/
    ├── Navigation.swift       選択巡回・グリッド移動（純ロジック・テスト対象）
    ├── GridLayout.swift       列数・セルサイズの算出（純ロジック・テスト対象）
    └── Log.swift              os.Logger
```

### 4.3 使用フレームワークと主要 API

| 用途 | API |
| --- | --- |
| トリガ傍受 | `CGEvent.tapCreate`（session / headInsert / defaultTap）、`keyDown` / `flagsChanged` |
| ウィンドウ列挙 | `NSWorkspace.runningApplications`、`AXUIElementCreateApplication`、`kAXWindowsAttribute`、`CGWindowListCopyWindowInfo`、非公開 `_AXUIElementGetWindow` |
| 操作 | `AXUIElementPerformAction(kAXRaiseAction)`、`kAXMinimizedAttribute`、`AXFullScreen`、`NSRunningApplication.activate/terminate` |
| 表示 | `NSPanel`（`.nonactivatingPanel`）、SwiftUI + `NSHostingView` |
| サムネイル | `SCShareableContent`、`SCScreenshotManager`（ScreenCaptureKit） |
| 起動 | `SMAppService`（ServiceManagement） |

---

## 5. 設定項目

| 設定 | 既定 | 範囲・選択肢 |
| --- | --- | --- |
| トリガ修飾キー | Command | Command / Option / Control |
| トリガキー | Tab | Tab / `（backtick） |
| 起動方式 | ホールド | ホールド / トグル |
| ログイン時に起動 | OFF | ON / OFF |
| 全ディスプレイに表示 | OFF | ON / OFF |
| 別 Space を含める | ON | ON / OFF |
| スイッチャーの大きさ | 100% | 50%–150% |
| アクティブ画面の強調 | ON | ON / OFF |
| 他画面の背景の黒さ | 100%（実効 50%） | 30%–100% |
| 外観 | システム | システム / ライト / ダーク |
| アクセントカラー | システム | システム / ブルー / パープル / ピンク / グリーン / オレンジ / レッド |
| 背景の不透明度 | 100% | 50%–100% |

設定は `UserDefaults`（`net.petitviolet.cTab` ドメイン）に保存され、トリガ／検索／表示系は次回スイッチャー表示から反映される。

---

## 6. 権限とビルド・配布

### 6.1 権限

アクセシビリティ権限が無いと EventTap を作成できず、Command+Tab を傍受できない（標準スイッチャーが出る）。画面収録権限はサムネイルにのみ必要で、未許可ならアイコン表示で縮退する。

### 6.2 ビルドと署名

Swift Package Manager の executable をビルドし、シェルスクリプト（`scripts/build_app.sh`）で `.app` バンドル化する。TCC 権限はコード署名の Designated Requirement に紐づくため、ad-hoc 署名（cdhash 依存）では再ビルドのたびに権限が失効する。固定の自己署名証明書（`scripts/build_app.sh cert` が専用キーチェーンに作成）で署名すると DR が「bundle id + 証明書」基準になり、再ビルド後も権限が維持される。Apple Developer Program は不要。

### 6.3 配布

他者への配布には Developer ID 署名 + notarization が別途必要。自己署名は手元での権限永続化のためのもので、Gatekeeper を通すものではない。Mac App Store はサンドボックス必須で CGEventTap による横取りと非公開 API 利用が制約に反するため対象外。

---

## 7. セキュリティ / プライバシー

- EventTap の監視対象は `keyDown` / `flagsChanged` に限定する。スイッチャー非表示時はトリガ以外を一切消費せず素通しする。
- スイッチャー表示中のみ検索のために文字を読むが、メモリ内のローカル処理のみで保持・記録しない。
- ウィンドウタイトルや画面サムネイルはローカル・メモリ内のみで扱い、ディスク保存・ネットワーク送信は一切行わない。
- ログにウィンドウタイトル等の機微情報は出力しない（件数・状態・pid のみ）。

---

## 8. テスト

純ロジック層（`Navigation` / `GridLayout` / `HotKeyMatcher` / `WindowInfo` / `SwitcherViewModel` / `ThumbnailCache`）に対する単体テストを `swift test` で実行する（45 件）。EventTap・AX・ScreenCaptureKit・UI などの副作用層は実機での手動確認とする。

---

## 9. 既知の制約

- AX ウィンドウと CGWindowID の対応付けに非公開 API `_AXUIElementGetWindow` を使用しており、将来の macOS で挙動が変わる可能性がある（取得失敗時はそのウィンドウをスキップ）。
- 別 Space や一部アプリのウィンドウは AX の挙動により取得できないことがある。
- 複数ディスプレイで列数が異なる場合、上下移動は先頭（最前面ウィンドウのある）画面の列数を基準にする。
- マウスのクリック／ホバーはマウスカーソルのある画面のパネルで最も確実。
