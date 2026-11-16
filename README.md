# Expo 開発環境(devcontainer + WSL2 + Windows の adb)

Expo アプリの開発環境をコンテナ(devcontainer)の中に作り、**development build(expo-dev-client)** を Windows 側のエミュレーターや USB でつないだ実機で動作確認するための構成です。Expo Go は使いません。

## 前提条件

| 場所 | 必要なもの |
| --- | --- |
| Windows | Android SDK(`adb.exe`, エミュレーター)。Android Studio で入れたもので OK |
| WSL2 (Ubuntu) | Docker Engine、Node.js(`scripts/` のスクリプトの実行に使う)、curl |
| VS Code | 拡張機能「Dev Containers」「WSL」 |

WSL から `adb.exe devices` が実行できることを確認しておいてください。

## 構成

```
[WSL2] ./scripts/dev.sh <serial>   ← 普段はこれだけ実行する
   ├─ docker exec ─> [コンテナ] devcontainer の起動、APK のビルド(必要なときだけ)、Metro :8081(--network=host)
   └─ adb.exe ────> [Windows の adb] APK のインストール(必要なときだけ)、adb reverse tcp:8081、アプリを開く
                         │
                  [エミュレーター / USB 実機] dev client が 127.0.0.1:8081 の Metro に接続
```

- コンテナからは Windows の adb サーバーに届かない(WSL が NAT モードで、adb サーバーをネットワークに公開しないため)ので、端末の操作は WSL から `adb.exe` で行います。ビルドと Metro はコンテナ内で動かします。`scripts/dev.sh` がこの 2 つをまとめて扱うので、WSL とコンテナを行き来する必要はありません。
- **Android SDK のパッケージのバージョンは固定していません。** platform / build-tools / NDK / CMake は、ビルド時に Android Gradle Plugin がプロジェクト(RN / Expo のバージョン)に必要なものを自動で入れます。RN / Expo をアップグレードしても Dockerfile を変える必要はありません。入れたものは名前付きボリューム `expo-devcontainer-android-sdk` に残るので、ダウンロードは初回だけです(NDK などで数 GB あります)。

## 主なファイル

| ファイル | 内容 |
| --- | --- |
| `.devcontainer/Dockerfile` | `javascript-node:26-trixie` + Android cmdline-tools(SDK のパッケージは入れない) |
| `.devcontainer/devcontainer.json` | features(JDK 17、Claude Code)、ホストネットワーク、Android SDK・Gradle・Claude Code 用のボリューム、作成時のライセンス同意と `npm install` |
| `scripts/dev.sh` | 開発の入り口。コンテナの起動、ビルド、インストール、Metro の起動、アプリを開くところまでを行う |
| `scripts/e2e.sh` | Windows の Maestro で `.maestro/` の E2E テストを流す |
| `scripts/lib.sh` | スクリプト共通の処理 |
| `.maestro/` | Maestro の flow ファイル |

`android/` は Git 管理外で、ビルドのたびに `expo prebuild` で `app.json` の内容が反映されます。ただし既存の `android/` に上書き・合成するだけなので、config plugin を外したときや `android.package` を変えたときなどは、コンテナ内で `npx expo prebuild --clean --platform android --no-install` を実行してから `./scripts/dev.sh --rebuild <serial>` を実行してください。ネイティブ側の設定は `app.json` か config plugin で変更してください。

## 使い方

### 1. 端末を用意する(Windows 側)
- **エミュレーター**: Android Studio の Device Manager から起動します。
- **実機**: 開発者オプションで「USB デバッグ」を ON にし、USB でつないで、表示されるダイアログで許可します。

### 2. 開発を始める(WSL で実行)
```bash
./scripts/dev.sh <serial> [<serial>...]   # 指定した端末で開発する
./scripts/dev.sh all                      # 接続中の全端末で開発する
./scripts/dev.sh                          # 使い方と、接続中の端末の一覧を表示する
```
次のことを順に行い、最後にこのターミナルで Metro が動き続けます(`r` でリロード、`Ctrl+C` で終了)。

1. devcontainer を起動する(起動済みなら何もしない)
2. **ネイティブ部分が前回のビルドから変わっていれば**、コンテナ内で development build をビルドする
   - 「変わったか」は `@expo/fingerprint` で判定します(ネイティブ依存の追加・更新、`app.json` のネイティブに関わる設定、config plugin など)。JS/TS だけの変更ではビルドしません。
   - 出力先: `android/app/build/outputs/apk/debug/app-debug.apk`(エミュレーター(x86_64)と実機(arm64-v8a)向けだけ)
3. 端末に入っている APK が古い、または入っていないときだけインストールする
4. `adb reverse tcp:8081 tcp:8081` を設定する
5. コンテナ内で Metro を起動し、準備ができたら端末で dev client を Metro につなぐ(Metro がすでに動いていれば、端末で開くだけにする)

