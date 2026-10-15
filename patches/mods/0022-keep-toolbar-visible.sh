#!/bin/bash
# 工具栏滑动时保持显示，且不干扰手势本身

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0022' "$path1"; then
    exit 100
fi

# A) 滑动期间不再申请 hiding token（也不动工具栏位置）
sed -i '/^    public boolean forceHideBrowserControlsAndroidView() {$/,/^    }$/c\
    public boolean forceHideBrowserControlsAndroidView() {\
        // Alice patch start 0022\
        // Alice: keep-toolbar-visible -- 滑动期间不强制隐藏 Android 工具栏，位置也不动。\
        return false;\
        // Alice patch end 0022\
    }' "$path1"

# B) 不再因为 hiddenRatio > 0 把 Android 工具栏设成 INVISIBLE
sed -i 's|^        return !BrowserControlsUtils.drawControlsAsTexture(this);$|        // Alice patch start 0022\n        // 全屏时仍按原逻辑隐藏；其它情况保持 Android 工具栏可见。\n        if (getFullscreenManager() != null \&\& getFullscreenManager().getPersistentFullscreenMode()) {\n            return !BrowserControlsUtils.drawControlsAsTexture(this);\n        }\n        return true;\n        // Alice patch end 0022|' "$path2"
