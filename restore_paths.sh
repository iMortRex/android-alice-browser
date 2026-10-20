#!/bin/bash
# restore_paths.sh — 从给定的 .sh 补丁脚本中提取 pathN=... 变量，逐个执行
#                    git checkout <ref> -- <path>
#
# 用法:
#   ./restore_paths.sh <patch.sh> [git-ref]
#
# 参数:
#   patch.sh    包含 path1="..." path2="..." 等变量定义的补丁脚本
#   git-ref     要恢复的 ref（默认: alice-state-01）
#
# 环境变量:
#   GIT_ROOT=...   手动指定 git 仓库根（默认自动探测 chromium/src）
#   DRY_RUN=1      只打印将执行的命令，不实际执行
#
# 示例:
#   ./restore_paths.sh patches/mods/0023-bottom-navbar-edge-to-edge.sh
#   ./restore_paths.sh patches/mods/0023-bottom-navbar-edge-to-edge.sh alice-state-02
#   DRY_RUN=1 ./restore_paths.sh patches/mods/0023-bottom-navbar-edge-to-edge.sh
#   GIT_ROOT=./chromium/src ./restore_paths.sh patches/mods/0023-bottom-navbar-edge-to-edge.sh
#
# 退出码:
#   0  全部成功
#   1  参数/环境错误
#   2  有路径 checkout 失败

set -euo pipefail

usage() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

[[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

src_file="$1"
git_ref="${2:-alice-state-01}"
dry_run="${DRY_RUN:-0}"

[[ -f "$src_file" ]] || { echo "错误: 文件不存在: $src_file" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 定位 git 仓库根
#   候选顺序（GIT_ROOT 未设置时）：
#     1) <脚本目录>/chromium/src
#     2) ./chromium/src
#     3) ../chromium/src
#     4) <脚本目录>
#     5) .
#     6) ..
#   对每个候选：必须是 git 仓库，且必须包含指定的 git_ref，否则跳过。
#   这样可以避免命中外层管理脚本自身的仓库。
# ---------------------------------------------------------------------------
find_git_root() {
    local script_dir d root
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    local -a candidates=()
    if [[ -n "${GIT_ROOT:-}" ]]; then
        candidates=("$GIT_ROOT")
    else
        candidates=(
            "$script_dir/chromium/src"
            "./chromium/src"
            "../chromium/src"
            "$script_dir"
            "."
            ".."
        )
    fi

    local -a seen_without_ref=()
    for d in "${candidates[@]}"; do
        [[ -d "$d" ]] || continue
        root=$(cd "$d" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || continue
        if git -C "$root" rev-parse --verify --quiet "$git_ref" >/dev/null 2>&1; then
            printf '%s\n' "$root"
            return 0
        fi
        seen_without_ref+=("$root")
    done

    if [[ ${#seen_without_ref[@]} -gt 0 ]]; then
        {
            echo "错误: 以下 git 仓库均不包含 ref '$git_ref':" >&2
            printf '  - %s\n' "${seen_without_ref[@]}" | awk '!seen[$0]++' >&2
            echo "请用第二个参数指定正确的 ref，或用 GIT_ROOT=... 指定仓库根" >&2
        }
    else
        echo "错误: 未找到任何 git 仓库（可用 GIT_ROOT=... 指定）" >&2
    fi
    return 1
}

git_root=$(find_git_root) || exit 1

# ---------------------------------------------------------------------------
# 从补丁脚本里提取 pathN=...
#   逐行解析，不 source，避免误执行补丁中的 sed/grep 逻辑
# ---------------------------------------------------------------------------
paths=()
while IFS= read -r line; do
    val="${line#*=}"                   # 去掉 pathN= 前缀
    val="${val%$'\r'}"                 # 去掉可能的 CR
    val="${val#\"}"; val="${val%\"}"   # 去双引号
    val="${val#\'}"; val="${val%\'}"   # 去单引号
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

fail=0
i=0
for p in "${paths[@]}"; do
    i=$((i + 1))
    printf "[%2d/%d] %s\n" "$i" "$total" "$p"
    if [[ "$dry_run" == "1" ]]; then
        printf '        → git -C "%s" checkout "%s" -- "%s"\n' "$git_root" "$git_ref" "$p"
    else
        if git -C "$git_root" checkout "$git_ref" -- "$p"; then
            :
        else
            echo "        ✗ 失败" >&2
            fail=$((fail + 1))
        fi
    fi
done

echo "----------------------------------------"
if [[ $fail -eq 0 ]]; then
    echo "完成 ✓"
    exit 0
else
    echo "完成，但有 $fail 个路径失败 ✗" >&2
    exit 2
fi