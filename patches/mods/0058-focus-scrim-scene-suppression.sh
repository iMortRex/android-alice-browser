#!/bin/bash
# 地址栏聚焦：遮罩底边跟随搜索框顶部，抑制 compositor 工具栏残留层。

set -e

path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"

# 检测是否已应用
if grep -q 'Alice patch start 0058' "$path1"; then
    exit 100
fi

# 遮罩处理器补充动画和 Activity 相关 import。
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0058\
import android.app.Activity;\
// Alice patch end 0058' "$path1"
sed -i '/^import androidx\.annotation\.ColorInt;$/a\
// Alice patch start 0058\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0058' "$path1"
sed -i '/^import org\.chromium\.ui\.util\.ColorUtils;$/a\
// Alice patch start 0058\
import java.util.List;\
// Alice patch end 0058' "$path1"

# 注册边界布局和 IME 动画回调。
sed -i '/^        mTabStripHeightSupplier\.addSyncObserverAndPostIfNonNull(mTabStripHeightChangeCallback);$/a\
        // Alice patch start 0058\
        if (mContext instanceof Activity) {\
            View aliceBottomBoundary =\
                    ((Activity) mContext).findViewById(R.id.control_container);\
            if (aliceBottomBoundary != null) {\
                aliceBottomBoundary.addOnLayoutChangeListener(\
                        (v, left, top, right, bottom,\
                                oldLeft, oldTop, oldRight, oldBottom) ->\
                                updateScrimBottomMargin());\
                mAliceScrimBoundaryView = aliceBottomBoundary;\
                mAliceScrimPreDrawListener =\
                        () -> {\
                            alignAliceScrimToSearchBox();\
                            return true;\
                        };\
                aliceBottomBoundary\
                        .getViewTreeObserver()\
                        .addOnPreDrawListener(mAliceScrimPreDrawListener);\
                ViewCompat.setWindowInsetsAnimationCallback(\
                        aliceBottomBoundary,\
                        new WindowInsetsAnimationCompat.Callback(\
                                WindowInsetsAnimationCompat.Callback\
                                        .DISPATCH_MODE_CONTINUE_ON_SUBTREE) {\
                            @Override\
                            public WindowInsetsCompat onProgress(\
                                    WindowInsetsCompat insets,\
                                    List<WindowInsetsAnimationCompat> runningAnimations) {\
                                updateScrimBottomMargin(\
                                        insets.getInsets(WindowInsetsCompat.Type.ime()).bottom);\
                                return insets;\
                            }\
                        });\
            }\
        }\
        // Alice patch end 0058\
' "$path1"

# 底栏变化时重新计算遮罩底部边距。
sed -i '/^                mBottomControlsStacker\.getHeightFromLayerToBottom(LayerType\.BOTTOM_CHIN));$/,/^    }$/c\
        // Alice patch start 0058\
                mBottomControlsStacker.getHeightFromLayerToBottom(LayerType.BOTTOM_CHIN));\
        updateScrimBottomMargin();\
    }\
    // Alice patch end 0058' "$path1"

# 新增遮罩底部边距计算方法。
sed -i '/^    private final BottomControlsStacker mBottomControlsStacker;$/a\
    // Alice patch start 0058\
    private final int[] mAliceScrimToolbarLocation = new int[2];\
    private final int[] mAliceScrimViewLocation = new int[2];\
    private @Nullable View mAliceScrimBoundaryView;\
    private ViewTreeObserver.@Nullable OnPreDrawListener mAliceScrimPreDrawListener;\
    // Alice patch end 0058\
' "$path1"

