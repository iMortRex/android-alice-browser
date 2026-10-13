#!/bin/bash
# components_strings.grd.gritdeps：alice/ 条目必须排在最前（grit 按字典序生成）

set -e

F="components/components_strings.grd.gritdeps"
[ -f "$F" ] || exit 100

ALICE_LINE=$(grep '^alice/' "$F" || true)

# 没有 alice 条目，或已经排好（注释行之后第一行就是它）→ 跳过
if [ -z "$ALICE_LINE" ]; then exit 100; fi
if [ "$(sed -n '/^[^#]/{p;q;}' "$F")" = "$ALICE_LINE" ]; then exit 100; fi

# 先把原位置的条目删掉，再放到文件最前面（grit 校验会忽略 # 注释行）
grep -vxF "$ALICE_LINE" "$F" > "$F.tmp"
sed -i "1i ${ALICE_LINE}" "$F.tmp"
mv "$F.tmp" "$F"