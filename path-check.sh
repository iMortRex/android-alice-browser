#!/bin/bash
#
# path-check.sh
#
# 用法:
#   path-check.sh <脚本.sh>      文件模式
#   path-check.sh <路径片段>      片段模式
#
# 文件模式:
#   在 patches/mods 下定位 <脚本.sh>，从它里面提取所有形如 "a/b/c" 的路径，
#   再遍历 patches/mods 下所有 .sh，若某个 .sh 包含其中某个路径，
#   就打印该 .sh 文件名 + 命中的那个路径（不打印行内容）。
#
# 片段模式:
#   在 patches/mods 下所有 .sh 中查找包含该路径片段的文件，打印命中行。
#
# 默认路径:
#   patches/mods  （相对于本脚本所在目录）
#
# 退出码:
#   0  找到匹配
#   1  未找到匹配 / 目标脚本中无路径
#   2  参数错误 / 目录不存在 / 目标文件不存在
#

set -euo pipefail

usage() {
    printf '用法: %s <脚本.sh | 路径片段>\n' "${0##*/}" >&2
    printf '示例:\n' >&2
    printf '  %s a.sh\n' "${0##*/}" >&2
    printf '  %s chrome/android/java/.../SettingsActivity.java\n' "${0##*/}" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
case $1 in
    -h|--help) usage ;;
esac

input=$1
[[ -n $input ]] || usage

# ---- 定位脚本自身与默认目录 ----
script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
script_dir=$(dirname -- "$script_path")

DEFAULT_SUBDIR="patches/mods"
mods_dir="$script_dir/$DEFAULT_SUBDIR"

if [[ ! -d $mods_dir ]]; then
    printf '错误: 目录不存在: %s\n' "$mods_dir" >&2
    exit 2
fi

# ---- 在默认目录下解析 .sh 文件 ----
resolve_target() {
    local in=$1
    local base
    base=$(basename -- "$in")

    if [[ -f $mods_dir/$in ]]; then
        readlink -f -- "$mods_dir/$in"; return 0
    fi
    if [[ -f $mods_dir/$base ]]; then
        readlink -f -- "$mods_dir/$base"; return 0
    fi

    local found=()
    while IFS= read -r -d '' f; do
        found+=("$f")
    done < <(find "$mods_dir" -type f -name "$base" -print0 2>/dev/null)

    if [[ ${#found[@]} -eq 1 ]]; then
        readlink -f -- "${found[0]}"; return 0
    elif [[ ${#found[@]} -gt 1 ]]; then
        printf '错误: %s 下找到多个同名文件，请指定子路径:\n' "$DEFAULT_SUBDIR" >&2
        local f
        for f in "${found[@]}"; do
            printf '  %s\n' "${f#"$script_dir"/}" >&2
        done
        return 2
    fi

    if [[ -f $in ]]; then
        readlink -f -- "$in"; return 0
    fi
    return 1
}

# ---- 模式一：文件模式 ----
# 从 target 中提取 pathN 与值的键值对（支持 = 或 : 分隔、带/不带引号），
# 遍历其它 .sh；若包含某值，输出 文件名 + "pathN: value"。
run_file_mode() {
    local target=$1

    # 提取 pathN[:=]值
    # 值支持: "..." / '...' / 无引号到空白为止
    # 先剔除 shebang 与整行注释，避免示例路径混进来
    # awk 保持出现顺序去重（重复定义的 pathN 只保留第一次）
    local target_pairs=()
    mapfile -t target_pairs < <(
        grep -vE '^[[:space:]]*(#!|#)' -- "$target" 2>/dev/null \
            | grep -oE 'path[0-9]+[[:space:]]*[:=][[:space:]]*("[^"]+"|'\''[^'\'']+'\''|[^[:space:]]+)' \
            | awk '!seen[$0]++'
    )

    if [[ ${#target_pairs[@]} -eq 0 ]]; then
        printf '在 %s 中未找到 path* 路径\n' "${target#"$script_dir"/}"
        return 1
    fi

    local found_any=0
    while IFS= read -r -d '' f; do
        local f_real
        f_real=$(readlink -f -- "$f")
        [[ $f_real == "$target" ]] && continue
        [[ $f_real == "$script_path" ]] && continue

        local matched=()
        local pair key value
        for pair in "${target_pairs[@]}"; do
            # key = 第一个 = 或 : 之前的部分（去掉空白）
            key=${pair%%[=:]*}
            key=${key//[[:space:]]/}
            # value = 第一个 = 或 : 之后的部分
            value=${pair#*[=:]}
            # 去掉前导空白
            value=${value#"${value%%[![:space:]]*}"}
            # 去掉成对引号
            if [[ $value == \"*\" ]]; then
                value=${value#\"}; value=${value%\"}
            elif [[ $value == \'*\' ]]; then
                value=${value#\'}; value=${value%\'}
            fi
            [[ -n $key && -n $value ]] || continue

            if grep -qF -- "$value" "$f" 2>/dev/null; then
                matched+=("$key: $value")
            fi
        done

        if [[ ${#matched[@]} -gt 0 ]]; then
            found_any=1
            printf '%s\n' "${f_real#"$script_dir"/}"
            local m
            for m in "${matched[@]}"; do
                printf '    %s\n' "$m"
            done
            printf '\n'
        fi
    done < <(find "$mods_dir" -type f -name '*.sh' -print0)

    if [[ $found_any -eq 0 ]]; then
        printf '未找到包含相同路径的 .sh 文件\n'
        return 1
    fi
    return 0
}

# ---- 模式二：片段模式 ----
run_fragment_mode() {
    local query=$1
    local found_any=0
    while IFS= read -r -d '' f; do
        local f_real
        f_real=$(readlink -f -- "$f")
        [[ $f_real == "$script_path" ]] && continue

        if grep -qF -- "$query" "$f" 2>/dev/null; then
            found_any=1
            printf '%s\n' "${f_real#"$script_dir"/}"
            local line
            while IFS= read -r line; do
                printf '    %s\n' "$line"
            done < <(grep -nF -- "$query" "$f")
            printf '\n'
        fi
    done < <(find "$mods_dir" -type f -name '*.sh' -print0)

    if [[ $found_any -eq 0 ]]; then
        printf '未找到包含该路径片段的 .sh 文件: %s\n' "$query"
        return 1
    fi
    return 0
}

# ---- 分流 ----
if [[ $input == *.sh ]]; then
    if ! target=$(resolve_target "$input"); then
        printf '错误: 在 %s 下找不到脚本: %s\n' "$DEFAULT_SUBDIR" "$input" >&2
        exit 2
    fi
    run_file_mode "$target"
else
    run_fragment_mode "$input"
fi