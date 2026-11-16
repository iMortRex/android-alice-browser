#!/bin/bash
# 冷启动模拟导航栏布局同步：工具栏容器完成首次布局时补一次导航栏背景刷新，
# 避免 edge-to-edge 安全区与 compositor 表面晚于窗口首帧稳定。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"

if grep -q 'Alice patch start 0080' "$path1"; then
    exit 100
fi

sed -i '/^    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;$/a\
    // Alice patch start 0080\
    private boolean mAliceNavigationBarLayoutSyncPending = true;\
    private final View.OnLayoutChangeListener mAliceNavigationBarLayoutListener =\
            new View.OnLayoutChangeListener() {\
                @Override\
                public void onLayoutChange(\
                        View view,\
                        int left,\
                        int top,\
                        int right,\
                        int bottom,\
                        int oldLeft,\
                        int oldTop,\
                        int oldRight,\
                        int oldBottom) {\
                    if (!mAliceNavigationBarLayoutSyncPending\
                            || mNavigationBarBackgroundColor == Integer.MIN_VALUE) {\
                        return;\
                    }\
                    if (mCurrentPosition.get() != ControlsPosition.BOTTOM) {\
                        mAliceNavigationBarLayoutSyncPending = false;\
                        view.removeOnLayoutChangeListener(this);\
                        return;\
                    }\
                    View aliceBackground = mNavigationBarBackground;\
                    if (aliceBackground == null\
                            || aliceBackground.getVisibility() != View.VISIBLE) {\
                        updateNavigationBarBackground();\
                        aliceBackground = mNavigationBarBackground;\
                    }\
                    if (aliceBackground != null\
                            \&\& aliceBackground.getVisibility() == View.VISIBLE\
                            \&\& mAliceInitialPageReady) {\
                        mAliceNavigationBarLayoutSyncPending = false;\
                        view.removeOnLayoutChangeListener(this);\
                    }\
                }\
            };\
    // Alice patch end 0080' "$path1"

sed -i '/^                \.postOnAnimation(ToolbarPositionController.this::updateNavigationBarBackground);$/a\
        // Alice patch start 0080\
        mControlContainer\
                .getView()\
                .addOnLayoutChangeListener(mAliceNavigationBarLayoutListener);\
        // Alice patch end 0080' "$path1"

sed -i '/^        mControlContainer.removeTouchEventObserver(mToolbarTouchObserver);$/a\
        // Alice patch start 0080\
        if (mAliceNavigationBarLayoutSyncPending) {\
            mControlContainer\
                    .getView()\
                    .removeOnLayoutChangeListener(mAliceNavigationBarLayoutListener);\
            mAliceNavigationBarLayoutSyncPending = false;\
        }\
        // Alice patch end 0080' "$path1"
