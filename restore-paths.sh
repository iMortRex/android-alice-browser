#!/bin/bash
# restore_paths.sh — 从给定的 .sh 补丁脚本中提取 pathN=... 变量，逐个执行
#                    git checkout <ref> -- <path>
#
# 用法:
#   ./restore_paths.sh                         无参数: 重置工作区到基准 ref
#   ./restore_paths.sh <patch.sh> [git-ref]    按补丁恢复路径
#   ./restore_paths.sh --all [git-ref]         全量恢复 Git 工作区，存在 tar 时还原
#
# 参数:
#   patch.sh    包含 path1="..." path2="..." 等变量定义的补丁脚本
#   --all       执行 git checkout <ref> -- .、git clean -fd、git reset -q，
#               存在 backups/third_party/<ref>.tar 时完整解开它
#   git-ref     要恢复的 ref（默认: alice-state-01）
#
# 环境变量:
#   GIT_ROOT=...       手动指定 git 仓库根（默认: $HOME/android-alice-browser）
#   DRY_RUN=1          只打印将执行的命令，不实际执行
#   ARP_BASE_REF=...   无参数重置时使用的基准 ref（默认: alice-state-01）
#   BATCH_SIZE=...     每次 git checkout 传入的路径数（默认: 500）
#   THIRD_PARTY_SNAPSHOT=...
#                      third_party 路径可选使用的 tar 快照
#                      （默认: backups/third_party/<git-ref>.tar）
#
# 说明:
#   脚本可在任意目录执行，仓库根默认固定为 $HOME/android-alice-browser，
#   可用 GIT_ROOT 覆盖。
#
# 示例:
#   ./restore_paths.sh                                   # 重置工作区
#   ./restore_paths.sh patches/mods/0023-*.sh
#   ./restore_paths.sh patches/mods/0023-*.sh alice-state-01
#   ./restore_paths.sh --all alice-state-00
#   DRY_RUN=1 ./restore_paths.sh
#   DRY_RUN=1 ./restore_paths.sh --all alice-state-00
#   ARP_BASE_REF=alice-state-00 ./restore_paths.sh
#   GIT_ROOT=/other/repo ./restore_paths.sh -n
#   BATCH_SIZE=200 ./restore_paths.sh patches/mods/0033-*.sh
#   THIRD_PARTY_SNAPSHOT=backups/third_party/other.tar ./restore_paths.sh patches/mods/0065-*.sh
#
# 退出码:
#   0  全部成功
#   1  参数/环境错误
#   2  有路径 checkout 失败

set -euo pipefail

usage() {
    sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

dry_run="${DRY_RUN:-0}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

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

    printf '%s\n' "$top"
}

