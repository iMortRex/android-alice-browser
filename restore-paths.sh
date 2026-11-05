#!/bin/bash
# restore_paths.sh — 从给定的 .sh 补丁脚本中提取 pathN=... 变量，逐个执行
#                    git checkout <ref> -- <path>
#
# 用法:
#   ./restore_paths.sh                         无参数: 重置工作区到基准 ref
#   ./restore_paths.sh <patch.sh> [git-ref]    按补丁恢复路径
#
# 参数:
#   patch.sh    包含 path1="..." path2="..." 等变量定义的补丁脚本
#   git-ref     要恢复的 ref（默认: alice-state-01）
#
# 环境变量:
#   GIT_ROOT=...       手动指定 git 仓库根（默认: $HOME/android-alice-browser）
#   DRY_RUN=1          只打印将执行的命令，不实际执行
#   ARP_BASE_REF=...   无参数重置时使用的基准 ref（默认: alice-state-01）
#   BATCH_SIZE=...     每次 git checkout 传入的路径数（默认: 500）
#
# 说明:
#   脚本可在任意目录执行，仓库根默认固定为 $HOME/android-alice-browser，
#   可用 GIT_ROOT 覆盖。
#
# 示例:
#   ./restore_paths.sh                                   # 重置工作区
#   ./restore_paths.sh patches/mods/0023-*.sh
#   ./restore_paths.sh patches/mods/0023-*.sh alice-state-01
#   DRY_RUN=1 ./restore_paths.sh
#   ARP_BASE_REF=alice-state-00 ./restore_paths.sh
#   GIT_ROOT=/other/repo ./restore_paths.sh -n
#   BATCH_SIZE=200 ./restore_paths.sh patches/mods/0033-*.sh
#
# 退出码:
#   0  全部成功
#   1  参数/环境错误
#   2  有路径 checkout 失败

set -euo pipefail