あとは `App.tsx` などを編集すれば、Fast Refresh で端末にすぐ反映されます。端末をつなぎ直したときやエミュレーターを再起動したときは、`dev.sh` を実行し直してください(ビルドとインストールは必要なときしか行わないので、すぐ終わります)。

Metro のポートを変えたいときは `RCT_METRO_PORT=8082 ./scripts/dev.sh <serial>` のように指定します。`dev.sh` が起動した Metro は、`Ctrl+C` やターミナルを閉じたときに一緒に止まります。

ネイティブ部分が変わっていなくてもビルドし直したいときは `--rebuild` を付けます。
```bash
./scripts/dev.sh --rebuild <serial>
```

### VS Code でコンテナに入って作業する場合
コードの編集や `npm install`、`claude` などは、VS Code の「Dev Containers: Reopen in Container」で開いたコンテナ内のターミナルで行えます。`dev.sh` は同じコンテナを使います。コンテナ内で `npx expo start` を実行して Metro を動かしている場合でも、`dev.sh` はそれを使って端末で開くだけにします。

## Claude Code
features で Claude Code を入れています。コンテナ内のターミナルで `claude` を実行してください。
- 初回はログインが必要です。設定とログイン情報はボリューム `expo-devcontainer-claude` に保存されるので、コンテナを作り直してもログインし直す必要はありません。
- WSL 側の `~/.claude` とは別の設定です。

## E2E テスト(Maestro)
Maestro は **Windows 側**で動かします。Maestro は adb サーバー(`127.0.0.1:5037`)に直接つなぐので、Windows の adb を使う構成ではコンテナや WSL からはつながらないためです。flow ファイルはこのリポジトリの `.maestro/` に置きます。

### Windows に Maestro を入れる(初回のみ)
1. Java 17 以上が入っていることを確認する(PowerShell で `java -version`)
2. https://github.com/mobile-dev-inc/maestro/releases から最新の `maestro.zip` をダウンロードし、`%USERPROFILE%\.maestro` に展開する(`%USERPROFILE%\.maestro\bin\maestro.bat` があればよい)
3. `%USERPROFILE%\.maestro\bin` を Windows のユーザー環境変数 `Path` に追加する
4. WSL のターミナルを開き直し、`maestro.bat --version` が動くことを確認する

### テストを流す
1. 別のターミナルで `./scripts/dev.sh <serial>` を動かしておく
2. WSL で次を実行する
   ```bash
   ./scripts/e2e.sh <serial>                       # .maestro/ の flow をすべて流す
   ./scripts/e2e.sh <serial> .maestro/smoke.yaml   # 特定の flow だけ流す
   ```
   `adb reverse` の設定はスクリプトが行います。flow は `openLink` で dev client を Metro につないでから操作します(`.maestro/smoke.yaml` を参照)。

## 注意点
- Metro の URL は `127.0.0.1` になるように設定しています(`REACT_NATIVE_PACKAGER_HOSTNAME`)。そのため、USB でつないでいない端末からは使えません。

## Wi-Fi 経由で実機につなぎたい場合
WSL2 は標準では NAT モードなので、LAN 上のスマホから WSL の 8081 に直接は届きません。次のどちらかで対応します。

- **方法 A(簡単)**: トンネルを使う。`npx expo start --tunnel` を実行し、dev client で表示された URL を開く
- **方法 B**: WSL をミラーモードにする(末尾の「補足: WSL のミラーモードで、すべてをコンテナ内で行う場合」を参照)

## うまくいかないとき

| 症状 | 確認すること |
| --- | --- |
| dev client で Metro につながらない | Metro が動いているか(WSL で `curl localhost:8081/status` を実行して `packager-status:running` と返るか)。動いていれば `dev.sh` を再実行する |
| スクリプトが「adb がタイムアウトしました」で止まる | Windows の adb サーバーが固まっています。PowerShell で `taskkill /IM adb.exe /F` を実行してから再試行してください |
| ネイティブモジュールが見つからないというエラーが出る | `./scripts/dev.sh --rebuild <serial>` でビルドし直してインストールする |
| Windows から `localhost:8081` につながらない | `.wslconfig` で `localhostForwarding=false` になっていないか。`wsl --shutdown` で再起動してみる |
| ファイルを変えても反映されない | プロジェクトが WSL の ext4 上(`/home/...`)にあるか。`/mnt/c` 上だとファイルの変更を検知できない |
| ビルドで「license not accepted」と出る | コンテナ内で `yes \| sdkmanager --sdk_root=$ANDROID_HOME --licenses` を実行する |
| ビルドで「Unsupported class file major version」や JDK のバージョンエラーが出る | AGP が求める JDK が上がっています。`.devcontainer/devcontainer.json` の features `ghcr.io/devcontainers/features/java:1` の `"version": "17"` を新しいバージョンに変えて、コンテナを作り直す |
| SDK の容量を空けたい / SDK をまっさらにしたい | コンテナを止めてから `docker volume rm expo-devcontainer-android-sdk` を実行する(次のビルドで入れ直されます) |
| Gradle のビルドがメモリ不足で落ちる | `%UserProfile%\.wslconfig` の `memory=` で WSL に割り当てるメモリを増やす |

