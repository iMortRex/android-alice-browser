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

# 应用 patches
echo "=== 应用 patch ==="
if [ -d "$SCRIPT_DIR/patches" ]; then
    for p in "$SCRIPT_DIR"/patches/*.patch; do
        [ -f "$p" ] || continue

        # 已应用就跳过
        if git apply --reverse --check "$p" 2>/dev/null; then
            echo "已应用，跳过: $(basename "$p")"
            continue
        fi

        # 没应用，正式应用
        echo "应用: $(basename "$p")"
        git apply --whitespace=nowarn "$p" || {
            echo "应用失败: $p"
            exit 1
        }
    done
fi

# 应用 mod
echo "=== 应用 mod ==="
if [ -d "$SCRIPT_DIR/patches/mods" ]; then
    for m in "$SCRIPT_DIR"/patches/mods/*.sh; do
        [ -f "$m" ] || continue
        name=$(basename "$m")

        # 临时禁用 set -e
        set +e
        bash "$m"
        code=$?
        set -e

        case $code in
            0)   echo "应用: $name" ;;
            100) echo "已应用，跳过: $name" ;;
            *)   echo "应用失败: $name (exit=$code)"
                 exit 1 ;;
        esac
    done
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
    echo "安装:"
    echo "adb.exe install -r $APK"
else
    echo "编译失败：找不到 APK"
    exit 1
fi