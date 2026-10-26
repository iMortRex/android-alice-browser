#!/bin/bash
#
# path-check.sh
#
# 用法: path-check.sh <路径片段>
#
# 在 patches/mods/ 目录下的所有文件中查找包含指定路径的文件，
# 并列出命中的文件与行号。
#
# 示例:
#   ./path-check.sh chrome/android/java/res/xml/appearance_preferences.xml
#
# 可自行设置别名:
#   alias pc='/path/to/path-check.sh'
#
# 退出码:
#   0  找到匹配
#   1  未找到匹配
#   2  参数错误 / 目录不存在
#

set -euo pipefail

usage() {
    printf '用法: %s <路径片段>\n' "${0##*/}" >&2
    printf '示例: %s chrome/android/java/res/xml/appearance_preferences.xml\n' "${0##*/}" >&2
    exit 2
}

# ---- 参数 ----
[[ $# -ge 1 ]] || usage
case $1 in
    -h|--help) usage ;;
esac
query=$1
[[ -n $query ]] || usage

# ---- 定位 patches/mods/ ----
script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
script_dir=$(dirname -- "$script_path")
mods_dir="$script_dir/patches/mods"

if [[ ! -d $mods_dir ]]; then
    printf '错误: 目录不存在: %s\n' "$mods_dir" >&2
    exit 2
fi

# ---- 查找 ----
# -r 递归 / -l 只列文件名 / -I 跳过二进制 / -F 固定字符串 / -Z 用 NUL 分隔文件名
hits=()
while IFS= read -r -d '' f; do
    # 排除本脚本自身
    [[ $f == "$script_path" ]] && continue
    [[ $(readlink -f -- "$f") == "$script_path" ]] && continue
    hits+=("$f")
done < <(grep -rlIFZ -- "$query" "$mods_dir" 2>/dev/null || true)

if [[ ${#hits[@]} -eq 0 ]]; then
    printf '未找到包含该路径的文件: %s\n' "$query"
    exit 1
fi

# ---- 输出 ----
printf '包含路径 "%s" 的文件（%d 个）:\n\n' "$query" "${#hits[@]}"
for f in "${hits[@]}"; do
    printf '%s\n' "${f#"$script_dir"/}"
    while IFS= read -r line; do
        printf '    %s\n' "$line"
    done < <(grep -nF -- "$query" "$f" || true)
    printf '\n'
done