#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"

# 确保 depot_tools 在 PATH
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

# 进入 Chromium 源码
cd "$CHROMIUM"

# 应用补丁
source $SCRIPT_DIR/alice-patch.sh

# 增量编译
echo "=== 增量编译 ==="
autoninja -C out/Default chrome_public_apk

APK="$CHROMIUM/out/Default/apks/ChromePublic.apk"
echo "=== 编译成功 ==="
echo "手动安装指令:"
echo "adb.exe install -r $APK"
echo "正在安装"
adb.exe install -r $APK
echo "安装完成"
pactl set-sink-volume @DEFAULT_SINK@ 200% 2>/dev/null
paplay "/mnt/c/Windows/Media/Windows Unlock.wav"
pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null

# 找 APK
# APK="$CHROMIUM/out/Default/apks/ChromePublic.apk"
# if [ -f "$APK" ]; then
#     echo ""
#     echo "=== 编译成功 ==="
#     echo "APK: $APK"
#     echo "安装: adb.exe install -r $APK"
# else
#     echo "编译失败：找不到 APK"
#     exit 1
# fi