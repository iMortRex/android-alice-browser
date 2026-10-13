#!/bin/bash
# 去掉工具栏主页按钮 + 地址栏左侧固定 16dp 留白

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/home_button/HomeButton.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# 1) 主页按钮永久隐藏：GONE = 连 48dp 占位一起去掉（想保留占位就改成 INVISIBLE）
sed -i -e 's|^        mVisibility = visibility;$|        // Alice patch start\n        mVisibility = GONE;\n        // Alice patch end|' \
       -e 's|^        super.setVisibility(mHasSpaceToShow ? mVisibility : GONE);$|        // Alice patch start\n        super.setVisibility(GONE);\n        // Alice patch end|' \
    "$path1"

# 2) 地址栏左侧固定 16dp 留白（不再依赖主页按钮宽度）
sed -i 's|^        int padding = mToolbarSidePaddingForNtp;$|        // Alice patch start\n        // Alice: 左侧固定 16dp 留白（主页按钮已去掉）\n        int padding = Math.round(16 * getResources().getDisplayMetrics().density);\n        // Alice patch end|' "$path2"