# ---------------------------------------------------------------------------
# 无参数：默认重置工作区到基准 ref
#   git checkout <base_ref> -- .
#   git clean -fd
#   ⚠️ clean -fd 会删除未跟踪文件，补丁文件请先 git add 或用 DRY_RUN=1 预演
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 参数模式：
#   --all [git-ref]       全量恢复 Git 工作区和 third_party tar
#   <patch.sh> [git-ref]  恢复指定补丁路径
#   无参数                重置工作区到 ARP_BASE_REF
# ---------------------------------------------------------------------------
mode="patch"
if [[ "${1:-}" == "--all" ]]; then
    mode="all"
    if [[ $# -gt 2 ]]; then
        echo "错误: --all 最多接受一个 git-ref 参数" >&2
        usage
    fi
    git_ref="${2:-alice-state-01}"
elif [[ $# -lt 1 ]]; then
    base_ref="${ARP_BASE_REF:-alice-state-01}"
    git_ref="$base_ref"
    git_root=$(find_git_root) || exit 1

    if ! git -C "$git_root" rev-parse --verify --quiet "$base_ref" >/dev/null 2>&1; then
        echo "错误: 仓库 $git_root 不包含 ref '$base_ref'" >&2
        exit 1
    fi

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
else
    if [[ $# -gt 2 ]]; then
        echo "错误: 最多接受一个补丁文件和一个 git-ref 参数" >&2
        usage
    fi
    git_ref="${2:-alice-state-01}"
fi

third_party_snapshot="${THIRD_PARTY_SNAPSHOT:-$script_dir/backups/third_party/${git_ref}.tar}"

git_root=$(find_git_root) || exit 1

# ---------------------------------------------------------------------------
# --all：直接全量恢复 Git 工作区，然后完整解开对应的 third_party tar。
#   git checkout <ref> -- .
#   git clean -fd
#   git reset -q
#   tar -xpf <snapshot> -C <git-root>
#
# git clean -fd 会删除仓库内所有未跟踪、且未被 .gitignore 忽略的文件。
# git reset -q 必须在 clean 之后执行，否则快照中新增的文件会先变成未跟踪文件，
# 再被 clean -fd 删除。reset 只退索引，工作区仍保留快照内容。
# third_party tar 中可能包含普通 Git 不跟踪的文件，因此放在 Git 清理之后恢复。
# tar 不是必需项：不存在时只跳过 tar 恢复，不影响 Git 全量恢复。
# ---------------------------------------------------------------------------
if [[ "$mode" == "all" ]]; then
    if ! git -C "$git_root" rev-parse --verify --quiet "$git_ref" >/dev/null 2>&1; then
        echo "错误: 仓库 $git_root 不包含 ref '$git_ref'" >&2
        exit 1
    fi

    echo "恢复模式:   全量"
    echo "仓库根目录: $git_root"
    echo "git ref:    $git_ref"
    echo "tar 快照:   $third_party_snapshot"
    [[ "$dry_run" == "1" ]] && echo "模式:       DRY_RUN（仅打印，不执行）"
    echo "----------------------------------------"

    if [[ "$dry_run" == "1" ]]; then
        printf '    [dry-run] git -C "%s" checkout "%s" -- .\n' "$git_root" "$git_ref"
        printf '    [dry-run] git -C "%s" clean -fd\n' "$git_root"
        printf '    [dry-run] git -C "%s" reset -q\n' "$git_root"
        if [[ -f "$third_party_snapshot" ]]; then
            printf '    [dry-run] tar -xpf "%s" -C "%s"\n' \
                "$third_party_snapshot" "$git_root"
        else
            printf '    [dry-run] 跳过不存在的 tar: "%s"\n' "$third_party_snapshot"
        fi
    else
        git -C "$git_root" checkout "$git_ref" -- . || {
            echo "错误: git checkout $git_ref -- . 失败" >&2
            exit 1
        }
        git -C "$git_root" clean -fd || {
            echo "错误: git clean -fd 失败" >&2
            exit 1
        }
        git -C "$git_root" reset -q || {
            echo "错误: git reset -q 失败" >&2
            exit 1
        }
        if [[ -f "$third_party_snapshot" ]]; then
            tar -xpf "$third_party_snapshot" -C "$git_root" || {
                echo "错误: third_party tar 恢复失败: $third_party_snapshot" >&2
                exit 1
            }
        else
            echo "跳过 third_party tar: 不存在 $third_party_snapshot"
        fi
    fi

    if [[ "$dry_run" != "1" ]]; then
        pactl set-sink-volume @DEFAULT_SINK@ 200% 2>/dev/null
        paplay "/mnt/c/Windows/Media/Windows Notify.wav"
        pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
    fi

    echo "----------------------------------------"
    echo "完成 ✓"
    exit 0
fi

# ---------------------------------------------------------------------------
# 从补丁脚本里提取 pathN=...（逐行解析，不 source）
# ---------------------------------------------------------------------------
paths=()
declare -A seen_paths=()

append_paths_from_file() {
    local src_file="$1"
    local line val

    while IFS= read -r line; do
        val="${line#*=}"
        val="${val%$'\r'}"
        val="${val#\"}"; val="${val%\"}"
        val="${val#\'}"; val="${val%\'}"
        [[ -z "$val" ]] && continue
        [[ -n "${seen_paths[$val]+set}" ]] && continue
        seen_paths["$val"]=1
        paths+=("$val")
    done < <(grep -E '^[[:space:]]*path[0-9]+=' "$src_file" || true)
}

src_file="$1"
[[ -f "$src_file" ]] || { echo "错误: 文件不存在: $src_file" >&2; exit 1; }
append_paths_from_file "$src_file"
src_label="$src_file"

total=${#paths[@]}
[[ $total -gt 0 ]] || { echo "错误: 未在 $src_label 中找到 pathN 变量" >&2; exit 1; }

echo "补丁来源:   $src_label"
echo "仓库根目录: $git_root"
echo "git ref:    $git_ref"
echo "路径数量:   $total"
[[ "$dry_run" == "1" ]] && echo "模式:       DRY_RUN（仅打印，不执行）"
echo "----------------------------------------"

# ---------------------------------------------------------------------------
# 恢复路径：
#   third_party/* 在 tar 快照存在时从 tar 恢复单个路径。
#   其他路径使用批量 git checkout。
# ---------------------------------------------------------------------------
batch_size="${BATCH_SIZE:-500}"
fail=0
git_paths=()
third_party_paths=()

for p in "${paths[@]}"; do
    case "$p" in
        third_party/*) third_party_paths+=("$p") ;;
        *) git_paths+=("$p") ;;
    esac
done

if [[ ${#git_paths[@]} -gt 0 ]] &&
    ! git -C "$git_root" rev-parse --verify --quiet "$git_ref" >/dev/null 2>&1; then
    echo "错误: 仓库 $git_root 不包含 ref '$git_ref'" >&2
    exit 1
fi

if [[ "$dry_run" == "1" ]]; then
    i=0
    for p in "${paths[@]}"; do
        i=$((i + 1))
        printf "[%2d/%d] %s\n" "$i" "$total" "$p"
        case "$p" in
            third_party/*)
                if [[ -f "$third_party_snapshot" ]]; then
                    printf '        → tar -xpf "%s" -C "%s" -- "%s"\n' \
                        "$third_party_snapshot" "$git_root" "$p"
                else
                    printf '        → 跳过 third_party（tar 不存在）: %s\n' "$p"
                fi
                ;;
            *)
                printf '        → git -C "%s" checkout "%s" -- "%s"\n' \
                    "$git_root" "$git_ref" "$p"
                ;;
        esac
    done
else
    if [[ ${#third_party_paths[@]} -gt 0 ]]; then
        echo "----------------------------------------"
        if [[ -f "$third_party_snapshot" ]]; then
            echo "--> 从 tar 快照恢复 ${#third_party_paths[@]} 个 third_party 路径"
            echo "快照文件: $third_party_snapshot"

            for p in "${third_party_paths[@]}"; do
                echo "[tar] $p"
                if ! tar -xpf "$third_party_snapshot" -C "$git_root" -- "$p"; then
                    echo "  ✗ tar 恢复失败: $p" >&2
                    fail=$((fail + 1))
                fi
            done
        else
            echo "跳过 ${#third_party_paths[@]} 个 third_party 路径: tar 不存在"
            echo "快照文件: $third_party_snapshot"
        fi
    fi

    idx=0
    while (( idx < ${#git_paths[@]} )); do
        batch=( "${git_paths[@]:idx:batch_size}" )
        n=${#batch[@]}

        echo "----------------------------------------"
        for (( k=0; k<n; k++ )); do
            printf "[git %d/%d] %s\n" \
                "$((idx + k + 1))" "${#git_paths[@]}" "${batch[k]}"
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

if [[ "$dry_run" != "1" ]]; then
    pactl set-sink-volume @DEFAULT_SINK@ 200% 2>/dev/null
    paplay "/mnt/c/Windows/Media/Windows Notify.wav"
    pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
fi

echo "----------------------------------------"
if [[ $fail -eq 0 ]]; then
    echo "完成 ✓"
    exit 0
else
    echo "完成，但有 $fail 个路径失败 ✗" >&2
    exit 2
fi
