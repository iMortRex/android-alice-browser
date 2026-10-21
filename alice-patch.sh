#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shopt -s nullglob

# ---------- 应用 patches ----------
patch_files=("$PROJECT_DIR"/patches/*.patch)

applied=()   # 已应用
pending=()   # 可应用、待应用
skipped=()   # 冲突/未完成，本次不应用

for p in "${patch_files[@]}"; do
    [ -f "$p" ] || continue

    if git apply --reverse --check "$p" 2>/dev/null; then
        applied+=("$p")
    elif git apply --check --whitespace=nowarn "$p" 2>/dev/null; then
        pending+=("$p")
    else
        skipped+=("$p")
    fi
done

for p in "${applied[@]}"; do
    echo "已应用，跳过: $(basename "$p")"
done
for p in "${skipped[@]}"; do
    echo "跳过（未完成或冲突，暂不应用）: $(basename "$p")"
done

if [ ${#pending[@]} -gt 0 ]; then
    echo "=== 应用 patch ==="
    for p in "${pending[@]}"; do
        echo "应用: $(basename "$p")"
        git apply --whitespace=nowarn "$p" || {
            echo "应用失败: $p"
            exit 1
        }
    done
fi

# ---------- 应用 mods ----------
mod_files=("$PROJECT_DIR"/patches/mods/*.sh)

if [ ${#mod_files[@]} -gt 0 ]; then
    echo "=== 应用 mod ==="
    for m in "${mod_files[@]}"; do
        [ -f "$m" ] || continue
        name=$(basename "$m")

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