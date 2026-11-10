#!/bin/bash
# Hub 转场：同步动画进度、TabSwitcher 背景、层级顺序和 viewport 冻结。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path2="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubAnimationConstants.java"
path3="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/phone/NewTabAnimationLayout.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"

# 检测是否已应用
if grep -q 'Alice patch start 0070' "$path1"; then
    exit 100
fi

# 引入 Hub 动画进度常量和观察器。
sed -i '/^import org\.chromium\.chrome\.browser\.hub\.HubExitNavigationHelper;$/a\
// Alice patch start 0070\
import org.chromium.chrome.browser.hub.HubAnimationConstants;\
// Alice patch end 0070' "$path1"

# 增加 Hub 动画进度观察器字段。
sed -i '/^    private boolean mInTabSwitcherTransition;$/a\
    // Alice patch start 0070\
    private final HubAnimationConstants.AliceHubAnimationProgressObserver\
            mAliceHubAnimationProgressObserver;\
    // Alice patch end 0070' "$path1"

# 进入 Hub 时冻结 viewport。
sed -i 's|^\( *\)mInTabSwitcherTransition = true;$|\1mInTabSwitcherTransition = true;\
\1\/\/ Alice patch start 0070\
\1mCompositorViewHolder.setAliceHubViewportTransition(true);\
\1\/\/ Alice patch end 0070|' "$path1"

# 注册 Hub 动画进度观察器，并同步 TabSwitcher 背景 alpha。
sed -i '/^        mHubManagerSupplier = hubManagerSupplier;$/a\
        // Alice patch start 0070\
        mAliceHubAnimationProgressObserver =\
                (showingHub, fraction) -> {\
                    if (mToolbarPositionController == null) return;\
                    mToolbarPositionController.setAliceTabSwitcherBackgroundAlpha(\
                            (showingHub || fraction < 0.95f) ? 0f : 1f);\
                };\
        HubAnimationConstants.setAliceHubAnimationProgressObserver(\
                mAliceHubAnimationProgressObserver);\
        // Alice patch end 0070' "$path1"

# 销毁时移除 Hub 动画进度观察器。
sed -i '/^        mIsDestroyed = true;$/a\
        // Alice patch start 0070\
        HubAnimationConstants.removeAliceHubAnimationProgressObserver(\
                mAliceHubAnimationProgressObserver);\
        // Alice patch end 0070' "$path1"

# 返回 BROWSING 时解除 Hub viewport 冻结。
sed -i '/^                        if (layoutType == LayoutType\.BROWSING) {$/a\
                            // Alice patch start 0070\
                            mCompositorViewHolder.setAliceHubViewportTransition(false);\
                            // Alice patch end 0070\
' "$path1"

# Hub 转场期间暂缓重新捕获搜索工具栏快照。
sed -i '/^    private void updateForLayout(@LayoutType int layoutType) {$/,/^    }$/s|            mToolbarPositionController.requestSearchToolbarSnapshotCapture();|            if (layoutType != LayoutType.HUB) {\
                // Alice patch start 0070\
                mToolbarPositionController.requestSearchToolbarSnapshotCapture();\
                // Alice patch end 0070\
            }|' "$path1"

# 为 HubAnimationConstants 增加 Nullable import。
sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/a\
// Alice patch start 0070\
import org.chromium.build.annotations.Nullable;\
// Alice patch end 0070' "$path2"

# 增加 Hub 动画进度观察器接口、注册和广播方法。
sed -i '/^public class HubAnimationConstants {$/a\
    // Alice patch start 0070\
    public interface AliceHubAnimationProgressObserver {\
        void onProgress(boolean showingHub, float fraction);\
    }\
\
    private static volatile @Nullable AliceHubAnimationProgressObserver\
            sAliceHubAnimationProgressObserver;\
\
    public static void setAliceHubAnimationProgressObserver(\
            @Nullable AliceHubAnimationProgressObserver observer) {\
        sAliceHubAnimationProgressObserver = observer;\
    }\
\
    public static void removeAliceHubAnimationProgressObserver(\
            AliceHubAnimationProgressObserver observer) {\
        if (sAliceHubAnimationProgressObserver == observer) {\
            sAliceHubAnimationProgressObserver = null;\
        }\
    }\
\
    public static void notifyAliceHubAnimationProgress(boolean showingHub, float fraction) {\
        AliceHubAnimationProgressObserver observer = sAliceHubAnimationProgressObserver;\
        if (observer != null) observer.onProgress(showingHub, fraction);\
    }\
    // Alice patch end 0070\
' "$path2"

# 收缩展开动画更新时广播进度。
sed -i '/^        if (mAnimationTracker != null) {$/,/^        }$/c\
        // Alice patch start 0070\
        shrinkExpandAnimator.addUpdateListener(\
                animation -> {\
                    if (mAnimationTracker != null) mAnimationTracker.onUpdate();\
                    notifyAliceHubAnimationProgress(animation.getAnimatedFraction());\
                });\
        // Alice patch end 0070' "$path3"

# 动画开始和结束时广播首尾进度。
sed -i '/^                        if (mAnimationTracker != null) mAnimationTracker.onStart();$/a\
                        // Alice patch start 0070\
                        notifyAliceHubAnimationProgress(0f);\
                        // Alice patch end 0070' "$path3"

