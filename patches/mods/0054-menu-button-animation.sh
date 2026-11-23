#!/bin/bash
# 菜单内按钮动画：从菜单按钮位置展开新建标签页或开发者工具页面。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TabSwitcherActionMenuCoordinator.java"
path3="chrome/browser/ui/android/browser_navigator_android.cc"
path4="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/NewTabAnimationUtils.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewTabAnimationLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0054' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 记录标签管理页菜单按钮最近一次点击时间。
sed -i '/^public class ToolbarPositionController implements OnSharedPreferenceChangeListener {$/a\
    // Alice patch start 0054\
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
    // Alice patch end 0054' "$path1"

# 菜单内按钮点击时记录动画来源。
sed -i 's|^                        recordUserActions(id);$|                        // Alice patch start 0054\n                        org.chromium.chrome.browser.toolbar.ToolbarPositionController\n                                .notifyAliceTabSwitcherMenuClicked();\n                        // Alice patch end 0054\n                        recordUserActions(id);|' "$path2"

# 扩展页打开前台标签时映射为 Chrome UI，让动画复用菜单按钮锚点。
sed -i '/^TabModel::TabLaunchType GetTabLaunchType(const NavigateParams\* params) {$/a\
  // Alice patch start 0054\
  bool aliceExtensionNavigation =\
      params->url.SchemeIs("chrome-extension")\
              || (params->source_contents != nullptr\
                      \&\& params->source_contents->GetLastCommittedURL().SchemeIs(\
                              "chrome-extension"));\
  // Alice patch end 0054' "$path3"

sed -i '/^  \/\/ 3\. Foreground Navigation:$/i\
  // Alice patch start 0054\
  if (aliceExtensionNavigation \&\& !is_background) {\
    return TabLaunchType::FROM_CHROME_UI;\
  }\
  // Alice patch end 0054\
\
' "$path3"

# 增加右下角动画起点。
sed -i 's|^        RectStart\.BOTTOM_CENTER$|        // Alice patch start 0054\n        RectStart.BOTTOM_CENTER,\n        RectStart.BOTTOM_RIGHT\n        // Alice patch end 0054|' "$path4"
sed -i 's|^        int BOTTOM_CENTER = 5;$|        // Alice patch start 0054\n        int BOTTOM_CENTER = 5;\n        int BOTTOM_RIGHT = 6;\n        // Alice patch end 0054|' "$path4"

# 右下角起点从右上角开始，再向左上铺满。
sed -i 's|^        } else {$|        } else if (rectStart == RectStart.BOTTOM_RIGHT) {\n            // Alice patch start 0054\n            int aliceRight = finalRect.right;\n            initialRect.right = aliceRight;\n            initialRect.left = aliceRight - initialWidth;\n            finalRect.left = aliceRight - finalWidth;\n            int aliceBottom = finalRect.bottom;\n            initialRect.top = aliceBottom - initialHeight;\n            initialRect.bottom = aliceBottom;\n            finalRect.top = aliceBottom - finalHeight;\n            // Alice patch end 0054\n        } else {|' "$path4"

# 菜单按钮或 Chrome UI 创建的页面使用右下角动画。
sed -i '/^    private @RectStart int getForegroundRectStart(@Nullable Tab oldTab, Tab newTab) {$/a\
        // Alice patch start 0054\
        if (ToolbarPositionController.wasAliceTabSwitcherMenuClickedRecently()\
                || (newTab.getUrl() != null\
                        \&\& "devtools".equals(newTab.getUrl().getScheme()))\
                || newTab.getLaunchType() == TabLaunchType.FROM_CHROME_UI\
                || newTab.getLaunchType() == TabLaunchType.FROM_RECENT_TABS\
                || newTab.getLaunchType() == TabLaunchType.FROM_RECENT_TABS_FOREGROUND\
                || newTab.getLaunchType()\
                        == TabLaunchType.FROM_HISTORY_NAVIGATION_FOREGROUND) {\
            return RectStart.BOTTOM_RIGHT;\
        }\
        // Alice patch end 0054' "$path5"

# 右下角动画最终铺满窗口底部。
sed -i '/^        NewTabAnimationUtils\.updateRects(rectStart, isRtl, initialRect, finalRect);$/i\
        // Alice patch start 0054\
        if (rectStart == RectStart.BOTTOM_RIGHT) {\
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
        // Alice patch end 0054\
\
' "$path5"

# 将右下角动画起点对齐到底栏菜单按钮。
sed -i '/^            initialRect\.offset(0, -heightDifference);$/a\
        // Alice patch start 0054\
        if (rectStart == RectStart.BOTTOM_RIGHT\
                || ToolbarPositionController.wasAliceTabSwitcherMenuClickedRecently()) {\
            Rect aliceAnchorRect = new Rect();\
            View aliceAnchor = getAliceMenuButtonAnchor(aliceAnchorRect);\
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
        // Alice patch end 0054' "$path5"

# 新增底栏或工具栏菜单按钮锚点方法。
sed -i '/^    private int getBottomControlsHeightForTab($/i\
    // Alice patch start 0054\
    private @Nullable View getAliceMenuButtonAnchor(Rect aliceAnchorRect) {\
        View aliceToolbar = mAnimationHostView.findViewById(R.id.toolbar);\
        if (BottomBarConfigUtils.isBottomBarEnabled(getContext())) {\
            View aliceBottomBar =\
                    mAnimationHostView.findViewById(\
                            org.chromium.chrome.browser.ui.bottombar.R.id\
                                    .bottom_bar_container);\
            if (aliceBottomBar != null) {\
                View aliceMenuButton = aliceBottomBar.findViewById(R.id.menu_button);\
                if (aliceMenuButton != null\
                        \&\& aliceMenuButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                    return aliceMenuButton;\
                }\
            }\
        }\
        if (aliceToolbar != null) {\
            View aliceMenuButton = aliceToolbar.findViewById(R.id.menu_button);\
            if (aliceMenuButton != null\
                    \&\& aliceMenuButton.getGlobalVisibleRect(aliceAnchorRect)) {\
                return aliceMenuButton;\
            }\
        }\
        return null;\
    }\
    // Alice patch end 0054\
\
' "$path5"
