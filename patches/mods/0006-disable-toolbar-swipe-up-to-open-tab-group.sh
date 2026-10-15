#!/bin/bash
# 禁用上滑工具栏打开标签页管理

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/LayoutManagerChrome.java"

# 检测是否已应用
if grep -q 'Alice patch start 0006' "$path1"; then
    exit 100
fi

# 上滑工具栏不再打开标签页管理，改为原来的「下拉显示工具栏」
sed -i '/^        public void onSwipeUpdated(/,/^        }$/ s|^\( *\)showLayout(LayoutType.HUB, true);$|\1// Alice patch start 0006\n\1startShowing(mToolbarSwipeLayout, true);\n\1// Alice patch end 0006|' "$path1"
