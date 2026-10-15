#!/bin/bash
# 新建标签页动画：从「屏幕底部中间」向上铺满整个屏幕
#
# 卡片是 Hub 的 ShrinkExpandImageView，矩形由 ShrinkExpandHubLayoutAnimatorProvider 决定：
#   - 起点：Hub 容器的底部中间（卡片大小沿用上游的 0.2 倍）；
#   - 终点：整个 Hub 容器（含底部工具栏那块），铺满屏幕且左右对称；
#   - HubLayout 里 rectStart 固定成 BOTTOM_CENTER，圆角才是 {r, r, 0, 0}（左右一致）；
#   - 新建标签页不吃 0027 的 56dp 工具栏留白（矩形已经算到屏幕底部了）。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path4="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"

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
