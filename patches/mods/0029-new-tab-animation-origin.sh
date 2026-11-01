#!/bin/bash
# 新建标签页动画：从「屏幕底部中间」向上铺满整个屏幕

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path4="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"
path5="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/NewTabAnimationUtils.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewTabAnimationLayout.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path8="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewForegroundTabAnimationHostView.java"
path9="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TabSwitcherActionMenuCoordinator.java"
path10="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimationData.java"

# 检测是否已应用
if grep -q 'Alice patch start 0029' "$path1"; then
    exit 100
fi

# 1) 工具栏配置在底部时，不按“在顶部”处理
sed -i '/^    public static boolean shouldShowToolbarOnTop(@Nullable Tab tab) {$/a\
        // Alice patch start 0029\
        if (!isToolbarConfiguredToShowOnTop()) return false;\
        // Alice patch end 0029' "$path1"

sed -i '/^public class ToolbarPositionController implements OnSharedPreferenceChangeListener {$/a\
    // Alice patch start 0029\
    private static volatile long sAliceBottomBarNewTabButtonClickTime;\
\
    public static void notifyAliceBottomBarNewTabButtonClicked() {\
        sAliceBottomBarNewTabButtonClickTime = android.os.SystemClock.uptimeMillis();\
    }\
\
    public static boolean wasAliceBottomBarNewTabButtonClickedRecently() {\
        return android.os.SystemClock.uptimeMillis()\
                        - sAliceBottomBarNewTabButtonClickTime\
                < 2000;\
    }\
\
    private static volatile long sAliceTabSwitcherMenuClickTime;\
\
    public static void notifyAliceTabSwitcherMenuClicked() {\
        sAliceTabSwitcherMenuClickTime = android.os.SystemClock.uptimeMillis();\
    }\
\
    public static boolean wasAliceTabSwitcherMenuClickedRecently() {\
        return android.os.SystemClock.uptimeMillis()\
                        - sAliceTabSwitcherMenuClickTime\
                < 2000;\
    }\
    // Alice patch end 0029' "$path1"

sed -i 's|^                    v -> {$|                    v -> {\n                        // Alice patch start 0029\n                        ToolbarPositionController\n                                .notifyAliceBottomBarNewTabButtonClicked();\n                        // Alice patch end 0029|' "$path7"

sed -i 's|^                        recordUserActions(id);$|                        // Alice patch start 0029\n                        org.chromium.chrome.browser.toolbar.ToolbarPositionController\n                                .notifyAliceTabSwitcherMenuClicked();\n                        // Alice patch end 0029\n                        recordUserActions(id);|' "$path9"

# 5) 起点终点都是底部居中：圆角才会是 {r, r, 0, 0}（左右一致）
sed -i 's|^\( *\)@RectStart int rectStart = isBottomBarInGts ? RectStart\.BOTTOM_CENTER : RectStart\.TOP;$|\1@RectStart int rectStart = isBottomBarInGts ? RectStart.BOTTOM_CENTER : RectStart.TOP;\n\1// Alice patch start 0029\n\1rectStart = RectStart.BOTTOM_CENTER;\n\1// Alice patch end 0029|' "$path3"

# 6) 新建标签页不吃 0027 的 56dp 工具栏留白
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

sed -i 's|^\( *\)mView.setTranslationY(translationY + searchBoxGap);$|\1// Alice patch start 0029\n\1mView.setTranslationY(\n\1        translationY + (mSearchBoxGapEnabled ? searchBoxGap : 0));\n\1// Alice patch end 0029|' "$path4"

sed -i '/^                        mRectView, mInitialRect, finalRect, \/\* searchBoxHeight= \*\/ 0);$/a\
        // Alice patch start 0029\
        mExpandAnimator.setSearchBoxGapEnabled(false);\
        // Alice patch end 0029' "$path8"