sed -i '/^    \/\*\* Controls the visibility of scrim overlay\. \*\/$/i\
    // Alice patch start 0058\
    private void updateScrimBottomMargin() {\
        // Alice patch start 0058\
        if (!isBottomToolbarActive()) {\
            updateScrimBottomMargin(0);\
            return;\
        }\
        if (mIsImeAnimationRunning) {\
            if (mCurrentImeAnimationHeight >= 0) {\
                updateScrimBottomMargin(mCurrentImeAnimationHeight);\
            }\
            return;\
        }\
        if (!(mContext instanceof Activity)) {\
            updateScrimBottomMargin(0);\
            return;\
        }\
        View aliceBoundary =\
                ((Activity) mContext).findViewById(R.id.control_container);\
        if (aliceBoundary == null\
                || !KeyboardVisibilityDelegate.getInstance()\
                        .isKeyboardShowing(aliceBoundary)) {\
            updateScrimBottomMargin(0);\
            return;\
        }\
        // Alice patch end 0058\
    }\
\
    private void alignAliceScrimToSearchBox() {\
        if (!isBottomToolbarActive() || !(mContext instanceof Activity)) {\
            if (mOmniboxScrimView != null) mOmniboxScrimView.setTranslationY(0);\
            return;\
        }\
\
        View aliceScrim = mOmniboxScrimView;\
        if (aliceScrim == null || aliceScrim.getParent() == null) {\
            if (!mScrimShown) return;\
            View aliceAnchor = mScrimModel.get(ScrimProperties.ANCHOR_VIEW);\
            if (aliceAnchor == null) return;\
            aliceScrim = findAliceScrimView(aliceAnchor.getRootView());\
            mOmniboxScrimView = aliceScrim;\
        }\
        if (aliceScrim == null || aliceScrim.getVisibility() == View.GONE) return;\
\
        View aliceToolbar = ((Activity) mContext).findViewById(R.id.toolbar);\
        if (aliceToolbar == null || aliceToolbar.getVisibility() != View.VISIBLE) return;\
        aliceToolbar.getLocationInWindow(mAliceScrimToolbarLocation);\
        aliceScrim.getLocationInWindow(mAliceScrimViewLocation);\
        int aliceScrimBottom =\
                mAliceScrimViewLocation[1] + aliceScrim.getHeight();\
        int aliceDelta = mAliceScrimToolbarLocation[1] - aliceScrimBottom;\
        if (aliceDelta != 0) {\
            aliceScrim.setTranslationY(aliceScrim.getTranslationY() + aliceDelta);\
        }\
    }\
\
    private @Nullable View findAliceScrimView(View view) {\
        if (view.getVisibility() != View.GONE \&\& view instanceof ScrimView) {\
            return view;\
        }\
        if (!(view instanceof ViewGroup)) return null;\
        ViewGroup aliceGroup = (ViewGroup) view;\
        for (int i = 0; i < aliceGroup.getChildCount(); i++) {\
            @Nullable View aliceResult = findAliceScrimView(aliceGroup.getChildAt(i));\
            if (aliceResult != null) return aliceResult;\
        }\
        return null;\
    }\
    // Alice patch end 0058\
\
    private void updateScrimBottomMargin(int bottomMargin) {\
        // Alice patch start 0058\
        int aliceBottomMargin =\
                isBottomToolbarActive() ? 0 : Math.max(0, bottomMargin);\
        // Alice patch end 0058\
        mScrimModel.set(ScrimProperties.BOTTOM_MARGIN, aliceBottomMargin);\
    }\
    // Alice patch end 0058\
' "$path1"

# 退出搜索页时搜索框已不存在，遮罩直接停在工具栏 hairline 顶部。
sed -i '/^    public void setVisibility(boolean shouldShow, boolean animate) {$/,/^    }$/c\
    // Alice patch start 0058\
    public void setVisibility(boolean shouldShow, boolean animate) {\
        if (shouldShow == mScrimShown) return;\
\
        if (shouldShow) {\
            mScrimManager.showScrim(mScrimModel);\
        } else {\
            // Alice patch start 0058\
            int aliceToolbarTopInset =\
                    Math.max(\
                            0,\
                            mBottomControlsStacker.getHeightFromLayerToBottom(\
                                    LayerType.BOTTOM_TOOLBAR));\
            mScrimModel.set(ScrimProperties.BOTTOM_MARGIN, aliceToolbarTopInset);\
            // Alice patch end 0058\
            mScrimManager.hideScrim(mScrimModel, animate);\
        }\
\
        mScrimShown = shouldShow;\
    }\
    // Alice patch end 0058\
' "$path1"

