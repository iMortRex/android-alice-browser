#!/bin/bash
# 标签管理页新建标签动画：从标签管理页的新建按钮展开，并保持底部圆角一致。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path4="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewTabAnimationLayout.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewForegroundTabAnimationHostView.java"
path7="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimationData.java"

# 检测是否已应用
if grep -q 'Alice patch start 0029' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 工具栏配置在底部时，不按顶部工具栏判断动画方向。
sed -i '/^    public static boolean shouldShowToolbarOnTop(@Nullable Tab tab) {$/a\
        // Alice patch start 0029\
        if (!isToolbarConfiguredToShowOnTop()) return false;\
        // Alice patch end 0029' "$path1"

# Hub 布局中的新建标签动画统一从底部居中开始。
sed -i 's|^\( *\)@RectStart int rectStart = isBottomBarInGts ? RectStart\.BOTTOM_CENTER : RectStart\.TOP;$|\1@RectStart int rectStart = isBottomBarInGts ? RectStart.BOTTOM_CENTER : RectStart.TOP;\n\1// Alice patch start 0029\n\1rectStart = RectStart.BOTTOM_CENTER;\n\1// Alice patch end 0029|' "$path3"

# 新建标签动画不再吃底栏移动补丁增加的 56dp 搜索框留白。
sed -i '/^    private final int mSearchBoxHeight;$/a\
    // Alice patch start 0029\
    private boolean mSearchBoxGapEnabled = true;\
    // Alice patch end 0029' "$path4"

sed -i '/^    public void setThumbnailSizeForOffset(@Nullable Size thumbnailSize) {$/i\
    // Alice patch start 0029\
    public void setSearchBoxGapEnabled(boolean enabled) {\
        mSearchBoxGapEnabled = enabled;\
    }\
    // Alice patch end 0029\
' "$path4"

sed -i '/^                        mRectView, mInitialRect, finalRect, \/\* searchBoxHeight= \*\/ 0);$/a\
        // Alice patch start 0029\
        mExpandAnimator.setSearchBoxGapEnabled(false);\
        // Alice patch end 0029' "$path6"

# 新建标签动画四个角保持相同圆角。
sed -i 's|^                startRadii\[2\] = 0;$|                // Alice patch start 0029\n                // 所有角保持相同圆角。\n                // Alice patch end 0029|' "$path5"
sed -i 's|^                    startRadii\[3\] = 0;$|                    // Alice patch start 0029\n                    startRadii[3] = radius;\n                    // Alice patch end 0029|' "$path5"

sed -i '/^        int\[\] cornerRadii;$/,/^        }$/c\
        // Alice patch start 0029\
        int[] cornerRadii =\
                new int[] {cornerRadius, cornerRadius, cornerRadius, cornerRadius};\
        // Alice patch end 0029' "$path7"

# 标签管理页的新建标签动画起点对准当前 Hub 容器中的新建按钮。
sed -i '/^        initialRect = new Rect();$/,/^        NewTabAnimationUtils\.updateRects(rectStart, isRtl, initialRect, finalRect);$/c\
        // Alice patch start 0029\
        View aliceNewTabButton = containerView.findViewById(R.id.toolbar_action_button);\
        Rect aliceNewTabButtonRect = new Rect();\
        Rect aliceHubContainerRect = new Rect();\
        boolean aliceHasButtonOrigin =\
                aliceNewTabButton != null\
                        \&\& aliceNewTabButton.getGlobalVisibleRect(aliceNewTabButtonRect)\
                        \&\& containerView.getGlobalVisibleRect(aliceHubContainerRect);\
        if (aliceHasButtonOrigin) {\
            aliceNewTabButtonRect.offset(\
                    -aliceHubContainerRect.left, -aliceHubContainerRect.top);\
            initialRect = aliceNewTabButtonRect;\
            finalRect = new Rect(0, 0, aliceHubContainerRect.width(), aliceHubContainerRect.height());\
        } else {\
            initialRect = new Rect();\
            NewTabAnimationUtils.updateRects(rectStart, isRtl, initialRect, finalRect);\
        }\
        // Alice patch end 0029' "$path3"

# 底部居中动画最终铺满到窗口底部。
sed -i '/^        NewTabAnimationUtils\.updateRects(rectStart, isRtl, initialRect, finalRect);$/i\
        // Alice patch start 0029\
        if (rectStart == RectStart.BOTTOM_CENTER) {\
            int[] aliceAnimationHostLocation = new int[2];\
            mAnimationHostView.getLocationOnScreen(aliceAnimationHostLocation);\
            int aliceDisplayBottom =\
                    mToolbarManager\
                            .getWindowAndroid()\
                            .getDisplay()\
                            .getDisplayHeight()\
                            - aliceAnimationHostLocation[1];\
            finalRect.bottom = Math.max(finalRect.bottom, aliceDisplayBottom);\
        }\
        // Alice patch end 0029\
\
' "$path5"