# === 「新建标签页 / 开发者工具」的弹出动画起点 ===
# 7) NewTabAnimationUtils：新增「右下角」起点（初始小卡片贴右下角，再往左上铺满）
sed -i 's|^        RectStart\.BOTTOM_CENTER$|        // Alice patch start 0029\n        RectStart.BOTTOM_CENTER,\n        RectStart.BOTTOM_RIGHT\n        // Alice patch end 0029|' "$path5"
sed -i 's|^        int BOTTOM_CENTER = 5;$|        // Alice patch start 0029\n        int BOTTOM_CENTER = 5;\n        int BOTTOM_RIGHT = 6;\n        // Alice patch end 0029|' "$path5"
sed -i 's|^        } else {$|        } else if (rectStart == RectStart.BOTTOM_RIGHT) {\n            // Alice patch start 0029\n            // 右下角起手：初始小卡片贴在右下角，再往左上铺满\n            int aliceRight = finalRect.right;\n            initialRect.right = aliceRight;\n            initialRect.left = aliceRight - initialWidth;\n            finalRect.left = aliceRight - finalWidth;\n            int aliceBottom = finalRect.bottom;\n            initialRect.top = aliceBottom - initialHeight;\n            initialRect.bottom = aliceBottom;\n            finalRect.top = aliceBottom - finalHeight;\n            // Alice patch end 0029\n        } else {|' "$path5"

# 8) NewTabAnimationLayout：区分「开发者工具」和「新建标签页」
#    - 开发者工具（devtools:// 标签页）：右下角 → 左上角
#    - 新建标签页（工具栏的新标签页按钮 / 长按「标签页」后的「新建标签页」）：从新标签页按钮处往上缩放
sed -i '/^                || tabLaunchType == TabLaunchType\.FROM_LONGPRESS_FOREGROUND_IN_GROUP) {$/,/^        }$/ s|^        }$|        }\n\n        // Alice patch start 0029\n        // 打开开发者工具：从右下角往左上角展开\n        if (newTab.getUrl() != null \&\& "devtools".equals(newTab.getUrl().getScheme())) {\n            return RectStart.BOTTOM_RIGHT;\n        }\n        // 新建标签页（工具栏「新标签页」按钮 / 长按「标签页」后的「新建标签页」/ 应用菜单）：\n        // 从新标签页按钮处往上缩放\n        if (tabLaunchType == TabLaunchType.FROM_CHROME_UI\n                \|\| tabLaunchType == TabLaunchType.FROM_TAB_SWITCHER_UI) {\n            return RectStart.BOTTOM_CENTER;\n        }\n        // Alice patch end 0029|' "$path6"

# 9) 新建标签页动画从上到下所有角始终保持相同圆角。
sed -i 's|^                startRadii\[2\] = 0;$|                // Alice patch start 0029\n                // 所有角保持相同圆角。\n                // Alice patch end 0029|' "$path6"
sed -i 's|^                    startRadii\[3\] = 0;$|                    // Alice patch start 0029\n                    startRadii[3] = radius;\n                    // Alice patch end 0029|' "$path6"

sed -i '/^        int\[\] cornerRadii;$/,/^        }$/c\
        // Alice patch start 0029\
        int[] cornerRadii =\
                new int[] {cornerRadius, cornerRadius, cornerRadius, cornerRadius};\
        // Alice patch end 0029' "$path10"

# 10) NewTabAnimationLayout：普通新标签页的起点对准底部栏的「新建标签页」按钮。
#     必须放在 heightDifference 修正之后，否则底栏高度会再次把起点推回工具栏上方。
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

sed -i '/^        NewTabAnimationUtils\.updateRects(rectStart, isRtl, initialRect, finalRect);$/i\
        // Alice patch start 0029\
        if (rectStart == RectStart.BOTTOM_CENTER\
                || rectStart == RectStart.BOTTOM_RIGHT) {\
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
' "$path6"

sed -i '/^            initialRect\.offset(0, -heightDifference);$/a\
        // Alice patch start 0029\
        if (rectStart == RectStart.BOTTOM_RIGHT\
                || (rectStart == RectStart.BOTTOM_CENTER\
                        \&\& (ToolbarPositionController\
                                        .wasAliceBottomBarNewTabButtonClickedRecently()\
                                || ToolbarPositionController\
                                        .wasAliceTabSwitcherMenuClickedRecently()\
                                || newTab.getLaunchType()\
                                        == TabLaunchType.FROM_TAB_SWITCHER_UI))) {\
            Rect aliceAnchorRect = new Rect();\
            View aliceAnchor = getAliceAnimationAnchor(rectStart, aliceAnchorRect);\
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
        // Alice patch end 0029' "$path6"

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
' "$path6"

