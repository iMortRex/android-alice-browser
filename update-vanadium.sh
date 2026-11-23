#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"

export PATH="$SCRIPT_DIR/depot_tools:$PATH"

# 1. 恢复 vanadium 子模块（撤销上次的 replace 修改）
echo "=== 恢复 vanadium ==="
cd "$SCRIPT_DIR/vanadium"
git checkout -- .
git clean -fd
echo "补丁数量: $(ls patches/ | wc -l)"

# 2. 拉取 vanadium 最新 tag
echo "=== 更新 vanadium 到最新 tag ==="
git fetch --tags
LATEST_TAG=$(git tag | sort -V | tail -n1)
git checkout "$LATEST_TAG"
echo "当前 tag: $LATEST_TAG"
