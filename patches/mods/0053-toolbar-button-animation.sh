#!/bin/bash
# 工具栏按钮动画：从底栏新建标签按钮位置展开新建标签页。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewTabAnimationLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0053' "$path1"; then
    exit 100
fi

# 记录底栏新建标签按钮最近一次点击时间。
sed -i '/^public class ToolbarPositionController implements OnSharedPreferenceChangeListener {$/a\
    // Alice patch start 0053\
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
    // Alice patch end 0053' "$path1"

# 底栏新建标签按钮点击时记录动画来源。
sed -i 's|^                    v -> {$|                    v -> {\n                        // Alice patch start 0053\n                        ToolbarPositionController\n                                .notifyAliceBottomBarNewTabButtonClicked();\n                        // Alice patch end 0053|' "$path2"

# 底栏新建按钮点击后，前台标签从底栏按钮开始动画。
sed -i '/^    private @RectStart int getForegroundRectStart(@Nullable Tab oldTab, Tab newTab) {$/a\
        // Alice patch start 0053\
        if (ToolbarPositionController.wasAliceBottomBarNewTabButtonClickedRecently()) {\
            return RectStart.BOTTOM_CENTER;\
        }\
        // Alice patch end 0053' "$path3"

# 将动画起点对齐到底栏新建标签按钮。
sed -i '/^            initialRect\.offset(0, -heightDifference);$/a\
        // Alice patch start 0053\
        if (ToolbarPositionController.wasAliceBottomBarNewTabButtonClickedRecently()) {\
            Rect aliceAnchorRect = new Rect();\
            View aliceAnchor = getAliceBottomBarNewTabAnchor(aliceAnchorRect);\
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
        // Alice patch end 0053' "$path3"

# 新增底栏新建标签按钮锚点方法。
sed -i '/^    private int getBottomControlsHeightForTab($/i\
    // Alice patch start 0053\
    private @Nullable View getAliceBottomBarNewTabAnchor(Rect aliceAnchorRect) {\
        if (!BottomBarConfigUtils.isBottomBarEnabled(getContext())) return null;\
        View aliceBottomBar =\
                mAnimationHostView.findViewById(\
                        org.chromium.chrome.browser.ui.bottombar.R.id\
                                .bottom_bar_container);\
        if (aliceBottomBar == null) return null;\
        View aliceNewTabButton =\
                aliceBottomBar.findViewById(\
                        org.chromium.chrome.browser.ui.bottombar.R.id.new_tab_button);\
        return aliceNewTabButton != null\
                        \&\& aliceNewTabButton.getGlobalVisibleRect(aliceAnchorRect)\
                ? aliceNewTabButton\
                : null;\
    }\
    // Alice patch end 0053\
\
' "$path3"
