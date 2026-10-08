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

# 1. 先应用 patches（大段替换）
if [ -d "$SCRIPT_DIR/patches" ]; then
    for p in "$SCRIPT_DIR"/patches/*.patch; do
        [ -f "$p" ] || continue
        echo "Applying patch: $(basename "$p")"
        git apply --whitespace=nowarn "$p" || {
            echo "FAILED: $p"
            exit 1
        }
    done
fi

# 2. 再应用 mods（sed 微调）
if [ -d "$SCRIPT_DIR/mods" ]; then
    for m in "$SCRIPT_DIR"/mods/*.sh; do
        [ -f "$m" ] || continue
        echo "Applying mod: $(basename "$m")"
        bash "$m" || exit 1
    done
fi

# 3. 增量编译
echo "=== 增量编译 ==="
autoninja -C out/Default chrome_public_apk

# 4. 找 APK
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