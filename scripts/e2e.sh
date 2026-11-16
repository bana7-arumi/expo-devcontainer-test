#!/usr/bin/env bash
# WSL(コンテナの外)で実行する。Windows にインストールした Maestro で E2E テストを流す。
# 先に別のターミナルで ./scripts/dev.sh <serial> を動かしておくこと(ビルド・インストール・Metro はそちらで行う)。
#   使い方: ./scripts/e2e.sh <serial> [flow ファイル/ディレクトリ ...]   # 省略すると .maestro/ 全体
set -euo pipefail
source "$(dirname "$0")/lib.sh"
MAESTRO="${MAESTRO:-maestro.bat}"

[ $# -ge 1 ] && [ "$1" != "all" ] || { echo "使い方: $0 <serial> [flow ...](E2E は 1 台ずつ実行する)" >&2; list_devices | sed 's/^/  /' >&2; exit 1; }
resolve_serials "$1"; shift
flows=("$@"); [ ${#flows[@]} -gt 0 ] || flows=("$ROOT/.maestro")

command -v "$MAESTRO" >/dev/null || { echo "Windows に Maestro が見つかりません($MAESTRO)。README の手順でインストールしてください" >&2; exit 1; }
metro_running || { echo "Metro が動いていません。別のターミナルで ./scripts/dev.sh ${serials[0]} を実行してください" >&2; exit 1; }
adb -s "${serials[0]}" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null

win_flows=(); for f in "${flows[@]}"; do win_flows+=("$(wslpath -w "$f")"); done
# Windows 側の Maestro は Windows の adb サーバー(127.0.0.1:5037)を使う
cd /mnt/c && "$MAESTRO" --device "${serials[0]}" test "${win_flows[@]}"
