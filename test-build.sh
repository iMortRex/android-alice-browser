#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"

# 确保 depot_tools 在 PATH
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

# 进入 Chromium 源码
cd "$CHROMIUM"

# 应用 patches
echo "=== 应用 patch ==="
if [ -d "$SCRIPT_DIR/patches" ]; then
    for p in "$SCRIPT_DIR"/patches/*.patch; do
        [ -f "$p" ] || continue

        # 已应用就跳过
        if git apply --reverse --check "$p" 2>/dev/null; then
            echo "已应用Patch，跳过: $(basename "$p")"
            continue
        fi

        echo "应用Patch: $(basename "$p")"
        git apply --whitespace=nowarn "$p" || { echo "失败: $p"; exit 1; }
    done
fi

# 应用 mod
echo "=== 应用 mod ==="
if [ -d "$SCRIPT_DIR/patches/mods" ]; then
    for m in "$SCRIPT_DIR"/patches/mods/*.sh; do
        [ -f "$m" ] || continue
        echo "应用mod: $(basename "$m")"
        bash "$m" || exit 1
    done
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
    echo "安装: adb install -r $APK"
else
    echo "编译失败：找不到 APK"
    exit 1
fi