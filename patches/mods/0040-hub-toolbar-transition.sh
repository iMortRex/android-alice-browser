#!/bin/bash
# 进入或退出 Hub 时，将真实工具栏按当前位置滑出或滑回。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0040' "$path1"; then
    exit 100
fi

sed -i '/^import org\.chromium\.ui\.insets\.InsetObserver;$/a\
// Alice patch start 0040\
import org.chromium.ui.interpolators.Interpolators;\
// Alice patch end 0040' "$path1"

sed -i '/^    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;$/a\
    // Alice patch start 0040\
    private static final long ALICE_HUB_TOOLBAR_TRANSITION_DURATION_MS = 250;\
    // Alice patch end 0040' "$path1"

sed -i '/^    private int getNavigationBarHeight() {$/i\
    // Alice patch start 0040\
    void setAliceHubToolbarTransition(boolean enteringHub, boolean animate) {\
        View toolbarView = mControlContainer.getView();\
        boolean toolbarOnBottom =\
                mCurrentPosition.get() == ControlsPosition.BOTTOM\
                        || !isToolbarConfiguredToShowOnTop();\
        int navigationBarHeight = toolbarOnBottom ? getNavigationBarHeight() : 0;\
        float toolbarHeight =\
                toolbarView.getHeight() > 0\
                        ? toolbarView.getHeight()\
                        : mControlContainer.getToolbarHeight();\
        float hiddenOffset =\
                toolbarOnBottom ? toolbarHeight + navigationBarHeight : -toolbarHeight;\
        float targetTranslationY = enteringHub ? hiddenOffset : 0f;\
        long duration =\
                animate ? ALICE_HUB_TOOLBAR_TRANSITION_DURATION_MS : 0;\
        var interpolator =\
                enteringHub\
                        ? Interpolators.EMPHASIZED_ACCELERATE\
                        : Interpolators.EMPHASIZED_DECELERATE;\
\
        toolbarView.animate().cancel();\
        toolbarView\
                .animate()\
                .translationY(targetTranslationY)\
                .setDuration(duration)\
                .setInterpolator(interpolator)\
                .start();\
\
        View navigationBarBackground = mNavigationBarBackgroundContainer;\
        if (navigationBarBackground != null) {\
            float navigationTargetTranslationY =\
                    toolbarOnBottom && enteringHub ? navigationBarHeight : 0f;\
            navigationBarBackground.animate().cancel();\
            navigationBarBackground\
                    .animate()\
                    .translationY(navigationTargetTranslationY)\
                    .setDuration(duration)\
                    .setInterpolator(interpolator)\
                    .start();\
        }\
    }\
    // Alice patch end 0040\
\
' "$path1"

sed -i '/^                        updateForLayout(layoutType);$/a\
                            // Alice patch start 0040\
                            if (layoutType == LayoutType.HUB\
                                    \&\& mToolbarPositionController != null) {\
                                mToolbarPositionController.setAliceHubToolbarTransition(\
                                        /* enteringHub= */ true, /* animate= */ true);\
                            }\
                            // Alice patch end 0040' "$path2"

sed -i '/^                            mIsTabSwitcherFinishedShowingSupplier\.set(false);$/a\
                            // Alice patch start 0040\
                            if (mToolbarPositionController != null) {\
                                mToolbarPositionController.setAliceHubToolbarTransition(\
                                        /* enteringHub= */ false, /* animate= */ true);\
                            }\
                            // Alice patch end 0040' "$path2"
