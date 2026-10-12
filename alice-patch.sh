#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "$SCRIPT_DIR"

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