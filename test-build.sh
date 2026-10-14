#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"

# 确保 depot_tools 在 PATH
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

# 进入 Chromium 源码
cd "$CHROMIUM"

# 应用补丁
source "$SCRIPT_DIR/alice-patch.sh"

# 增量编译
echo "=== 增量编译 ==="
sed -i 's|^chrome_public_manifest_package = .*|chrome_public_manifest_package = "io.github.imortrex.alice.browser.test"|' out/Default/args.gn
autoninja -C out/Default chrome_public_apk
mkdir -p out/Test
cp out/Default/apks/ChromePublic.apk out/Test/ChromePublic.apk
sed -i 's|^chrome_public_manifest_package = .*|chrome_public_manifest_package = "io.github.imortrex.alice.browser"|' out/Default/args.gn

# ========== 签名 ==========
echo "=== 签名 ==="
source "$SCRIPT_DIR/common.sh"
APK="$CHROMIUM/out/Test/ChromePublic.apk"

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
mkdir -p out/Test
SIGNED_APK="out/Test/test-$VERSION-arm64-v8a.apk"
sign_apk "$APK" "$SIGNED_APK"
echo "已签名: $SIGNED_APK"

APK="$CHROMIUM/out/Test/apks/ChromePublic.apk"
echo "=== 编译成功 ==="
echo "手动安装指令:"
echo "adb.exe install -r "$SIGNED_APK""
echo "正在安装"
adb.exe install -r "$SIGNED_APK"
echo "安装完成"
pactl set-sink-volume @DEFAULT_SINK@ 200% 2>/dev/null
paplay "/mnt/c/Windows/Media/Windows Unlock.wav"
pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
