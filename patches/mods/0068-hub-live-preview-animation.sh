#!/bin/bash
# Hub 预览动画：逐帧读取网格卡片位置，避免预览图与卡片错位。

set -e

path1="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimationData.java"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
path3="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"

# 检测是否已应用
if grep -q 'Alice patch start 0068' "$path1"; then
    exit 100
fi

# 动画数据保存实时卡片位置供应商。
sed -i '/^import android\.util\.Size;$/a\
// Alice patch start 0068\
import java.util.function.Supplier;\
// Alice patch end 0068' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private final int mBottomMargin;$/a\
    // Alice patch start 0068\
    private @Nullable Supplier<@Nullable Rect> mLiveCardRectSupplier;\
    // Alice patch end 0068' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^    \/\*\* Returns whether to use the fallback animation\. \*\/$/,/^    }$/c\
    public boolean shouldUseFallbackAnimation() {\
        return mUseFallbackAnimation;\
    }\
\
    // Alice patch start 0068\
    public void setLiveCardRectSupplier(@Nullable Supplier<@Nullable Rect> supplier) {\
        mLiveCardRectSupplier = supplier;\
    }\
\
    public @Nullable Supplier<@Nullable Rect> getLiveCardRectSupplier() {\
        return mLiveCardRectSupplier;\
    }\
    // Alice patch end 0068' "$path1"

# 动画数据发布时绑定实时卡片位置查询。
sed -i '/^                                    bottomMargin));$/a\
        // Alice patch start 0068\
        @Nullable ShrinkExpandAnimationData aliceAnimationData =\
                animationDataSupplier.get();\
        if (aliceAnimationData != null) {\
            aliceAnimationData.setLiveCardRectSupplier(\
                    () -> {\
                        Rect aliceLiveRect = coordinator.getTabThumbnailRect(tabId);\
                        if (aliceLiveRect.isEmpty()) return null;\
                        Rect aliceHubRect = new Rect();\
                        hubContainerView.getGlobalVisibleRect(aliceHubRect);\
                        aliceLiveRect.offset(-aliceHubRect.left, -aliceHubRect.top);\
                        int aliceBottomMargin = 0;\
                        if (mIsBottomBarEnabledOnGts) {\
                            EdgeToEdgeController aliceEdgeToEdge =\
                                    mEdgeToEdgeSupplier.get();\
                            if (aliceEdgeToEdge != null) {\
                                aliceBottomMargin +=\
                                        aliceEdgeToEdge.getSystemBottomInsetPx();\
                            }\
                            aliceBottomMargin += mBottomBarHeight;\
                        }\
                        aliceLiveRect.bottom =\
                                Math.min(\
                                        aliceLiveRect.bottom,\
                                        hubContainerView.getHeight() - aliceBottomMargin);\
                        return aliceLiveRect;\
                    });\
        }\
        // Alice patch end 0068
' "$path2"

# 动画帧中按进度插值实时卡片位置。
sed -i '/^import java\.util\.function\.DoubleConsumer;$/a\
// Alice patch start 0068\
import java.util.function.Supplier;\
// Alice patch end 0068' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^        Interpolator interpolator = getInterpolator(mAnimationType);$/a\
        // Alice patch start 0068\
        shrinkExpandAnimator.addUpdateListener(\
                animation -> mAliceLiveFraction = animation.getAnimatedFraction());\
        mAlicePreDrawListener =\
                () -> {\
                    Supplier<@Nullable Rect> aliceLiveCardSupplier =\
                            animationData.getLiveCardRectSupplier();\
                    @Nullable ShrinkExpandAnimator aliceLiveAnimator = mShrinkExpandAnimator;\
                    if (aliceLiveCardSupplier == null || aliceLiveAnimator == null) return true;\
                    Rect aliceLiveCard = aliceLiveCardSupplier.get();\
                    if (aliceLiveCard == null || aliceLiveCard.isEmpty()) return true;\
                    float aliceFraction = mAliceLiveFraction;\
                    Rect aliceFrom = isShrink ? initialRect : aliceLiveCard;\
                    Rect aliceTo = isShrink ? aliceLiveCard : finalRect;\
                    aliceLiveAnimator.setRect(\
                            new Rect(\
                                    Math.round(aliceFrom.left + (aliceTo.left - aliceFrom.left) * aliceFraction),\
                                    Math.round(aliceFrom.top + (aliceTo.top - aliceFrom.top) * aliceFraction),\
                                    Math.round(aliceFrom.right + (aliceTo.right - aliceFrom.right) * aliceFraction),\
                                    Math.round(\
                                            aliceFrom.bottom\
                                                    + (aliceTo.bottom - aliceFrom.bottom)\
                                                            * aliceFraction)));\
                    return true;\
                };\
        mHubContainerView.getViewTreeObserver().addOnPreDrawListener(mAlicePreDrawListener);\
        // Alice patch end 0068
' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0068\
import android.view.ViewTreeObserver;\
// Alice patch end 0068' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private boolean mLayoutSatisfied;$/a\
    // Alice patch start 0068\
    private float mAliceLiveFraction;\
    private ViewTreeObserver.@Nullable OnPreDrawListener mAlicePreDrawListener;\
    // Alice patch end 0068' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private void resetState() {$/a\
        // Alice patch start 0068\
        if (mAlicePreDrawListener != null) {\
            mHubContainerView.getViewTreeObserver()\
                    .removeOnPreDrawListener(mAlicePreDrawListener);\
            mAlicePreDrawListener = null;\
        }\
        // Alice patch end 0068' "$path3"

# 首次显示和收缩结束时使用实时卡片位置。
sed -i '/^                        mShrinkExpandImageView\.setVisibility(View\.VISIBLE);$/a\
                        // Alice patch start 0068\
                        if (!isShrink) {\
                            Supplier<@Nullable Rect> aliceStartSupplier =\
                                    animationData.getLiveCardRectSupplier();\
                            if (aliceStartSupplier != null) {\
                                Rect aliceStartCard = aliceStartSupplier.get();\
                                if (aliceStartCard != null \&\& !aliceStartCard.isEmpty()) {\
                                    assumeNonNull(mShrinkExpandAnimator)\
                                            .setRect(aliceStartCard);\
                                }\
                            }\
                        }\
                        // Alice patch end 0068' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^                        mShrinkExpandImageView\.resetKeepingBitmap(animationData\.getFinalRect());$/c\
                        // Alice patch start 0068\
                        Rect aliceEndRect = animationData.getFinalRect();\
                        if (isShrink) {\
                            Supplier<@Nullable Rect> aliceEndSupplier =\
                                    animationData.getLiveCardRectSupplier();\
                            if (aliceEndSupplier != null) {\
                                Rect aliceEndCard = aliceEndSupplier.get();\
                                if (aliceEndCard != null \&\& !aliceEndCard.isEmpty()) {\
                                    aliceEndRect = aliceEndCard;\
                                }\
                            }\
                        }\
                        mShrinkExpandImageView.resetKeepingBitmap(aliceEndRect);\
                        // Alice patch end 0068' "$path3"
