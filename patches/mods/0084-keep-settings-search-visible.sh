#!/bin/bash
# 设置搜索栏：单栏设置页进入任意子页时仍显示顶部搜索框。
# 搜索输入（FS_SEARCH）和搜索结果（FS_RESULTS）保持原有的隐藏行为。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/settings/search/SettingsSearchCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0084' "$path1"; then
    exit 100
fi

# 统一判断：普通设置浏览状态显示搜索框，搜索输入和结果状态继续隐藏。
sed -i '/^    private @Nullable View getHelpMenuView() {$/i\
    // Alice patch start 0084\
    /** Whether the search box should be visible outside the search and results states. */\
    private boolean shouldShowAliceSearchBox() {\
        return mFragmentState == FS_SETTINGS;\
    }\
    // Alice patch end 0084\
' "$path1"

# 单栏布局的头部和滑动状态更新不再限制为只在主设置页显示搜索框。
sed -i 's|^        searchBox.setVisibility(isShowingMainSettings() ? View.VISIBLE : View.GONE);$|        // Alice patch start 0084\
        searchBox.setVisibility(\
                shouldShowAliceSearchBox() ? View.VISIBLE : View.GONE);\
        // Alice patch end 0084|' "$path1"

# 初始化或恢复多栏容器时，直接打开的子页也显示搜索框。
sed -i 's|^                    searchBox.setVisibility(showingMain ? View.VISIBLE : View.GONE);$|                    // Alice patch start 0084\
                    searchBox.setVisibility(\
                            shouldShowAliceSearchBox() ? View.VISIBLE : View.GONE);\
                    // Alice patch end 0084|' "$path1"

# 进入子页和 Fragment 恢复时不再因为离开主设置页而隐藏搜索框。
sed -i 's|^\( *\)showUiInSingleColumn(searchBox, /\* show= \*/ false);$|\1// Alice patch start 0084\
\1showUiInSingleColumn(searchBox, shouldShowAliceSearchBox());\
\1// Alice patch end 0084|' "$path1"
sed -i 's|^\( *\)showUiInSingleColumn(searchBox, false);$|\1// Alice patch start 0084\
\1showUiInSingleColumn(searchBox, shouldShowAliceSearchBox());\
\1// Alice patch end 0084|' "$path1"

# 单栏布局切换时，只要仍在浏览设置就保持搜索框可见。
sed -i '/^            if (showingMain) {$/,/^            }$/c\
            // Alice patch start 0084\
            if (shouldShowAliceSearchBox()) {\
                searchBox.setVisibility(View.VISIBLE);\
            } else if (!showingMain) {\
                searchBox.setVisibility(View.GONE);\
                query.setVisibility(View.GONE);\
            }\
            // Alice patch end 0084' "$path1"

# 搜索状态下的旧注释与新行为保持一致。
sed -i '/^            \/\/ When switching from 2-column to single-column mode, we may be at non-main$/,/^            \/\/ the fragment to prevent fragments overlapping crbug.com\/511065590\.$/c\
            // Alice patch start 0084\
            // If search UI is active while browsing non-main settings during a layout\
            // switch, return to normal settings before continuing.\
            // Alice patch end 0084' "$path1"