# 生命周期结束时移除逐帧对齐监听器。
sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0058\
        if (mAliceScrimBoundaryView != null \&\& mAliceScrimPreDrawListener != null) {\
            ViewTreeObserver aliceBoundaryObserver =\
                    mAliceScrimBoundaryView.getViewTreeObserver();\
            if (aliceBoundaryObserver.isAlive()) {\
                aliceBoundaryObserver.removeOnPreDrawListener(\
                        mAliceScrimPreDrawListener);\
            }\
        }\
        mAliceScrimBoundaryView = null;\
        mAliceScrimPreDrawListener = null;\
        mOmniboxScrimView = null;\
        // Alice patch end 0058\
' "$path1"

# ToolbarManager 记录地址栏聚焦状态并提供导航栏工具栏颜色。
sed -i '/^    private boolean mIsXrFsm;$/a\
    // Alice patch start 0058\
    private boolean mIsUrlBarFocusedForSceneLayer;\
    // Alice patch end 0058' "$path2"
sed -i '/^    public int getPrimaryColor() {$/,/^    }$/c\
    public int getPrimaryColor() {\
        return mLocationBarModel.getPrimaryColor();\
    }\
\
    // Alice patch start 0058\
    public int getToolbarBackgroundColorForNavigationBar() {\
        if (mControlContainer == null) return getPrimaryColor();\
        return mControlContainer.getToolbarBackgroundColor();\
    }\
    // Alice patch end 0058' "$path2"

# 地址栏聚焦时抑制 compositor 工具栏层。
sed -i '/^    private void updateToolbarSceneLayerSuppression() {$/i\
    // Alice patch start 0058\
    private boolean isAliceDefaultNtpBottomOmniboxFocused() {\
        Tab aliceSceneTab = mActivityTabProvider.get();\
        return mIsUrlBarFocusedForSceneLayer\
                \&\& mBrowserControlsSizer.getControlsPosition()\
                        == ControlsPosition.BOTTOM\
                \&\& aliceSceneTab != null\
                \&\& !aliceSceneTab.isIncognito()\
                \&\& UrlUtilities.isNtpUrl(aliceSceneTab.getUrl());\
    }\
    // Alice patch end 0058\
\
' "$path2"
sed -i '/^        mSuppressToolbarSceneLayerSupplier\.set(mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow);$/c\
        // Alice patch start 0058\
        mSuppressToolbarSceneLayerSupplier.set(\
                mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow || mIsUrlBarFocusedForSceneLayer);\
        // Alice patch end 0058' "$path2"
sed -i '/^        mToolbar\.onUrlFocusChange(hasFocus);$/c\
        // Alice patch start 0058\
        mIsUrlBarFocusedForSceneLayer = hasFocus;\
        mToolbar.onUrlFocusChange(hasFocus);\
        updateToolbarSceneLayerSuppression();\
        // Alice patch end 0058\
' "$path2"

# Compositor 使用真实 top/bottom controls 和导航栏 inset 计算网页视口。
sed -i '/^    private boolean mControlsResizeView;$/a\
    // Alice patch start 0058\
    private int mAliceNavigationBarInset;\
    private int mAliceNavigationBarWidth;\
    // Alice patch end 0058' "$path3"
