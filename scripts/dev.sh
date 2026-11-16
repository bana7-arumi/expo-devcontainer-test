#!/usr/bin/env bash
# WSL(コンテナの外)で実行する、開発の入り口。これ 1 つで次のことを行う。
#   1. devcontainer を起動する(起動済みなら何もしない)
#   2. ネイティブ部分が前回のビルドから変わっていれば、コンテナ内で development build をビルドし直す
#   3. 指定した端末に入っている APK が古い(または入っていない)ときだけインストールする
#   4. adb reverse で端末から Metro に届くようにする
#   5. コンテナ内で Metro を起動し、準備ができたら端末で dev client を Metro につなぐ
# Metro はこのターミナルで動き続ける(r でリロード、Ctrl+C で終了)。
#
#   使い方: ./scripts/dev.sh [--rebuild] <serial> [<serial>...] | all
#     --rebuild   ネイティブ部分が変わっていなくてもビルドし直す
set -euo pipefail
source "$(dirname "$0")/lib.sh"

rebuild=0
if [ "${1:-}" = "--rebuild" ]; then rebuild=1; shift; fi
resolve_serials "$@"
ensure_container

# ---- 2. 必要ならビルド ----
fp=$(native_fingerprint)
if [ $rebuild -eq 1 ] || [ ! -f "$APK" ] || [ "$(cat "$APK_FP" 2>/dev/null)" != "$fp" ]; then
  echo "▶ ネイティブ部分が変わったので development build をビルドします"
  in_container npm run build:android </dev/null
  echo "$fp" > "$APK_FP"
else
  echo "✓ ビルド済みの APK はそのまま使えます"
fi

# ---- 3, 4. 端末ごとにインストールと adb reverse ----
for s in "${serials[@]}"; do
  if [ "$(adb -s "$s" shell cat "$DEVICE_FP" 2>/dev/null | tr -d '\r')" != "$fp" ] \
     || ! adb -s "$s" shell pm path "$APP_ID" >/dev/null 2>&1; then
    echo "▶ $s: development build をインストールします"
    adb -s "$s" install -r "$(wslpath -w "$APK")"
    adb -s "$s" shell "echo $fp > $DEVICE_FP"
  else
    echo "✓ $s: インストール済みの development build は最新です"
  fi
  adb -s "$s" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
done

# ---- 5. Metro を起動し、準備ができたら各端末で開く ----
if metro_running; then
  echo "Metro はすでに localhost:$PORT で動いています。端末で開くだけにします"
  for s in "${serials[@]}"; do adb -s "$s" shell am start -a android.intent.action.VIEW -d "'$DEV_CLIENT_URL'" >/dev/null; done
  exit 0
fi

(
  for _ in $(seq 1 120); do metro_running && break; sleep 1; done
  for s in "${serials[@]}"; do adb -s "$s" shell am start -a android.intent.action.VIEW -d "'$DEV_CLIENT_URL'" >/dev/null; done
) &
opener=$!
# ターミナルを閉じたときなどに、コンテナ内の Metro が残らないようにする(このスクリプトが起動したものだけを止める)
cleanup() {
  kill $opener 2>/dev/null || true
  docker exec "$CID" pkill -f "expo start --port $PORT" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

in_container npx expo start --port "$PORT"
