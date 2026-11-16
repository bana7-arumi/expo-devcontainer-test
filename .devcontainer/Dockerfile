FROM mcr.microsoft.com/devcontainers/javascript-node:26-trixie

# JDK は devcontainer.json の features(java)で入れる。
# Android SDK のパッケージ(platform / build-tools / NDK / CMake など)のバージョンはここでは決めない。
# 必要なバージョンは RN / Expo のバージョンで変わるので、ビルド時に Android Gradle Plugin が
# プロジェクトの設定を見て、足りないものを自動で入れる(ライセンスへの同意は postCreateCommand で行う)。
# SDK 本体は名前付きボリューム(devcontainer.json の mounts)に置くので、一度入れたものはコンテナを作り直しても残る。
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${PATH}:/opt/android-cmdline-tools/latest/bin

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

# cmdline-tools(sdkmanager)は SDK ボリュームの外に置き、イメージの更新がそのまま反映されるようにする。
# ライセンスへの同意と手動の SDK 操作に使うだけなので、バージョンは何でもよい。
ARG CMDLINE_TOOLS_VERSION=13114758
RUN mkdir -p /opt/android-cmdline-tools \
    && curl -fsSL -o /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /opt/android-cmdline-tools \
    && mv /opt/android-cmdline-tools/cmdline-tools /opt/android-cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip \
    && mkdir -p ${ANDROID_HOME} && chmod 777 ${ANDROID_HOME}

# Maestro CLI(E2E テスト)をコンテナ内で使う場合は、次のコメントを外す。
# コンテナから Windows の adb サーバーに届く必要があるので、WSL のミラーモードが前提(README の「補足」を参照)。
# NAT モードのままの場合は、Maestro は Windows 側で動かす(scripts/e2e.sh)。
# MAESTRO_VERSION が空なら、イメージをビルドした時点の最新版が入る。固定したい場合は devcontainer.json の
# build.args で指定する(例: "args": { "MAESTRO_VERSION": "2.12.1" })。
# devcontainer.json の containerEnv にある Maestro 用の設定のコメントも、あわせて外す。
# ENV MAESTRO_DIR=/opt/maestro
# ENV PATH=${PATH}:${MAESTRO_DIR}/bin
# ARG MAESTRO_VERSION=
# RUN url=https://github.com/mobile-dev-inc/maestro/releases/latest/download/maestro.zip \
#     && if [ -n "${MAESTRO_VERSION}" ]; then url=https://github.com/mobile-dev-inc/maestro/releases/download/cli-${MAESTRO_VERSION}/maestro.zip; fi \
#     && curl -fsSL -o /tmp/maestro.zip "$url" \
#     && unzip -q /tmp/maestro.zip -d /tmp \
#     && mv /tmp/maestro ${MAESTRO_DIR} \
#     && rm /tmp/maestro.zip

# 名前付きボリュームのマウント先(ボリュームを初めて作るときに、ここの権限を引き継ぐ)
RUN mkdir -p /home/node/.gradle /home/node/.claude && chmod 777 /home/node/.gradle