## 補足: WSL のミラーモードで、すべてをコンテナ内で行う場合

> この手順は、この環境ではまだ試していません(上の `dev.sh` を使う手順は確認済みです)。

WSL のネットワークを **ミラーモード** にすると、WSL とコンテナ(`--network=host`)の `127.0.0.1` が Windows の `127.0.0.1` と同じになります。そのためコンテナから、Windows の adb サーバー(`127.0.0.1:5037`)をそのまま使えます。adb サーバーはネットワークに公開しないままです。

この場合は、ビルド・インストール・Metro・端末での起動・Maestro まで、すべてをコンテナ内で行えます。WSL 側のスクリプトは不要になります。

### 1. WSL をミラーモードにする(Windows 側)
1. `%UserProfile%\.wslconfig` に次の内容を書く(ファイルがなければ作る)
   ```ini
   [wsl2]
   networkingMode=mirrored
   ```
2. PowerShell で `wsl --shutdown` を実行し、WSL を起動し直す(動いているコンテナと WSL のターミナルはすべて止まります)
3. Windows 側で adb サーバーを起動しておく(PowerShell で `adb start-server`。Android Studio やエミュレーターが起動していれば、すでに動いています)

元に戻すときは、`networkingMode=mirrored` の行を消して `wsl --shutdown` を実行します。

### 2. コンテナから adb が使えることを確認する(コンテナ内で実行)
```bash
$ANDROID_HOME/platform-tools/adb devices
```
Windows の `adb.exe devices` と同じ端末が出れば OK です。

- `platform-tools` は初回のビルドで SDK ボリュームに入ります。まだビルドしていなければ、先に `sdkmanager --sdk_root=$ANDROID_HOME platform-tools` で入れてください。
- `PATH` に `$ANDROID_HOME/platform-tools` を足しておくと便利です(`devcontainer.json` の `remoteEnv` などで設定します)。
- **コンテナ内で `adb kill-server` を実行しないでください。** Windows の adb サーバーが止まります。
- コンテナ内の adb と Windows の adb でバージョンが大きく違うと、コンテナ内の adb が Windows の adb サーバーを止めて、自分のサーバーを起動し直すことがあります。そうなったら、両方の platform-tools を新しいものにそろえてください。

### 3. 開発する(コンテナ内で実行)
```bash
# ビルド(接続した端末の ABI の分だけ)→ インストール → Metro 起動 → adb reverse → アプリを開く、をまとめて行う
npx expo run:android --device <端末名>

# 2 回目以降で、ネイティブ部分が変わっていなければ Metro だけ起動する
npx expo start          # a で端末で開く、shift+a で端末を選ぶ
```
- エミュレーターは Windows 側で起動しておいてください(コンテナからは起動できません)。
- `expo run:android` は `adb reverse` も自動で設定するので、`REACT_NATIVE_PACKAGER_HOSTNAME=127.0.0.1` の設定はそのままで使えます。

### 4. Maestro をコンテナ内で使う
`.devcontainer/Dockerfile` に Maestro をインストールする処理をコメントアウトして書いてあります。
1. `.devcontainer/Dockerfile` の Maestro のブロック(`# ENV MAESTRO_DIR=...` から `# && rm /tmp/maestro.zip` まで)のコメントを外す
2. `.devcontainer/devcontainer.json` の `containerEnv` で、`CLAUDE_CONFIG_DIR` の行の末尾に `,` を付け、Maestro 用の 2 行のコメントを外す
3. コンテナを作り直す(VS Code では「Dev Containers: Rebuild Container」)
4. コンテナ内で実行する
   ```bash
   maestro --device <serial> test .maestro
   ```

Maestro のバージョンを固定したい場合は、`devcontainer.json` の `build` に `"args": { "MAESTRO_VERSION": "2.12.1" }` のように指定します。指定しなければ、イメージをビルドした時点の最新版が入ります。

### 5. Wi-Fi 経由で実機につなぐ場合
ミラーモードでは、LAN 上の端末から PC の IP で Metro に届くようになります。
1. Hyper-V ファイアウォールで、WSL への TCP 8081 の受信を許可する(管理者の PowerShell で実行)
   ```powershell
   New-NetFirewallHyperVRule -Name Metro -DisplayName "Metro (WSL)" -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -Protocol TCP -LocalPorts 8081
   ```
2. `devcontainer.json` の `REACT_NATIVE_PACKAGER_HOSTNAME` を PC の LAN 上の IP に変えて(または設定を消して)、コンテナを作り直す
3. dev client で QR コードを読み取るか、`http://<PC の IP>:8081` を入力する
