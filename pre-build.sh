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

# # 应用patch
# echo "=== 应用 patch ==="
# if [ -d "$SCRIPT_DIR/patches" ]; then
#     for p in "$SCRIPT_DIR"/patches/*.patch; do
#         [ -f "$p" ] || continue
#         echo "Applying $p"
#         git apply --whitespace=nowarn "$p"
#     done
# fi

# # 应用mod
# echo "=== 应用 mod ==="
# if [ -d "$SCRIPT_DIR/patches/mods" ]; then
#     for m in "$SCRIPT_DIR"/patches/mods/*.sh; do
#         [ -f "$m" ] || continue
#         echo "Applying mod: $(basename "$m")"
#         bash "$m" || exit 1
#     done
# fi

# 应用 patch.sh
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    echo "=== 应用 common.sh ==="
    source "$SCRIPT_DIR/common.sh" || exit 1
fi
if [ -f "$SCRIPT_DIR/patch.sh" ]; then
    echo "=== 应用 patch.sh ==="
    source "$SCRIPT_DIR/patch.sh" || exit 1
fi

# 修正 gritdeps 里 alice 条目的位置
echo "=== 修正 gritdeps ==="
cd "$CHROMIUM"
for GRITDEPS in \
    "components/components_strings.grd.gritdeps" \
    ; do
    [ -f "$GRITDEPS" ] || continue
    head -1 "$GRITDEPS" | grep -q "^alice/" && continue
    ALICE_LINE=$(grep "^alice/" "$GRITDEPS" | head -1)
    [ -z "$ALICE_LINE" ] && continue
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