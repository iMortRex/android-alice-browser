#!/bin/bash
# 标签管理页新建标签动画：从标签管理页的新建按钮展开，并保持底部圆角一致。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewTabAnimationLayout.java"
path5="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimationData.java"

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

# 新建标签动画四个角保持相同圆角。
sed -i 's|^                startRadii\[2\] = 0;$|                // Alice patch start 0029\n                // 所有角保持相同圆角。\n                // Alice patch end 0029|' "$path4"
sed -i 's|^                    startRadii\[3\] = 0;$|                    // Alice patch start 0029\n                    startRadii[3] = radius;\n                    // Alice patch end 0029|' "$path4"

sed -i '/^        int\[\] cornerRadii;$/,/^        }$/c\
        // Alice patch start 0029\
        int[] cornerRadii =\
                new int[] {cornerRadius, cornerRadius, cornerRadius, cornerRadius};\
        // Alice patch end 0029' "$path5"

# 标签管理页的新建标签动画起点对准当前 Hub 容器中实际可见的新建按钮。
sed -i '/^        initialRect = new Rect();$/,/^        NewTabAnimationUtils\.updateRects(rectStart, isRtl, initialRect, finalRect);$/c\
        // Alice patch start 0029\
        View aliceBottomBar =\
                containerView.getRootView().findViewById(\
                        org.chromium.chrome.browser.ui.bottombar.R.id.bottom_bar_container);\
        View aliceNewTabButton =\
                aliceBottomBar == null\
                        ? null\
                        : aliceBottomBar.findViewById(\
                                org.chromium.chrome.browser.ui.bottombar.R.id.new_tab_button);\
        if (aliceNewTabButton == null || !aliceNewTabButton.isShown()) {\
            aliceNewTabButton = containerView.findViewById(R.id.toolbar_action_button);\
        }\
        int[] aliceNewTabButtonLocation = new int[2];\
        int[] aliceHubContainerLocation = new int[2];\
        int[] aliceRootLocation = new int[2];\
        View aliceRoot = containerView.getRootView();\
        Rect aliceNewTabButtonRect = new Rect();\
        Rect aliceHubContainerRect = new Rect();\
        boolean aliceHasButtonOrigin =\
                aliceNewTabButton != null\
                        \&\& aliceNewTabButton.isShown()\
                        \&\& aliceNewTabButton.getWidth() > 0\
                        \&\& aliceNewTabButton.getHeight() > 0;\
        if (aliceHasButtonOrigin) {\
            aliceNewTabButton.getLocationOnScreen(aliceNewTabButtonLocation);\
            containerView.getLocationOnScreen(aliceHubContainerLocation);\
            aliceRoot.getLocationOnScreen(aliceRootLocation);\
            aliceNewTabButtonRect.set(\
                    aliceNewTabButtonLocation[0],\
                    aliceNewTabButtonLocation[1],\
                    aliceNewTabButtonLocation[0] + aliceNewTabButton.getWidth(),\
                    aliceNewTabButtonLocation[1] + aliceNewTabButton.getHeight());\
            aliceHubContainerRect.set(\
                    aliceHubContainerLocation[0],\
                    aliceHubContainerLocation[1],\
                    aliceHubContainerLocation[0] + containerView.getWidth(),\
                    aliceHubContainerLocation[1] + containerView.getHeight());\
            aliceNewTabButtonRect.offset(\
                    -aliceHubContainerLocation[0], -aliceHubContainerLocation[1]);\
            initialRect = aliceNewTabButtonRect;\
            int aliceVisibleBottom =\
                    Math.min(\
                            containerView.getHeight(),\
                            Math.max(\
                                    0,\
                                    aliceRootLocation[1]\
                                            + aliceRoot.getHeight()\
                                            - aliceHubContainerLocation[1]));\
            finalRect =\
                    new Rect(0, 0, containerView.getWidth(), aliceVisibleBottom);\
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
                    hostViewRect.bottom - aliceAnimationHostLocation[1];\
            finalRect.bottom = Math.max(finalRect.bottom, aliceDisplayBottom);\
        }\
        // Alice patch end 0029\
\
' "$path4"

# TabSwitcher UI 启动的新标签页从标签管理页按钮位置开始。
sed -i '/^            initialRect\.offset(0, -heightDifference);$/a\
        // Alice patch start 0029\
        if (rectStart == RectStart.BOTTOM_CENTER\
                \&\& newTab.getLaunchType() == TabLaunchType.FROM_TAB_SWITCHER_UI) {\
            Rect aliceAnchorRect = new Rect();\
            View aliceAnchor = getAliceNewTabAnchor(aliceAnchorRect);\
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
        // Alice patch end 0029' "$path4"

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
' "$path4"

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
        // Alice patch end 0029' "$path4"

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
    }' "$path4"

# 新增标签管理页新建按钮锚点方法。
sed -i '/^    private int getBottomControlsHeightForTab($/i\
    // Alice patch start 0029\
    private @Nullable View getAliceNewTabAnchor(Rect aliceAnchorRect) {\
        View aliceHubToolbar = mAnimationHostView.findViewById(R.id.hub_toolbar);\
        if (aliceHubToolbar != null) {\
            View aliceNewTabButton =\
                    aliceHubToolbar.findViewById(R.id.toolbar_action_button);\
            if (aliceNewTabButton != null\
                    \&\& aliceNewTabButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                return aliceNewTabButton;\
            }\
        }\
        View aliceBottomBar =\
                mAnimationHostView.findViewById(\
                        org.chromium.chrome.browser.ui.bottombar.R.id.bottom_bar_container);\
        if (aliceBottomBar != null) {\
            View aliceNewTabButton =\
                    aliceBottomBar.findViewById(\
                            org.chromium.chrome.browser.ui.bottombar.R.id.new_tab_button);\
            if (aliceNewTabButton != null\
                    \&\& aliceNewTabButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                return aliceNewTabButton;\
            }\
        }\
        View aliceToolbar = mAnimationHostView.findViewById(R.id.toolbar);\
        if (aliceToolbar == null) return null;\
        View aliceSwitcherButton =\
                aliceToolbar.findViewById(R.id.tab_switcher_button);\
        boolean aliceFoundSwitcher = aliceSwitcherButton != null\
                \&\& aliceSwitcherButton.getGlobalVisibleRect(aliceAnchorRect);\
        return aliceFoundSwitcher ? aliceSwitcherButton : null;\
    }\
    // Alice patch end 0029\
\
' "$path4"
