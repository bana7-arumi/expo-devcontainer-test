# scripts/*.sh の共通処理(source して使う)。WSL(コンテナの外)で動く前提。
ADB="${ADB:-adb.exe}"
PORT="${RCT_METRO_PORT:-8081}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID=$(node -p "require('$ROOT/app.json').expo.android.package")
SCHEME=$(node -p "require('$ROOT/app.json').expo.scheme")
APK="$ROOT/android/app/build/outputs/apk/debug/app-debug.apk"
# APK をビルドしたときのネイティブ部分の fingerprint(APK の横に置く)
APK_FP="$APK.fingerprint"
# 端末に入れた APK の fingerprint を端末側に記録しておく場所
DEVICE_FP="/data/local/tmp/$APP_ID.fingerprint"
DEV_CLIENT_URL="$SCHEME://expo-development-client/?url=http%3A%2F%2F127.0.0.1%3A$PORT"

# ---- adb(Windows の adb.exe) ----

# adb サーバーが固まったときにスクリプトごと止まらないようにタイムアウトを付ける
adb() {
  local rc=0
  timeout "${ADB_TIMEOUT:-120}" "$ADB" "$@" || rc=$?
  if [ $rc -eq 124 ]; then
    echo "adb がタイムアウトしました。adb サーバーが固まっている可能性があります(PowerShell で taskkill /IM adb.exe /F を実行してから再試行してください)" >&2
  fi
  return $rc
}

list_devices() { adb devices | tr -d '\r' | awk 'NR>1 && $2=="device"{print $1}'; }

# 引数(<serial>... または all)を解決して配列 serials に入れる
resolve_serials() {
  if [ $# -eq 0 ]; then
    echo "使い方: $0 <serial> [<serial>...] | all" >&2
    echo "接続中の端末:" >&2
    list_devices | sed 's/^/  /' >&2
    exit 1
  fi
  if [ $# -eq 1 ] && [ "$1" = "all" ]; then
    mapfile -t serials < <(list_devices)
    [ ${#serials[@]} -gt 0 ] || { echo "adb に接続された端末がありません" >&2; exit 1; }
  else
    serials=("$@")
  fi
  local s
  for s in "${serials[@]}"; do
    [ "$(adb -s "$s" get-state 2>/dev/null | tr -d '\r')" = "device" ] \
      || { echo "端末 $s が接続されていません(adb.exe devices で確認してください)" >&2; exit 1; }
  done
}

metro_running() { curl -fsS --max-time 3 "http://localhost:$PORT/status" 2>/dev/null | grep -q running; }

# ---- devcontainer ----

# このフォルダの devcontainer を起動し(起動済みなら何もしない)、コンテナ ID を CID に入れる
ensure_container() {
  CID=$(docker ps -q --filter "label=devcontainer.local_folder=$ROOT" | head -1)
  if [ -z "$CID" ]; then
    echo "devcontainer を起動します..." >&2
    npx --yes @devcontainers/cli up --workspace-folder "$ROOT" >/dev/null
    CID=$(docker ps -q --filter "label=devcontainer.local_folder=$ROOT" | head -1)
    [ -n "$CID" ] || { echo "devcontainer を起動できませんでした" >&2; exit 1; }
  fi
}

# コンテナの中でコマンドを実行する(ワークスペースを作業ディレクトリにして node ユーザーで)
in_container() {
  local tty=(-i); [ -t 0 ] && [ -t 1 ] && tty=(-it)
  docker exec "${tty[@]}" -e RCT_METRO_PORT="$PORT" -u node -w "/workspaces/$(basename "$ROOT")" "$CID" "$@"
}

# ネイティブ部分(依存の native コード、app.json、config plugin など)の fingerprint
native_fingerprint() {
  in_container npx fingerprint fingerprint:generate --platform android 2>/dev/null </dev/null \
    | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.parse(d).hash))"
}