sed -i '/^        int verticalViewportInsets = controlsInsets + webContentsHeightInset;$/c\
        // Alice patch start 0058\
        if (mAliceNavigationBarWidth != getWidth()) {\
            mAliceNavigationBarWidth = getWidth();\
            // Alice patch start 0058\
            mAliceNavigationBarInset =\
                    FullscreenManager.FullscreenTransitionState.isExitingFullscreen()\
                    ? mAliceExitFrozenNavigationBarHeight\
                    : 0;\
            // Alice patch end 0058\
        }\
        View aliceRoot = getRootView();\
        android.view.WindowInsets aliceWindowInsets = aliceRoot.getRootWindowInsets();\
        if (aliceWindowInsets != null) {\
            int aliceCurrentNavBarInset =\
                    androidx.core.view.WindowInsetsCompat.toWindowInsetsCompat(\
                                    aliceWindowInsets, aliceRoot)\
                            .getInsets(\
                                    androidx.core.view.WindowInsetsCompat.Type\
                                            .navigationBars())\
                            .bottom;\
            boolean alicePreserveNavigationBarInset =\
                    FullscreenManager.FullscreenTransitionState\
                            .isExitingFullscreen()\
                            || (mBrowserControlsManager != null\
                                    \&\& mBrowserControlsManager\
                                            .getFullscreenManager()\
                                            .getPersistentFullscreenMode());\
            if (!alicePreserveNavigationBarInset || aliceCurrentNavBarInset > 0) {\
                mAliceNavigationBarInset = aliceCurrentNavBarInset;\
            }\
        }\
        boolean aliceInFullscreen =\
                mBrowserControlsManager != null\
                        && mBrowserControlsManager\
                                .getFullscreenManager()\
                                .getPersistentFullscreenMode();\
        int aliceTopControlsInset = 0;\
        int aliceBottomControlsInset = 0;\
        if (!aliceInFullscreen && mBrowserControlsManager != null) {\
            aliceTopControlsInset =\
                    mControlsResizeView\
                            ? mBrowserControlsManager.getTopControlsHeight()\
                            : mBrowserControlsManager.getTopControlsMinHeight();\
            boolean aliceBottomToolbar =\
                    mBrowserControlsManager.getControlsPosition()\
                            == BrowserControlsStateProvider.ControlsPosition.BOTTOM;\
            if (aliceBottomToolbar) {\
                int aliceToolbarHeight =\
                        getResources()\
                                .getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
                int aliceToolbarHairlineHeight =\
                        getResources()\
                                .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
                // Alice patch start 0058\
                aliceBottomControlsInset =\
                        Math.max(\
                                aliceToolbarHeight\
                                        + aliceToolbarHairlineHeight\
                                        + mAliceNavigationBarInset,\
                                mBrowserControlsManager.getBottomControlsHeight());\
                // Alice patch end 0058\
            } else {\
                if (!mBrowserControlsManager.hasHidingTokens()) {\
                    aliceBottomControlsInset =\
                            mControlsResizeView\
                                    ? mBrowserControlsManager.getBottomControlsHeight()\
                                    : mBrowserControlsManager.getBottomControlsMinHeight();\
                }\
                if (mBrowserControlsManager.getControlsPosition()\
                        == BrowserControlsStateProvider.ControlsPosition.TOP) {\
                    aliceBottomControlsInset += mAliceNavigationBarInset;\
                }\
            }\
        }\
        int verticalViewportInsets;\
        // Alice patch start 0058\
        if (aliceInFullscreen\
                \&\& (FullscreenManager.FullscreenTransitionState\
                                .isViewportSyncEnabled()\
                        || FullscreenManager.FullscreenTransitionState\
                                .isEnteringFullscreen())) {\
            verticalViewportInsets =\
                    aliceTopControlsInset\
                            + webContentsHeightInset;\
        } else {\
            verticalViewportInsets =\
                    aliceTopControlsInset\
                            + aliceBottomControlsInset\
                            + webContentsHeightInset;\
        }\
        // Alice patch end 0058\
        // Alice patch end 0058' "$path3"
