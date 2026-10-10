#!/bin/bash
# Display Cutout 模式固定为 1

# 检测是否已应用
if grep -q 'mVisibility = GONE;' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/home_button/HomeButton.java"; then
    exit 100
fi

# 主页按钮永久隐藏：GONE = 连 48dp 占位一起去掉（想保留占位就改成 INVISIBLE）
sed -i -e 's|^        mVisibility = visibility;$|        mVisibility = GONE;|' \
       -e 's|^        super.setVisibility(mHasSpaceToShow ? mVisibility : GONE);$|        super.setVisibility(GONE);|' \
    "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/home_button/HomeButton.java"

# 地址栏左侧固定 16dp 留白（不再依赖主页按钮宽度）
sed -i 's|^        int padding = mToolbarSidePaddingForNtp;$|        // Alice: 左侧固定 16dp 留白（主页按钮已去掉）\n        int padding = Math.round(16 * getResources().getDisplayMetrics().density);|' \
    "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