# 修改对应源码以完成本补丁功能。
sed -i '/^                            mAnimationTracker.onEnd();$/a\
                        // Alice patch start 0070\
                        notifyAliceHubAnimationProgress(1f);\
                        // Alice patch end 0070' "$path3"

# 新增 Hub 动画进度广播方法。
sed -i '/^    private void resetState() {$/i\
    // Alice patch start 0070\
    private void notifyAliceHubAnimationProgress(float fraction) {\
        if (mAnimationType != HubLayoutAnimationType.SHRINK_TAB\
                \&\& mAnimationType != HubLayoutAnimationType.EXPAND_TAB) {\
            return;\
        }\
        HubAnimationConstants.notifyAliceHubAnimationProgress(\
                mAnimationType == HubLayoutAnimationType.SHRINK_TAB, fraction);\
    }\
    // Alice patch end 0070\
\
' "$path3"

# Hub 布局的 Toolbar alpha 回调同步广播动画进度。
sed -i '/^        mOnToolbarAlphaChange = dependencyHolder\.getOnOverviewAlphaChange();$/c\
        // Alice patch start 0070\
        DoubleConsumer onToolbarAlphaChange =\
                dependencyHolder.getOnOverviewAlphaChange();\
        mOnToolbarAlphaChange =\
                alpha -> {\
                    onToolbarAlphaChange.accept(alpha);\
                    if (isStartingToHide()) {\
                        HubAnimationConstants.notifyAliceHubAnimationProgress(\
                                false, 1f - (float) alpha);\
                    } else if (isStartingToShow()) {\
                        HubAnimationConstants.notifyAliceHubAnimationProgress(\
                                true, (float) alpha);\
                    }\
                };\
        // Alice patch end 0070' "$path4"

# 提高 Hub 根层和动画层的 Z 顺序。
sed -i '/^        mRootView = dependencyHolder\.getHubRootView();$/a\
        // Alice patch start 0070\
        View aliceHubAnimationLayer = mRootView;\
        while (aliceHubAnimationLayer.getParent() instanceof View) {\
            aliceHubAnimationLayer.setTranslationZ(1000f);\
            View aliceHubAnimationParent = (View) aliceHubAnimationLayer.getParent();\
            if (aliceHubAnimationParent.getId() == android.R.id.content) break;\
            aliceHubAnimationLayer = aliceHubAnimationParent;\
        }\
        // Alice patch end 0070' "$path4"

# 修改对应源码以完成本补丁功能。
sed -i '/^        mAnimationHostView = animationHostView;$/a\
        // Alice patch start 0070\
        View aliceAnimationLayer = mAnimationHostView;\
        while (aliceAnimationLayer.getParent() instanceof View) {\
            aliceAnimationLayer.setTranslationZ(1000f);\
            View aliceAnimationParent = (View) aliceAnimationLayer.getParent();\
            if (aliceAnimationParent.getId() == android.R.id.content) break;\
            aliceAnimationLayer = aliceAnimationParent;\
        }\
        // Alice patch end 0070' "$path5"

# 增加 Hub viewport 冻结字段。
sed -i '/^    private int mAliceNavigationBarWidth;$/a\
    // Alice patch start 0070\
    private boolean mAliceHubViewportTransition;\
    // Alice patch end 0070' "$path6"

# Hub 转场期间暂缓 browser controls 触发的 viewport 尺寸提交。
sed -i '/^    private void onBrowserControlsHeightChanged() {$/,/^    }$/{
    /^    }$/a\
    // Alice patch start 0070\
    private boolean aliceShouldDeferBrowserControlsViewportForHub() {\
        return mBrowserControlsManager != null\
                \&\& mBrowserControlsManager.getControlsPosition()\
                        == BrowserControlsStateProvider.ControlsPosition.TOP\
                \&\& (mAliceHubViewportTransition\
                        || (mLayoutManager != null\
                                \&\& (mLayoutManager.getActiveLayoutType()\
                                                == org.chromium.chrome.browser.layouts.LayoutType.HUB\
                                        || mLayoutManager.getNextLayoutType()\
                                                == org.chromium.chrome.browser.layouts.LayoutType.HUB)));\
    }\
\
    public void setAliceHubViewportTransition(boolean transition) {\
        if (mAliceHubViewportTransition == transition) return;\
        mAliceHubViewportTransition = transition;\
        if (transition\
                || mBrowserControlsManager == null\
                || mBrowserControlsManager.getControlsPosition()\
                        != BrowserControlsStateProvider.ControlsPosition.TOP) {\
            return;\
        }\
        onBrowserControlsHeightChanged();\
        onViewportChanged();\
        tryUpdateControlsAndWebContentsSizing();\
        updateWebContentsSize(getCurrentTab());\
        requestRender();\
    }\
    // Alice patch end 0070
}' "$path6"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private void onBrowserControlsHeightChanged() {$/a\
        // Alice patch start 0070\
        if (aliceShouldDeferBrowserControlsViewportForHub()) return;\
        // Alice patch end 0070\
' "$path6"

# 修改对应源码以完成本补丁功能。
sed -i '/^        if (tab == null) return;$/a\
        // Alice patch start 0070\
        if (tab == mTabVisible \&\& aliceShouldDeferBrowserControlsViewportForHub()) return;\
        // Alice patch end 0070\
' "$path6"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private void tryUpdateControlsAndWebContentsSizing() {$/a\
        // Alice patch start 0070\
        if (aliceShouldDeferBrowserControlsViewportForHub()) return;\
        // Alice patch end 0070\
' "$path6"
