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