#!/usr/bin/env bash
set -euo pipefail

# cTab を安定した identity で署名するための自己署名コード署名証明書を作成する。
#
# なぜ必要か:
#   ad-hoc 署名（codesign -s -）は実行ファイルの cdhash に依存するため、
#   再ビルドのたびに macOS が「別アプリ」と判定し、付与済みの TCC 権限
#   （アクセシビリティ・画面収録）が失効する。
#   固定の証明書で署名すると Designated Requirement が
#   「bundle id + 証明書」基準になり、再ビルド後も権限が維持される。
#
# 専用キーチェーン（既知パスワード）を使うため、ユーザーのパスワード入力は不要。
# 証明書は信頼ストアには登録しない（ローカル署名専用・Apple Developer Program 不要）。
# 既に identity がある場合は再作成しない（再作成すると証明書が変わり権限が失効するため）。

IDENTITY="${1:-cTab Self-Signed}"
KEYCHAIN="$HOME/Library/Keychains/cTab-signing.keychain-db"
KEYCHAIN_PASSWORD="cTab-local-signing"   # ローカル署名専用キーチェーンのパスワード（秘匿価値なし）

if security find-identity -p codesigning 2>/dev/null | grep -qF "$IDENTITY"; then
  echo "署名 identity '$IDENTITY' は既に存在します。何もしません。"
  exit 0
fi

TMP="$(mktemp -d)"
trap '/bin/rm -rf "$TMP"' EXIT

# コード署名用途の自己署名証明書を生成。
cat > "$TMP/cfg" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $IDENTITY
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -days 3650 -nodes -config "$TMP/cfg" >/dev/null 2>&1

# macOS の security import が読めるよう -legacy（旧暗号）で p12 化する。
P12_PASSWORD="import-$$"
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

# 専用キーチェーンを用意（無ければ作成）。自動ロックを無効化して解錠しておく。
if [ ! -f "$KEYCHAIN" ]; then
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
fi
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

# codesign からのみアクセスできる形で取り込み、無確認アクセスを許可する。
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

# 検索リストへ追加（codesign / find-identity が見つけられるように。重複追加は避ける）。
EXISTING="$(security list-keychains -d user | sed 's/[" ]//g')"
if ! printf '%s\n' "$EXISTING" | grep -qF "$KEYCHAIN"; then
  # shellcheck disable=SC2086
  security list-keychains -d user -s "$KEYCHAIN" $EXISTING
fi

echo "完了: 署名 identity '$IDENTITY' を作成しました。"
echo "  専用キーチェーン: $KEYCHAIN"
echo "次に 'scripts/build_app.sh run' で再インストールすると、この証明書で署名されます。"
echo "アクセシビリティ権限を一度だけ付与すれば、以後の再ビルドでも維持されます。"