sed -i '/^        mAnimationHostView\.addView(mForegroundHostView);$/a\
        // Alice patch start 0029\
        mForegroundHostView.setElevation(1000f);\
        mForegroundHostView.setTranslationZ(1000f);\
        mAnimationHostView.bringChildToFront(mForegroundHostView);\
        // Alice patch end 0029' "$path6"

sed -i '/^        mHubContainerView\.addView(mShrinkExpandImageView);$/a\
        // Alice patch start 0029\
        if (mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB) {\
            mShrinkExpandImageView.setElevation(1000f);\
            mShrinkExpandImageView.setTranslationZ(1000f);\
            mHubContainerView.bringChildToFront(mShrinkExpandImageView);\
        }\
        // Alice patch end 0029' "$path2"

# 11) 只有新标签页走 BOTTOM_CENTER；其它页面恢复 Chromium 原有的起点判断。
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
        if (ToolbarPositionController.wasAliceBottomBarNewTabButtonClickedRecently()) {\
            return RectStart.BOTTOM_CENTER;\
        }\
        if (ToolbarPositionController.wasAliceTabSwitcherMenuClickedRecently()) {\
            return RectStart.BOTTOM_CENTER;\
        }\
        if (newTab.getUrl() != null\
                \&\& "devtools".equals(newTab.getUrl().getScheme())) {\
            return RectStart.BOTTOM_RIGHT;\
        }\
        if (tabLaunchType == TabLaunchType.FROM_CHROME_UI) {\
            return RectStart.BOTTOM_RIGHT;\
        }\
        if (tabLaunchType == TabLaunchType.FROM_TAB_SWITCHER_UI) {\
            return RectStart.BOTTOM_CENTER;\
        }\
        if (tabLaunchType == TabLaunchType.FROM_RECENT_TABS\
                || tabLaunchType == TabLaunchType.FROM_RECENT_TABS_FOREGROUND) {\
            return RectStart.BOTTOM_RIGHT;\
        }\
        if (tabLaunchType == TabLaunchType.FROM_HISTORY_NAVIGATION_FOREGROUND) {\
            return RectStart.BOTTOM_RIGHT;\
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
    }' "$path6"

sed -i '/^    private int getBottomControlsHeightForTab($/i\
    // Alice patch start 0029\
    private @Nullable View getAliceAnimationAnchor(\
            @RectStart int rectStart, Rect aliceAnchorRect) {\
        View aliceBottomBar = null;\
        if (BottomBarConfigUtils.isBottomBarEnabled(getContext())) {\
            aliceBottomBar =\
                    mAnimationHostView.findViewById(\
                            org.chromium.chrome.browser.ui.bottombar.R.id\
                                    .bottom_bar_container);\
        }\
        View aliceToolbar = mAnimationHostView.findViewById(R.id.toolbar);\
\
        if (rectStart == RectStart.BOTTOM_CENTER) {\
            if (aliceBottomBar != null\
                    \&\& ToolbarPositionController\
                            .wasAliceBottomBarNewTabButtonClickedRecently()) {\
                View aliceNewTabButton =\
                        aliceBottomBar.findViewById(\
                                org.chromium.chrome.browser.ui.bottombar.R.id\
                                        .new_tab_button);\
                if (aliceNewTabButton != null\
                        \&\& aliceNewTabButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                    return aliceNewTabButton;\
                }\
            }\
            if (aliceToolbar != null) {\
                View aliceSwitcherButton =\
                        aliceToolbar.findViewById(R.id.tab_switcher_button);\
                if (aliceSwitcherButton != null\
                        \&\& aliceSwitcherButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                    return aliceSwitcherButton;\
                }\
            }\
        } else if (rectStart == RectStart.BOTTOM_RIGHT) {\
            if (aliceBottomBar != null) {\
                View aliceMenuButton = aliceBottomBar.findViewById(R.id.menu_button);\
                if (aliceMenuButton != null\
                        \&\& aliceMenuButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                    return aliceMenuButton;\
                }\
            }\
            if (aliceToolbar != null) {\
                View aliceMenuButton = aliceToolbar.findViewById(R.id.menu_button);\
                if (aliceMenuButton != null\
                        \&\& aliceMenuButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                    return aliceMenuButton;\
                }\
            }\
        }\
        return null;\
    }\
    // Alice patch end 0029\
\
' "$path6"
