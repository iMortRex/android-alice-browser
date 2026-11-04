#!/bin/bash
set -e

# ---------- 音效 ----------
play_sound() {
    pactl set-sink-volume @DEFAULT_SINK@ 200% 2>/dev/null || true
    paplay "$1" 2>/dev/null || true
    pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || true
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"

# 确保 depot_tools 在 PATH
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

# 进入 Chromium 源码
cd "$CHROMIUM"

# 恢复干净（撤销上次所有 patch 和 mod 的修改）
echo "=== 恢复工作区 ==="
git reset -q
git checkout -- .
git clean -fd

# 应用 patch.sh
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    echo "=== 应用 common.sh ==="
    source "$SCRIPT_DIR/common.sh" || exit 1
fi
if [ -f "$SCRIPT_DIR/patch.sh" ]; then
    echo "=== 应用 patch.sh ==="
    source "$SCRIPT_DIR/patch.sh" || exit 1
fi

# 增量编译
echo "=== 增量编译 ==="
sed -i 's|^chrome_public_manifest_package = .*|chrome_public_manifest_package = "io.github.imortrex.alice.browser"|' out/Default/args.gn
if ! autoninja -C out/Default chrome_public_apk; then
    play_sound "/mnt/c/Windows/Media/Windows Critical Stop.wav"
    exit 1
fi

# ========== 签名 ==========
echo "=== 签名 ==="
source "$SCRIPT_DIR/common.sh"
APK="$CHROMIUM/out/Default/apks/ChromePublic.apk"

# 确保 keys 存在
if [ ! -f "$SCRIPT_DIR/keys/test.jks" ] || [ ! -f "$SCRIPT_DIR/keys/local.properties" ]; then
    echo "keys 不存在，从备份恢复..."
    mkdir -p "$SCRIPT_DIR/keys"
    cp ~/keys/test.jks "$SCRIPT_DIR/keys/" 2>/dev/null || {
        echo "错误：找不到 ~/keys/test.jks"
        exit 1
    }
    cp ~/keys/local.properties "$SCRIPT_DIR/keys/" 2>/dev/null || {
        echo "错误：找不到 ~/keys/local.properties"
        exit 1
    }
fi

# 设置签名环境
export PATH=$CHROMIUM/third_party/jdk/current/bin/:$PATH
export ANDROID_HOME=$CHROMIUM/third_party/android_sdk/public

VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' "$SCRIPT_DIR/vanadium/args.gn")
mkdir -p out/Release
SIGNED_APK="out/Release/$VERSION-arm64-v8a.apk"
sign_apk "$APK" "$SIGNED_APK"
echo "已签名: $SIGNED_APK"
play_sound "/mnt/c/Windows/Media/Windows Unlock.wav"

# 找 APK
APK="$CHROMIUM/$SIGNED_APK"
if [ -f "$APK" ]; then
    echo ""
    echo "=== 编译成功 ==="
    echo $(date +"%Y-%m-%d %H:%M:%S")
    echo "APK: $APK"
    echo "手动安装指令:"
    echo "adb.exe install -r $APK"
else
    echo "编译失败：找不到 APK"
    exit 1
fi