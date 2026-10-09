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
if [ -f "$SCRIPT_DIR/patch.sh" ]; then
    echo "=== 应用 patch.sh ==="
    source "$SCRIPT_DIR/patch.sh" || exit 1
fi

# 修正所有 gritdeps 里 alice 条目的位置
echo "=== 修正 gritdeps ==="
cd "$CHROMIUM"
for GRITDEPS in $(grep -rl "^alice/" --include="*.gritdeps" . 2>/dev/null); do
    # 已在第一行，跳过
    head -1 "$GRITDEPS" | grep -q "^alice/" && continue

    ALICE_LINE=$(grep "^alice/" "$GRITDEPS" | head -1)
    sed -i "\|^${ALICE_LINE}$|d" "$GRITDEPS"
    sed -i "1i ${ALICE_LINE}" "$GRITDEPS"
    echo "Fixed: $GRITDEPS"
done

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