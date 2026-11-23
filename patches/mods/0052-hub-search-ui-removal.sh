#!/bin/bash
# Hub 底栏移动后移除搜索框和搜索入口。

set -e

path1="chrome/browser/hub/internal/android/res/values/dimens.xml"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubToolbarMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0052' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 将 Hub 搜索框高度清零。
sed -i 's|^\( *\)<dimen name="hub_search_box_height">40dp</dimen>$|\1<!-- Alice patch start 0052 -->\n\1<dimen name="hub_search_box_height">0dp</dimen>\n\1<!-- Alice patch end 0052 -->|' "$path1"

# 将 Hub 搜索框上下间距清零。
sed -i 's|^\( *\)<dimen name="hub_search_box_vertical_margin">8dp</dimen>$|\1<!-- Alice patch start 0052 -->\n\1<dimen name="hub_search_box_vertical_margin">0dp</dimen>\n\1<!-- Alice patch end 0052 -->|' "$path1"

# 隐藏 Hub 搜索框和搜索图标。
sed -i '/^                        mPropertyModel\.set(SEARCH_LOUPE_VISIBLE, isTablet);$/a\
                        // Alice patch start 0052\
                        mPropertyModel.set(SEARCH_BOX_VISIBLE, false);\
                        mPropertyModel.set(SEARCH_LOUPE_VISIBLE, false);\
                        // Alice patch end 0052' "$path2"

# 阻止搜索框再次被显示。
sed -i '/^    private void onSearchBoxVisibilityChange(Boolean shouldShow) {$/a\
        // Alice patch start 0052\
        shouldShow = false;\
        // Alice patch end 0052' "$path2"

# 将搜索点击监听替换为空操作。
sed -i 's|^        mPropertyModel\.set(SEARCH_LISTENER, this::onSearchClicked);$|        // Alice patch start 0052\n        mPropertyModel.set(SEARCH_LISTENER, () -> {});\n        // Alice patch end 0052|' "$path2"
