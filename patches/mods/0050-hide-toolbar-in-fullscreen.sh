#!/bin/bash
# 全屏时隐藏 Android 工具栏，并避免切换 Tab 时强制把 controls 动画回 SHOWN。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0050' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 全屏时隐藏 Android 工具栏；底置工具栏固定使用 Android View。
sed -i 's|^        return !BrowserControlsUtils.drawControlsAsTexture(this);$|        // Alice patch start 0050\
        if (getFullscreenManager() != null \&\& getFullscreenManager().getPersistentFullscreenMode()) {\
            return false;\
        }\
        if (getControlsPosition() == ControlsPosition.BOTTOM) return true;\
        return !BrowserControlsUtils.drawControlsAsTexture(this);\
        // Alice patch end 0050|' "$path1"

# 切换 Tab 时不再 transient show controls，避免强制启动约 200ms 的 controls 动画。
sed -i '/^                mBrowserVisibilityDelegate.showControlsTransient();$/c\
                // Alice patch start 0050\
                // Tab switches must not force controls to SHOWN.\
                // Alice patch end 0050
' "$path1"