usage() {
    sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

dry_run="${DRY_RUN:-0}"
git_ref="${2:-alice-state-01}"

# 仓库根：默认 $HOME/android-alice-browser，可用 GIT_ROOT 覆盖
DEFAULT_GIT_ROOT="${HOME:?错误: 环境变量 HOME 未设置}/android-alice-browser/chromium/src"

# ---------------------------------------------------------------------------
# 定位 git 仓库根
#   默认 $HOME/android-alice-browser，可用 GIT_ROOT 覆盖。
#   不依赖当前工作目录，任意目录执行都能找到。
#   要求：目录存在、是 git 仓库、包含指定 ref。
# ---------------------------------------------------------------------------
find_git_root() {
    local root="${GIT_ROOT:-$DEFAULT_GIT_ROOT}"
    local top

    if [[ ! -d "$root" ]]; then
        echo "错误: 仓库目录不存在: $root" >&2
        echo "默认是 \$HOME/android-alice-browser，可用 GIT_ROOT=... 覆盖" >&2
        return 1
    fi

    top=$(cd "$root" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || {
        echo "错误: 不是 git 仓库: $root" >&2
        return 1
    }

    if ! git -C "$top" rev-parse --verify --quiet "$git_ref" >/dev/null 2>&1; then
        echo "错误: 仓库 $top 不包含 ref '$git_ref'" >&2
        echo "请用第二个参数指定正确的 ref，或用 GIT_ROOT=... 指定仓库根" >&2
        return 1
    fi

    printf '%s\n' "$top"
}

# ---------------------------------------------------------------------------
# 无参数：默认重置工作区到基准 ref
#   git checkout <base_ref> -- .
#   git clean -fd
#   ⚠️ clean -fd 会删除未跟踪文件，补丁文件请先 git add 或用 DRY_RUN=1 预演
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    base_ref="${ARP_BASE_REF:-alice-state-01}"
    git_ref="$base_ref"
    git_root=$(find_git_root) || exit 1

    echo "==> 重置工作区"
    echo "仓库根目录: $git_root"
    echo "基准 ref:   $base_ref"
    echo "----------------------------------------"
    if [[ "$dry_run" == "1" ]]; then
        printf '    [dry-run] git -C "%s" checkout "%s" -- .\n' "$git_root" "$base_ref"
        printf '    [dry-run] git -C "%s" clean -fd\n' "$git_root"
    else
        git -C "$git_root" checkout "$base_ref" -- . || {
            echo "错误: git checkout $base_ref -- . 失败" >&2
            exit 1
        }
        git -C "$git_root" clean -fd || {
            echo "错误: git clean -fd 失败" >&2
            exit 1
        }
        echo "完成 ✓"
    fi
    exit 0
fi

src_file="$1"
[[ -f "$src_file" ]] || { echo "错误: 文件不存在: $src_file" >&2; exit 1; }

git_root=$(find_git_root) || exit 1

# ---------------------------------------------------------------------------
# 从补丁脚本里提取 pathN=...（逐行解析，不 source）
# ---------------------------------------------------------------------------
paths=()
while IFS= read -r line; do
    val="${line#*=}"
    val="${val%$'\r'}"
    val="${val#\"}"; val="${val%\"}"
    val="${val#\'}"; val="${val%\'}"
    [[ -n "$val" ]] && paths+=("$val")
done < <(grep -E '^[[:space:]]*path[0-9]+=' "$src_file")

total=${#paths[@]}
[[ $total -gt 0 ]] || { echo "错误: 未在 $src_file 中找到 pathN 变量" >&2; exit 1; }

echo "补丁文件:   $src_file"
echo "仓库根目录: $git_root"
echo "git ref:    $git_ref"
echo "路径数量:   $total"
[[ "$dry_run" == "1" ]] && echo "模式:       DRY_RUN（仅打印，不执行）"
echo "----------------------------------------"

# ---------------------------------------------------------------------------
# 批量 checkout：先逐条打印路径，再把整批路径交给一条 git checkout。
#   批量执行比逐个 checkout 快一个数量级，且避免并发抢 index.lock。
#   整批失败时回退逐个执行，以精确定位失败路径。
# ---------------------------------------------------------------------------
batch_size="${BATCH_SIZE:-500}"
fail=0

if [[ "$dry_run" == "1" ]]; then
    i=0
    for p in "${paths[@]}"; do
        i=$((i + 1))
        printf "[%2d/%d] %s\n" "$i" "$total" "$p"
        printf '        → git -C "%s" checkout "%s" -- "%s"\n' "$git_root" "$git_ref" "$p"
    done
else
    idx=0
    while (( idx < total )); do
        batch=( "${paths[@]:idx:batch_size}" )
        n=${#batch[@]}

        echo "----------------------------------------"
        for (( k=0; k<n; k++ )); do
            printf "[%2d/%d] %s\n" "$((idx + k + 1))" "$total" "${batch[k]}"
        done
        echo "--> 批量 checkout $n 个路径 ..."

        if git -C "$git_root" checkout "$git_ref" -- "${batch[@]}"; then
            changed=$(git -C "$git_root" diff --name-status "$git_ref" -- "${batch[@]}" || true)
            if [[ -n "$changed" ]]; then
                echo "  ⚠ 仍与 ref 有差异：" >&2
                printf '%s\n' "$changed" | sed 's/^/    /' >&2
            fi
        else
            echo "  批量失败，回退逐个执行以定位失败路径" >&2
            for p in "${batch[@]}"; do
                if ! git -C "$git_root" checkout "$git_ref" -- "$p"; then
                    echo "  ✗ $p" >&2
                    fail=$((fail + 1))
                fi
            done
        fi

        idx=$((idx + n))
    done
fi

pactl set-sink-volume @DEFAULT_SINK@ 200% 2>/dev/null
paplay "/mnt/c/Windows/Media/Windows Notify.wav"
pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null

echo "----------------------------------------"
if [[ $fail -eq 0 ]]; then
    echo "完成 ✓"
    exit 0
else
    echo "完成，但有 $fail 个路径失败 ✗" >&2
    exit 2
fi