#!/bin/bash
# 冷启动扩展按钮着色：扩展入口创建时同步当前网页主题 tint。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionsMenuCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0077' "$path1"; then
    exit 100
fi

# 和其他工具栏按钮保持一致：优先使用 ThemeColorProvider 已生效的 tint；
# 如果主题色尚未初始化，则保留 View 在 XML 中已有的 tint，等待后续回调。
sed -i '/^        mThemeColorProvider.addTintObserver(mTintObserver);$/a\
        // Alice patch start 0077\
        ImageViewCompat.setImageTintList(\
                mExtensionsMenuButton,\
                mThemeColorProvider.getActivityFocusTint() == null\
                        ? mExtensionsMenuButton.getImageTintList()\
                        : mThemeColorProvider.getActivityFocusTint());\
        // Alice patch end 0077' "$path1"
