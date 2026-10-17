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

# 检测是否已应用
if grep -q 'Alice patch start 0029' "$path1"; then
    exit 100
fi

# 1) 工具栏配置在底部时，不按“在顶部”处理
sed -i '/^    public static boolean shouldShowToolbarOnTop(@Nullable Tab tab) {$/a\
        // Alice patch start 0029\
        if (!isToolbarConfiguredToShowOnTop()) return false;\
        // Alice patch end 0029' "$path1"

# 2) 动画的两个矩形：起点 = 容器底部中间，终点 = 整个容器
sed -i '/^        Rect finalRect = animationData.getFinalRect();$/a\
        // Alice patch start 0029\
        if (mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB) {\
            int aliceCardW = initialRect.width();\
            int aliceCardH = initialRect.height();\
            int aliceContainerW = mHubContainerView.getWidth();\
            int aliceContainerH = mHubContainerView.getHeight();\
            initialRect =\
                    new Rect(\
                            (aliceContainerW - aliceCardW) / 2,\
                            aliceContainerH - aliceCardH,\
                            (aliceContainerW + aliceCardW) / 2,\
                            aliceContainerH);\
            finalRect = new Rect(0, 0, aliceContainerW, aliceContainerH);\
        }\
        // Alice patch end 0029' "$path2"

# 3) 卡片本体也要摆到同一个起点（否则动画会拿卡片的左上角当基准偏移）
sed -i 's|^\( *\)mShrinkExpandImageView.resetKeepingBitmap(animationData.getInitialRect());$|\1// Alice patch start 0029\n\1Rect aliceViewRect = animationData.getInitialRect();\n\1if (mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB) {\n\1    int aliceCardW = aliceViewRect.width();\n\1    int aliceCardH = aliceViewRect.height();\n\1    int aliceContainerW = mHubContainerView.getWidth();\n\1    int aliceContainerH = mHubContainerView.getHeight();\n\1    aliceViewRect =\n\1            new Rect(\n\1                    (aliceContainerW - aliceCardW) / 2,\n\1                    aliceContainerH - aliceCardH,\n\1                    (aliceContainerW + aliceCardW) / 2,\n\1                    aliceContainerH);\n\1}\n\1mShrinkExpandImageView.resetKeepingBitmap(aliceViewRect);\n\1// Alice patch end 0029|' "$path2"

# 4) 动画结束时同样按容器铺满，避免最后一帧缩回旧矩形
sed -i 's|^\( *\)mShrinkExpandImageView.resetKeepingBitmap(animationData.getFinalRect());$|\1// Alice patch start 0029\n\1mShrinkExpandImageView.resetKeepingBitmap(\n\1        mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB\n\1                ? new Rect(0, 0, mHubContainerView.getWidth(), mHubContainerView.getHeight())\n\1                : animationData.getFinalRect());\n\1// Alice patch end 0029|' "$path2"

# 5) 起点终点都是底部居中：圆角才会是 {r, r, 0, 0}（左右一致）
sed -i 's|^\( *\)@RectStart int rectStart = isBottomBarInGts ? RectStart\.BOTTOM_CENTER : RectStart\.TOP;$|\1@RectStart int rectStart = isBottomBarInGts ? RectStart.BOTTOM_CENTER : RectStart.TOP;\n\1// Alice patch start 0029\n\1rectStart = RectStart.BOTTOM_CENTER;\n\1// Alice patch end 0029|' "$path3"

# 6) 新建标签页不吃 0027 的 56dp 工具栏留白
sed -i 's|^\( *\)mView.setTranslationY(translationY + searchBoxGap);$|\1// Alice patch start 0029\n\1mView.setTranslationY(\n\1        translationY + (mInitialRect.bottom == mFinalRect.bottom ? 0 : searchBoxGap));\n\1// Alice patch end 0029|' "$path4"

# === 「新建标签页 / 开发者工具」的弹出动画起点 ===
# 7) NewTabAnimationUtils：新增「右下角」起点（初始小卡片贴右下角，再往左上铺满）
sed -i 's|^        RectStart\.BOTTOM_CENTER$|        // Alice patch start 0029\n        RectStart.BOTTOM_CENTER,\n        RectStart.BOTTOM_RIGHT\n        // Alice patch end 0029|' "$path5"
sed -i 's|^        int BOTTOM_CENTER = 5;$|        // Alice patch start 0029\n        int BOTTOM_CENTER = 5;\n        int BOTTOM_RIGHT = 6;\n        // Alice patch end 0029|' "$path5"
sed -i 's|^        } else {$|        } else if (rectStart == RectStart.BOTTOM_RIGHT) {\n            // Alice patch start 0029\n            // 右下角起手：初始小卡片贴在右下角，再往左上铺满\n            int aliceRight = finalRect.right;\n            initialRect.right = aliceRight;\n            initialRect.left = aliceRight - initialWidth;\n            finalRect.left = aliceRight - finalWidth;\n            int aliceBottom = finalRect.bottom;\n            initialRect.top = aliceBottom - initialHeight;\n            initialRect.bottom = aliceBottom;\n            finalRect.top = aliceBottom - finalHeight;\n            // Alice patch end 0029\n        } else {|' "$path5"

