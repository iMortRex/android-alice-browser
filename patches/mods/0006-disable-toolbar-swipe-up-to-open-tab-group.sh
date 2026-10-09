#!/bin/bash
# 禁用上滑工具栏打开标签页管理

# 检测是否已应用
if grep -Pzo 'RecordUserAction\.record\("MobileToolbarSwipeOpenStackView"\);\s*\n\s*startShowing\(mToolbarSwipeLayout, true\);' "chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/LayoutManagerChrome.java" >/dev/null 2>&1; then
    exit 100
fi

sed -i '/public void onSwipeUpdated(/,/^        }/ s|showLayout(LayoutType.HUB, true);|startShowing(mToolbarSwipeLayout, true);|' \
    chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/LayoutManagerChrome.java