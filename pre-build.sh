#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"

# 确保 depot_tools 在 PATH
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

# 进入 Chromium 源码
cd "$CHROMIUM"

# 恢复干净（撤销上次所有 patch 和 mod 的修改）
echo "=== 恢复工作区 ==="
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
autoninja -C out/Default chrome_public_apk

# 找 APK
APK="$CHROMIUM/out/Default/apks/ChromePublic.apk"
if [ -f "$APK" ]; then
    echo ""
    echo "=== 编译成功 ==="
    echo "APK: $APK"
    echo "安装:"
    echo "adb.exe install -r $APK"
else
    echo "编译失败：找不到 APK"
    exit 1
fi