# 8) NewTabAnimationLayout：区分「开发者工具」和「新建标签页」
#    - 开发者工具（devtools:// 标签页）：右下角 → 左上角
#    - 新建标签页（工具栏的新标签页按钮 / 长按「标签页」后的「新建标签页」）：从新标签页按钮处往上缩放
sed -i '/^                || tabLaunchType == TabLaunchType\.FROM_LONGPRESS_FOREGROUND_IN_GROUP) {$/,/^        }$/ s|^        }$|        }\n\n        // Alice patch start 0029\n        // 打开开发者工具：从右下角往左上角展开\n        if (newTab.getUrl() != null \&\& "devtools".equals(newTab.getUrl().getScheme())) {\n            return RectStart.BOTTOM_RIGHT;\n        }\n        // 新建标签页（工具栏「新标签页」按钮 / 长按「标签页」后的「新建标签页」/ 应用菜单）：\n        // 从新标签页按钮处往上缩放\n        if (tabLaunchType == TabLaunchType.FROM_CHROME_UI\n                \|\| tabLaunchType == TabLaunchType.FROM_TAB_SWITCHER_UI) {\n            return RectStart.BOTTOM_CENTER;\n        }\n        // Alice patch end 0029|' "$path6"

# 9) NewTabAnimationLayout：右下角起点的圆角（切平右下角、左下角保留圆角）
#    RoundedCornerImageView#setRoundedCorners 的参数顺序是 (topStart, topEnd, bottomStart, bottomEnd)，
#    也就是 [0]=左上 [1]=右上 [2]=左下 [3]=右下；原来无条件把 [2] 切平，对右下角起点正好反了。
sed -i 's|^                startRadii\[2\] = 0;$|                // Alice patch start 0029\n                // 右下角起点：切平右下角、左下角保留圆角\n                startRadii[rectStart == RectStart.BOTTOM_RIGHT ? 3 : 2] = 0;\n                // Alice patch end 0029|' "$path6"

# 10) NewTabAnimationLayout：新建标签页的起点水平对准「标签管理页」（标签页）按钮
#     rectStart 仍是 BOTTOM_CENTER（底部贴边、底部圆角等逻辑不变），只把起点矩形水平挪到按钮中心。
sed -i 's|^        NewTabAnimationUtils.updateRects(rectStart, isRtl, initialRect, finalRect);$|        NewTabAnimationUtils.updateRects(rectStart, isRtl, initialRect, finalRect);\n\n        // Alice patch start 0029\n        // 新建标签页：起点水平对准「标签管理页」按钮（按钮不在时退回底部居中）\n        if (rectStart == RectStart.BOTTOM_CENTER) {\n            View aliceSwitcher = null;\n            if (BottomBarConfigUtils.isBottomBarEnabled(getContext())) {\n                View aliceBottomBar =\n                        mAnimationHostView.findViewById(\n                                org.chromium.chrome.browser.ui.bottombar.R.id\n                                        .bottom_bar_container);\n                if (aliceBottomBar != null) {\n                    aliceSwitcher = aliceBottomBar.findViewById(R.id.tab_switcher_button);\n                }\n            } else {\n                View aliceToolbar = mAnimationHostView.findViewById(R.id.toolbar);\n                if (aliceToolbar != null) {\n                    aliceSwitcher = aliceToolbar.findViewById(R.id.tab_switcher_button);\n                }\n            }\n            Rect aliceSwitcherRect = new Rect();\n            if (aliceSwitcher != null \&\& aliceSwitcher.getGlobalVisibleRect(aliceSwitcherRect)) {\n                initialRect.offset(aliceSwitcherRect.centerX() - initialRect.centerX(), 0);\n            }\n        }\n        // Alice patch end 0029|' "$path6"

# 11) getForegroundRectStart：新建标签页 / 历史记录 / 开发者工具统一走「底部居中」起点
#     第 8 步里的 devtools 特判和底部工具栏分支都被这段整体替换掉（那些分支最终都是左下角）。
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
        // 新建标签页 / 历史记录 / 开发者工具：统一从「标签管理页」按钮处往上缩放\
        return RectStart.BOTTOM_CENTER;\
        // Alice patch end 0029\
    }' "$path6"
