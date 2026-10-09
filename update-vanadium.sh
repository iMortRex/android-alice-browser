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

# 3. 恢复 Chromium 源码到干净状态
echo "=== 恢复 Chromium ==="
cd "$CHROMIUM"
git am --abort 2>/dev/null || true
rm -rf .git/rebase-apply .git/rebase-merge
git checkout -- .
git clean -fdx
VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' "$SCRIPT_DIR/vanadium/args.gn")
git reset --hard "$VERSION"
echo "Chromium 版本: $VERSION"

# 4. 应用 vanadium 补丁（带 replace）
rm -rf $SCRIPT_DIR/vanadium/patches/*trichrome-{apk-build-targets,browser-apk-targets}.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*{detailed,supported}-language*.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*javascript-optimizer-{site-setting,settings-UI}.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*component-updates.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*{pdf,PDF,for-content-public,toolbar-button,configs-from-config-app,config-app-parsing,new-tab-card,predictive-back}*.patch
# rm -rf $SCRIPT_DIR/vanadium/patches/*crashpad*.patch
replace "$SCRIPT_DIR/vanadium/patches" "VANADIUM" "ALICE"
replace "$SCRIPT_DIR/vanadium/patches" "Vanadium" "Alice"
replace "$SCRIPT_DIR/vanadium/patches" "vanadium" "alice"
git am --whitespace=nowarn --keep-non-patch $SCRIPT_DIR/vanadium/patches/*.patch