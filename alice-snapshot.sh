#!/bin/bash
# Alice 快照工具：
#   -t  <tag>  在 chromium/src 创建 Git 快照，并备份补丁用到的 third_party 文件
#   -td <tag>  删除 Git tag 和 third_party tar 快照
#   -tl        列出已有快照
#   -h         显示帮助
#   01         等价于 -t alice-state-01

set -euo pipefail

echo "=== 创建快照 ==="

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CHROMIUM_ROOT="$SCRIPT_DIR/chromium/src"
PATCH_MODS_DIR="$SCRIPT_DIR/patches/mods"
THIRD_PARTY_BACKUP_DIR="$SCRIPT_DIR/backups/third_party"
TAG_PREFIX="${ALICE_SNAPSHOT_PREFIX:-}"

usage() {
    cat <<'EOF'
Alice 快照工具

用法:
  ./alice-snapshot.sh -t  alice-state-00
  ./alice-snapshot.sh -td alice-state-00
  ./alice-snapshot.sh -tl
  ./alice-snapshot.sh -h
  ./alice-snapshot.sh 01          # 等价于 -t alice-state-01

说明:
  -t   在 chromium/src 创建 Git snapshot commit/tag，
       并把 patches/mods 中 third_party/* 路径打包到
       backups/third_party/<tag>.tar
  -td  删除 chromium/src 中的 tag，并删除对应的 tar 快照
  -tl  列出 Git tag 和 third_party tar 快照

  如果 tag 只包含数字，会自动添加 alice-state- 前缀。
  例如输入 01，实际 tag 为 alice-state-01。

环境变量:
  ALICE_SNAPSHOT_PREFIX  可选 tag 前缀；设置后 -t 要求前缀，
                          -tl 也只列出此前缀
EOF
}

die() {
    echo "错误: $*" >&2
    exit 1
}

require_layout() {
    [ -d "$CHROMIUM_ROOT/.git" ] || die "不是 Chromium Git 仓库: $CHROMIUM_ROOT"
    [ -d "$PATCH_MODS_DIR" ] || die "补丁目录不存在: $PATCH_MODS_DIR"
}

normalize_tag() {
    local tag="$1"
    if [[ "$tag" =~ ^[0-9]+$ ]]; then
        printf 'alice-state-%s\n' "$tag"
    else
        printf '%s\n' "$tag"
    fi
}

validate_tag() {
    local tag="$1"
    if [ -n "$TAG_PREFIX" ]; then
        [[ "$tag" == "$TAG_PREFIX"* ]] || die "tag 必须以 ${TAG_PREFIX} 开头: $tag"
    fi
    [[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || die "tag 只能包含字母、数字、点、下划线和短横线: $tag"
    git -C "$CHROMIUM_ROOT" check-ref-format "refs/tags/$tag" >/dev/null ||
        die "非法 Git tag: $tag"
}

third_party_archive() {
    local tag="$1"
    printf '%s/%s.tar\n' "$THIRD_PARTY_BACKUP_DIR" "$tag"
}

create_snapshot() {
    local tag
    local archive
    local list_file
    local path_line path_value
    local -A seen=()

    tag=$(normalize_tag "$1")

    require_layout
    validate_tag "$tag"
    archive=$(third_party_archive "$tag")

    local conflict=0
    if git -C "$CHROMIUM_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
        echo "重名: Git tag 已存在: $tag" >&2
        conflict=1
    fi
    if [ -e "$archive" ]; then
        echo "重名: tar 快照已存在: $archive" >&2
        conflict=1
    fi
    if [ "$conflict" -ne 0 ]; then
        die "快照名已存在，已取消，不会覆盖"
    fi

    echo "创建 Git 快照: $tag"
    git -C "$CHROMIUM_ROOT" add -A
    git -C "$CHROMIUM_ROOT" commit -m "snapshot: $tag"
    git -C "$CHROMIUM_ROOT" tag "$tag"
    git -C "$CHROMIUM_ROOT" reset --mixed HEAD~1

    mkdir -p "$THIRD_PARTY_BACKUP_DIR"
    list_file=$(mktemp)

    while IFS= read -r path_line; do
        path_value="${path_line#*=}"
        path_value="${path_value%$'\r'}"
        path_value="${path_value#\"}"
        path_value="${path_value%\"}"
        path_value="${path_value#\'}"
        path_value="${path_value%\'}"

        case "$path_value" in
            third_party/*) ;;
            *) continue ;;
        esac

        [ -n "${seen[$path_value]:-}" ] && continue
        seen["$path_value"]=1

        if [ -e "$CHROMIUM_ROOT/$path_value" ] || [ -L "$CHROMIUM_ROOT/$path_value" ]; then
            printf '%s\n' "$path_value" >> "$list_file"
        else
            echo "警告: 快照时不存在，跳过: $path_value" >&2
        fi
    done < <(
        for patch_file in "$PATCH_MODS_DIR"/*.sh; do
            [ -f "$patch_file" ] || continue
            grep -hE '^[[:space:]]*path[0-9]+=' "$patch_file" || true
        done
    )

    if [ ! -s "$list_file" ]; then
        rm -f "$list_file"
        die "没有找到可备份的 third_party 文件"
    fi

    echo "创建 third_party tar 快照"
    tar -cpf "$archive" \
        -C "$CHROMIUM_ROOT" \
        --verbatim-files-from \
        --no-recursion \
        -T "$list_file"
    rm -f "$list_file"

    echo "Git tag:       $tag"
    echo "third_party:   $archive"
}

delete_snapshot() {
    local tag
    local archive

    tag=$(normalize_tag "$1")

    require_layout
    validate_tag "$tag"
    archive=$(third_party_archive "$tag")

    if git -C "$CHROMIUM_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
        git -C "$CHROMIUM_ROOT" tag -d "$tag"
    else
        echo "警告: Git tag 不存在: $tag"
    fi

    if [ -e "$archive" ]; then
        rm -f "$archive"
        echo "已删除: $archive"
    else
        echo "警告: tar 快照不存在: $archive"
    fi
}

list_snapshots() {
    local -A tags=()
    local tag archive file

    require_layout

    while IFS= read -r tag; do
        [ -n "$tag" ] && tags["$tag"]=1
    done < <(git -C "$CHROMIUM_ROOT" tag -l "${TAG_PREFIX}*")

    if [ -d "$THIRD_PARTY_BACKUP_DIR" ]; then
        while IFS= read -r file; do
            tag=$(basename "$file" .tar)
            tags["$tag"]=1
        done < <(find "$THIRD_PARTY_BACKUP_DIR" -maxdepth 1 -type f -name "${TAG_PREFIX}*.tar" -print)
    fi

    if [ ${#tags[@]} -eq 0 ]; then
        echo "没有快照"
        return 0
    fi

    echo "快照列表:"
    while IFS= read -r tag; do
        archive=$(third_party_archive "$tag")
        if git -C "$CHROMIUM_ROOT" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
            printf '%s  git=有' "$tag"
        else
            printf '%s  git=无' "$tag"
        fi
        if [ -f "$archive" ]; then
            printf '  tar=有\n'
        else
            printf '  tar=无\n'
        fi
    done < <(printf '%s\n' "${!tags[@]}" | sort)
}

case "${1:-}" in
    -t)
        [ $# -eq 2 ] || { usage; exit 1; }
        create_snapshot "$2"
        ;;
    -td)
        [ $# -eq 2 ] || { usage; exit 1; }
        delete_snapshot "$2"
        ;;
    -tl)
        [ $# -eq 1 ] || { usage; exit 1; }
        list_snapshots
        ;;
    [0-9]*)
        [[ "$1" =~ ^[0-9]+$ ]] || { usage; exit 1; }
        [ $# -eq 1 ] || { usage; exit 1; }
        create_snapshot "$1"
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac