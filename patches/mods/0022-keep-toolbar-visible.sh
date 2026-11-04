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

# A0) 默认普通 NTP 滑动时，Android 工具栏保持唯一的可见工具栏。
sed -i '/^    private @Nullable LayoutTab mToTab; \/\/ Set to mLeftTab or mRightTab or null if undetermined.$/a\
    // Alice patch start 0022\
    private boolean mAliceDisableCompositorToolbar;\
    // Alice patch end 0022' "$path1"

sed -i '/^        NativePage nativePage = (currentTab != null) ? currentTab.getNativePage() : null;$/i\
        // Alice patch start 0022\
        Tab aliceSwipeSourceTab = model.getTabAtChecked(fromIndex);\
        mAliceDisableCompositorToolbar =\
                aliceSwipeSourceTab != null\
                        \&\& !aliceSwipeSourceTab.isIncognito()\
                        \&\& UrlUtilities.isNtpUrl(aliceSwipeSourceTab.getUrl());\
        if (mAliceDisableCompositorToolbar) {\
            if (mLeftToolbarOverlay != null) mLeftToolbarOverlay.setManualVisibility(false);\
            if (mRightToolbarOverlay != null) mRightToolbarOverlay.setManualVisibility(false);\
        }\
        // Alice patch end 0022' "$path1"

sed -i 's|^        layoutTab\.setShowToolbar(mMoveToolbar);$|        // Alice patch start 0022\n        layoutTab.setShowToolbar(mMoveToolbar \&\& !mAliceDisableCompositorToolbar);\n        // Alice patch end 0022|' "$path1"

sed -i '/^            if (mLeftToolbarOverlay != null) {$/,/^            }$/c\
            // Alice patch start 0022\
            if (mLeftToolbarOverlay != null) {\
                if (mAliceDisableCompositorToolbar) {\
                    mLeftToolbarOverlay.setManualVisibility(false);\
                } else {\
                    mLeftToolbarOverlay.setManualVisibility(true);\
                    mLeftToolbarOverlay.setAnonymize(mLeftTab != mFromTab);\
                    mLeftToolbarOverlay.setXOffset(leftX * dpToPx);\
                }\
            }\
            // Alice patch end 0022' "$path1"

sed -i '/^            if (mRightToolbarOverlay != null) {$/,/^            }$/c\
            // Alice patch start 0022\
            if (mRightToolbarOverlay != null) {\
                if (mAliceDisableCompositorToolbar) {\
                    mRightToolbarOverlay.setManualVisibility(false);\
                } else {\
                    mRightToolbarOverlay.setManualVisibility(true);\
                    mRightToolbarOverlay.setAnonymize(mRightTab != mFromTab);\
                    mRightToolbarOverlay.setXOffset(rightX * dpToPx);\
                }\
            }\
            // Alice patch end 0022' "$path1"

# A) 滑动期间不再申请 hiding token（也不动工具栏位置）
sed -i '/^    public boolean forceHideBrowserControlsAndroidView() {$/,/^    }$/c\
    public boolean forceHideBrowserControlsAndroidView() {\
        // Alice patch start 0022\
        // Alice: keep-toolbar-visible -- 滑动期间不强制隐藏 Android 工具栏，位置也不动。\
        return false;\
        // Alice patch end 0022\
    }' "$path1"

# B) 全屏时隐藏 Android 工具栏。底置工具栏固定使用 Android view，
#    顶部工具栏继续使用 Chrome 原有的 compositor/Android 二选一逻辑。
sed -i 's|^        return !BrowserControlsUtils.drawControlsAsTexture(this);$|        // Alice patch start 0022\n        if (getFullscreenManager() != null \&\& getFullscreenManager().getPersistentFullscreenMode()) {\n            return false;\n        }\n        if (getControlsPosition() == ControlsPosition.BOTTOM) return true;\n        return !BrowserControlsUtils.drawControlsAsTexture(this);\n        // Alice patch end 0022|' "$path2"

# C) 切 Tab 时不再 transient show browser controls。这个调用会把 constraints
#    推到 SHOWN，并由 native 启动约 200ms 的 controls 动画。
sed -i '/^                mBrowserVisibilityDelegate.showControlsTransient();$/c\
                // Alice patch start 0022\
                // Tab switches must not force controls to SHOWN.\
                // Alice patch end 0022
' "$path2"
