#!/usr/bin/env bash
set -euo pipefail

# cTab を .app バンドルとしてビルド・署名・インストールするスクリプト。
# 使い方: scripts/build_app.sh {build|icon|cert|bundle|install|run|reset|uninstall}
#   cert: 権限を再ビルド後も維持するための自己署名証明書を作成（一度だけ・対話実行）

APP="cTab"
BUNDLE_ID="net.petitviolet.cTab"
CONFIG="${CONFIG:-release}"
# 署名 identity。CODESIGN_IDENTITY 未指定時は自己署名証明書 'cTab Self-Signed' を使う。
# 該当 identity が無ければ ad-hoc 署名にフォールバックする。
SIGN_IDENTITY="${CODESIGN_IDENTITY:-cTab Self-Signed}"
# 署名証明書を入れる専用キーチェーン（create_signing_cert.sh が作成）。
# パスワードは固定値だが、信頼されないローカル自己署名証明書専用のため秘匿価値はない。
SIGNING_KEYCHAIN="$HOME/Library/Keychains/cTab-signing.keychain-db"
SIGNING_KEYCHAIN_PASSWORD="cTab-local-signing"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_BIN="$ROOT/.build/$CONFIG/$APP"
APP_BUNDLE="$ROOT/build/$APP.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP.app"

cmd_build() {
  swift build -c "$CONFIG"
}

cmd_icon() {
  mkdir -p "$ROOT/build"
  swift "$ROOT/scripts/generate_icon.swift" "$ROOT/build/cTab.iconset"
  iconutil -c icns "$ROOT/build/cTab.iconset" -o "$ROOT/Resources/cTab.icns"
  echo "Generated $ROOT/Resources/cTab.icns"
}

cmd_bundle() {
  cmd_build
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS"
  mkdir -p "$APP_BUNDLE/Contents/Resources"
  cp "$BUILD_BIN" "$APP_BUNDLE/Contents/MacOS/$APP"
  cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
  if [ -f "$ROOT/Resources/cTab.icns" ]; then
    cp "$ROOT/Resources/cTab.icns" "$APP_BUNDLE/Contents/Resources/cTab.icns"
  fi
  sign_bundle
  echo "Built $APP_BUNDLE"
}

# 固定証明書があればそれで署名（TCC 権限が再ビルド後も維持される）。
# 無ければ ad-hoc 署名にフォールバック（再ビルドで権限が失効する）。
# 単一バイナリ構成なので --deep は付けない（Apple 非推奨）。
sign_bundle() {
  # 専用キーチェーンがあれば解錠（再起動後はロックされているため）。
  if [ -f "$SIGNING_KEYCHAIN" ]; then
    security unlock-keychain -p "$SIGNING_KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN" 2>/dev/null || true
  fi

  # 専用キーチェーン内の証明書の SHA-1 ハッシュを取得（同名証明書が複数あっても一意に署名するため）。
  local hash=""
  if [ -f "$SIGNING_KEYCHAIN" ]; then
    hash="$(security find-identity -p codesigning "$SIGNING_KEYCHAIN" 2>/dev/null \
      | grep -F "$SIGN_IDENTITY" | grep -oE '[0-9A-F]{40}' | head -1)"
  fi

  if [ -n "$hash" ]; then
    codesign --force --sign "$hash" "$APP_BUNDLE"
    echo "Signed with: ${SIGN_IDENTITY} [${hash}] - TCC 権限は再ビルド後も維持されます"
  elif security find-identity -p codesigning 2>/dev/null | grep -qF "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
    echo "Signed with: ${SIGN_IDENTITY} - TCC 権限は再ビルド後も維持されます"
  else
    codesign --force --sign - "$APP_BUNDLE"
    echo "WARNING: ad-hoc 署名です。再ビルドのたびに TCC 権限が失効します。"
    echo "  権限を永続化するには 'scripts/build_app.sh cert' を一度実行してください。"
  fi
}

cmd_install() {
  cmd_bundle
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALLED_APP"
  cp -R "$APP_BUNDLE" "$INSTALLED_APP"
  echo "Installed to $INSTALLED_APP"
}

cmd_run() {
  cmd_install
  open "$INSTALLED_APP"
  echo "Launched. Accessibility / Screen Recording 権限をシステム設定で付与してください。"
}

cmd_reset() {
  killall "$APP" 2>/dev/null || true
  tccutil reset Accessibility "$BUNDLE_ID" || true
  tccutil reset ScreenCapture "$BUNDLE_ID" || true
  echo "Reset permissions for $BUNDLE_ID"
  echo "次の手順で再付与してください: 1) scripts/build_app.sh run で再インストール・起動"
  echo "  2) システム設定 > プライバシーとセキュリティ > アクセシビリティ で cTab を ON"
  echo "  3) cTab を再起動（メニューバーの ⌘⇥ から終了し、再度 open）"
}

cmd_uninstall() {
  killall "$APP" 2>/dev/null || true
  rm -rf "$INSTALLED_APP"
  tccutil reset Accessibility "$BUNDLE_ID" || true
  tccutil reset ScreenCapture "$BUNDLE_ID" || true
  echo "Uninstalled $INSTALLED_APP and reset permissions for $BUNDLE_ID"
}

case "${1:-bundle}" in
  build) cmd_build ;;
  icon) cmd_icon ;;
  cert) exec "$ROOT/scripts/create_signing_cert.sh" "$SIGN_IDENTITY" ;;
  bundle) cmd_bundle ;;
  install) cmd_install ;;
  run) cmd_run ;;
  reset) cmd_reset ;;
  uninstall) cmd_uninstall ;;
  *) echo "usage: $0 {build|icon|cert|bundle|install|run|reset|uninstall}"; exit 1 ;;
esac