# TabSwitcher UI 启动的新标签页从标签管理页按钮位置开始。
sed -i '/^            initialRect\.offset(0, -heightDifference);$/a\
        // Alice patch start 0029\
        if (rectStart == RectStart.BOTTOM_CENTER\
                \&\& newTab.getLaunchType() == TabLaunchType.FROM_TAB_SWITCHER_UI) {\
            Rect aliceAnchorRect = new Rect();\
            View aliceAnchor = getAliceTabSwitcherAnchor(aliceAnchorRect);\
            if (aliceAnchor != null) {\
                int[] aliceAnimationHostLocation = new int[2];\
                mAnimationHostView.getLocationOnScreen(aliceAnimationHostLocation);\
                initialRect.set(\
                        aliceAnchorRect.left - aliceAnimationHostLocation[0],\
                        aliceAnchorRect.top - aliceAnimationHostLocation[1],\
                        aliceAnchorRect.right - aliceAnimationHostLocation[0],\
                        aliceAnchorRect.bottom - aliceAnimationHostLocation[1]);\
            }\
        }\
        // Alice patch end 0029' "$path5"

# 允许动画 View 越过父容器边界绘制。
sed -i '/^        mAnimationHostView\.addView(mForegroundHostView);$/i\
        // Alice patch start 0029\
        mAnimationHostView.setClipChildren(false);\
        mAnimationHostView.setClipToPadding(false);\
        android.view.ViewParent aliceAnimationParent = mAnimationHostView.getParent();\
        if (aliceAnimationParent instanceof ViewGroup) {\
            ViewGroup aliceAnimationParentView = (ViewGroup) aliceAnimationParent;\
            aliceAnimationParentView.setClipChildren(false);\
            aliceAnimationParentView.setClipToPadding(false);\
        }\
        // Alice patch end 0029\
\
' "$path5"

# 动画 View 放在撤销气泡下方，保证气泡始终显示在动画之上。
sed -i '/^        mAnimationHostView\.addView(mForegroundHostView);$/a\
        // Alice patch start 0029\
        mForegroundHostView.setElevation(0f);\
        mForegroundHostView.setTranslationZ(0f);\
        View aliceSnackbarHost = mAnimationHostView.findViewById(R.id.bottom_container);\
        if (aliceSnackbarHost != null\
                \&\& aliceSnackbarHost.getParent() == mAnimationHostView) {\
            int aliceSnackbarIndex = mAnimationHostView.indexOfChild(aliceSnackbarHost);\
            mAnimationHostView.removeView(mForegroundHostView);\
            mAnimationHostView.addView(mForegroundHostView, aliceSnackbarIndex);\
        }\
        // Alice patch end 0029' "$path5"

# Hub 预览图插到 Snackbar 容器之前，避免遮住撤销气泡。
sed -i '/^        mHubContainerView\.addView(mShrinkExpandImageView);$/c\
        // Alice patch start 0029\
        View aliceHubSnackbarContainer =\
                mHubContainerView.findViewById(R.id.pane_host_view_snackbar_container);\
        if (aliceHubSnackbarContainer != null\
                \&\& aliceHubSnackbarContainer.getParent() == mHubContainerView) {\
            mHubContainerView.addView(\
                    mShrinkExpandImageView,\
                    mHubContainerView.indexOfChild(aliceHubSnackbarContainer));\
        } else {\
            mHubContainerView.addView(mShrinkExpandImageView);\
        }\
        // Alice patch end 0029' "$path2"

# 仅 TabSwitcher UI 创建的标签页使用 BOTTOM_CENTER 起点。
sed -i '/^    private @RectStart int getForegroundRectStart(@Nullable Tab oldTab, Tab newTab) {$/,/^    }$/c\
    private @RectStart int getForegroundRectStart(@Nullable Tab oldTab, Tab newTab) {\
        @TabLaunchType int tabLaunchType = newTab.getLaunchType();\
        if (oldTab == null\
                || tabLaunchType == TabLaunchType.FROM_LONGPRESS_FOREGROUND\
                || tabLaunchType == TabLaunchType.FROM_LONGPRESS_FOREGROUND_IN_GROUP) {\
            return RectStart.CENTER;\
        }\
\
        // Alice patch start 0029\
        if (tabLaunchType == TabLaunchType.FROM_TAB_SWITCHER_UI) {\
            return RectStart.BOTTOM_CENTER;\
        }\
        // Alice patch end 0029\
\
        if (BottomBarConfigUtils.isBottomBarEnabled(getContext())) {\
            return RectStart.BOTTOM_CENTER;\
        }\
\
        boolean oldTabHasTopToolbar = ToolbarPositionController.shouldShowToolbarOnTop(oldTab);\
        boolean newTabHasTopToolbar = ToolbarPositionController.shouldShowToolbarOnTop(newTab);\
\
        if (oldTabHasTopToolbar \&\& newTabHasTopToolbar) {\
            return RectStart.TOP_TOOLBAR;\
        } else if (oldTabHasTopToolbar) {\
            return RectStart.TOP;\
        } else if (newTabHasTopToolbar) {\
            return RectStart.BOTTOM;\
        } else {\
            return RectStart.BOTTOM_TOOLBAR;\
        }\
    }' "$path5"

# 新增标签管理页按钮锚点方法。
sed -i '/^    private int getBottomControlsHeightForTab($/i\
    // Alice patch start 0029\
    private @Nullable View getAliceTabSwitcherAnchor(Rect aliceAnchorRect) {\
        View aliceToolbar = mAnimationHostView.findViewById(R.id.toolbar);\
        if (aliceToolbar == null) return null;\
        View aliceSwitcherButton =\
                aliceToolbar.findViewById(R.id.tab_switcher_button);\
        return aliceSwitcherButton != null\
                        \&\& aliceSwitcherButton.getGlobalVisibleRect(aliceAnchorRect)\
                ? aliceSwitcherButton\
                : null;\
    }\
    // Alice patch end 0029\
\
' "$path5"
