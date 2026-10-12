#!/bin/bash
# 工具栏滑动（按住工具栏左右滑切标签 / 上滑开标签页管理）时让工具栏保持显示，且不干扰手势本身。

# 检测是否已应用
if grep -q 'Alice: keep-toolbar-visible -- 滑动期间不强制隐藏 Android 工具栏' "chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"; then
    exit 100
fi

# A) 滑动期间不再申请 hiding token（也不动工具栏位置）
sed -i '/^    public boolean forceHideBrowserControlsAndroidView() {$/,/^    }$/c\
    public boolean forceHideBrowserControlsAndroidView() {\
        // Alice: keep-toolbar-visible -- 滑动期间不强制隐藏 Android 工具栏，位置也不动。\
        return false;\
    }' \
    "chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"

# B) 不再因为 hiddenRatio > 0 把 Android 工具栏设成 INVISIBLE
sed -i 's|^        return !BrowserControlsUtils.drawControlsAsTexture(this);$|        // Alice: keep-toolbar-visible -- 滑动时也保持 Android 工具栏可见。\n        return true;|' \
    "chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"
