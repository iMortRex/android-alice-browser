#!/bin/bash
# 全屏切换时同步系统栏、browser controls 和 WebContents 视口，避免退出后
# 页面仍使用旧 inset，或工具栏要等下一次滑动才重新可见。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenHtmlApiHandlerBase.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/tab/TabBrowserControlsConstraintsHelper.java"
path6="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeBottomChinMediator.java"
path7="chrome/browser/browser_controls/android/java/src/org/chromium/chrome/browser/browser_controls/BottomControlsStacker.java"
path8="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenHtmlApiHandlerCompat.java"
path9="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path10="chrome/browser/fullscreen/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0042' "$path1"; then
    exit 100
fi

sed -i '/^    private boolean mInTabSwitcherTransition;$/a\
    // Alice patch start 0042\
    private @Nullable Runnable mAliceFullscreenSnapshotReleaseRunnable;\
    // Alice patch end 0042' "$path2"

sed -i '0,/^                            mInTabSwitcherTransition = true;$/{s//                            mInTabSwitcherTransition = true;\
                            \/\/ Alice patch start 0042\
                            cancelAliceFullscreenSnapshotRelease();\
                            releaseAliceFullscreenToolbarSnapshotNow();\
                            \/\/ Alice patch end 0042/}' "$path2"

sed -i 's|^\( *\)mInTabSwitcherTransition = true;$|\1mInTabSwitcherTransition = true;\
\1\/\/ Alice patch start 0042\
\1mCompositorViewHolder.setAliceHubViewportTransition(true);\
\1\/\/ Alice patch end 0042|' "$path2"

sed -i '/^                        if (layoutType == LayoutType.BROWSING) {$/a\
                            // Alice patch start 0042\
                            mCompositorViewHolder.setAliceHubViewportTransition(false);\
                            // Alice patch end 0042\
' "$path2"

# 进入全屏的窗口旋转阶段，保持 bottom controls 在 shown 位置。Android controls
# 本身可以隐藏并由快照覆盖，但不能让 renderer 提前把页面底部展开一个工具栏高度。
# 竖屏不进入该过渡状态；横屏保留完整同步。
sed -i '/^    final class FullscreenTransitionState {$/a\
        // Alice patch start 0042\
        private static volatile boolean sAliceViewportSyncEnabled;\
        private static volatile boolean sAliceEnteringFullscreen;\
\
        public static void setViewportSyncEnabled(boolean enabled) {\
            sAliceViewportSyncEnabled = enabled;\
        }\
\
        public static boolean isViewportSyncEnabled() {\
            return sAliceViewportSyncEnabled;\
        }\
\
        public static void setEnteringFullscreen(boolean entering) {\
            sAliceEnteringFullscreen = entering;\
        }\
\
        public static boolean isEnteringFullscreen() {\
            return sAliceEnteringFullscreen;\
        }\
\
        // Alice patch end 0042\
' "$path10"

# Hub 转场开始释放快照后，updateForLayout 不能再立刻重新捕获一份。
sed -i '/^    private void updateForLayout(@LayoutType int layoutType) {$/,/^    }$/s|            mToolbarPositionController.requestSearchToolbarSnapshotCapture();|            if (layoutType != LayoutType.HUB) {\
                mToolbarPositionController.requestSearchToolbarSnapshotCapture();\
            }|' "$path2"

# 复用搜索工具栏快照，为 HTML 全屏切换提供独立的过渡快照。
sed -i '/^    private int mSearchToolbarSnapshotColor;$/a\
    // Alice patch start 0042\
    private boolean mAliceFullscreenSnapshotVisible;\
    private boolean mAliceFullscreenSnapshotCached;\
    private int mAliceFullscreenSnapshotAttachAttempts;\
    private final Runnable mAliceFullscreenSnapshotEnsureRunnable =\
            this::ensureFullscreenToolbarSnapshotVisible;\
    // Alice patch end 0042' "$path9"

sed -i 's|^                            \&\& mLayerVisibility != LayerVisibility.HIDDEN) {$|                            \&\& mLayerVisibility != LayerVisibility.HIDDEN\
                            \&\& !mAliceFullscreenSnapshotVisible) {|' "$path9"

sed -i '/^    void requestSearchToolbarSnapshotCapture() {$/i\
    // Alice patch start 0042\
    void showFullscreenToolbarSnapshot() {\
        mAliceFullscreenSnapshotVisible = true;\
        mAliceFullscreenSnapshotCached = true;\
        mAliceFullscreenSnapshotAttachAttempts = 0;\
        ensureFullscreenToolbarSnapshotVisible();\
    }\
\
    void hideFullscreenToolbarSnapshot() {\
        mControlContainer\
                .getView()\
                .removeCallbacks(mAliceFullscreenSnapshotEnsureRunnable);\
        mAliceFullscreenSnapshotVisible = false;\
        mAliceFullscreenSnapshotAttachAttempts = 0;\
        updateSearchToolbarSnapshot();\
    }\
\
    void releaseFullscreenToolbarSnapshot() {\
        boolean aliceWasFullscreenSnapshot =\
                mAliceFullscreenSnapshotVisible || mAliceFullscreenSnapshotCached;\
        mAliceFullscreenSnapshotVisible = false;\
        mAliceFullscreenSnapshotCached = false;\
        mAliceFullscreenSnapshotAttachAttempts = 0;\
        if (!aliceWasFullscreenSnapshot) return;\
        View aliceControlContainer = mControlContainer.getView();\
        aliceControlContainer.removeCallbacks(mAliceFullscreenSnapshotEnsureRunnable);\
        discardAliceFullscreenToolbarSnapshot();\
        aliceControlContainer.requestLayout();\
        aliceControlContainer.invalidate();\
    }\
\
    private void discardAliceFullscreenToolbarSnapshot() {\
        ImageView aliceSnapshot = mSearchToolbarSnapshot;\
        if (aliceSnapshot != null) {\
            aliceSnapshot.setVisibility(View.INVISIBLE);\
            aliceSnapshot.setImageDrawable(null);\
            if (aliceSnapshot.getParent() instanceof ViewGroup) {\
                ((ViewGroup) aliceSnapshot.getParent()).removeView(aliceSnapshot);\
            }\
        }\
        mSearchToolbarSnapshot = null;\
        releaseSearchToolbarSnapshot();\
    }\
\
    private @Nullable ViewGroup getFullscreenToolbarSnapshotParent() {\
        View aliceControlContainer = mControlContainer.getView();\
        View aliceOverlayParent =\
                aliceControlContainer\
                        .getRootView()\
                        .findViewById(android.R.id.content);\
        if (aliceOverlayParent instanceof ViewGroup) {\
            return (ViewGroup) aliceOverlayParent;\
        }\
        if (aliceControlContainer.getParent() instanceof ViewGroup) {\
            return (ViewGroup) aliceControlContainer.getParent();\
        }\
        return null;\
    }\
\
    private void ensureFullscreenToolbarSnapshotVisible() {\
        if (!mAliceFullscreenSnapshotVisible) return;\
        View aliceControlContainer = mControlContainer.getView();\
        aliceControlContainer.removeCallbacks(mAliceFullscreenSnapshotEnsureRunnable);\
        captureSearchToolbarSnapshot();\
        updateSearchToolbarSnapshot();\
        ImageView aliceSnapshot = mSearchToolbarSnapshot;\
        ViewGroup aliceExpectedParent = getFullscreenToolbarSnapshotParent();\
        boolean aliceReady =\
                aliceSnapshot != null\
                        \&\& mSearchToolbarSnapshotBitmap != null\
                        \&\& aliceExpectedParent != null\
                        \&\& aliceSnapshot.getParent() == aliceExpectedParent\
                        \&\& aliceSnapshot.isAttachedToWindow()\
                        \&\& aliceSnapshot.getWidth() > 0\
                        \&\& aliceSnapshot.getHeight() > 0;\
        if (aliceSnapshot != null \&\& aliceReady) {\
            aliceSnapshot.setTranslationY(0);\
            aliceSnapshot.setTranslationZ(1);\
            aliceSnapshot.bringToFront();\
            aliceSnapshot.setVisibility(View.VISIBLE);\
        }\
        if (mAliceFullscreenSnapshotAttachAttempts++ < 24) {\
            aliceControlContainer.postOnAnimation(\
                    mAliceFullscreenSnapshotEnsureRunnable);\
        }\
    }\
    // Alice patch end 0042\
\
' "$path9"

sed -i '/^    private void captureSearchToolbarSnapshot() {$/i\
    // Alice patch start 0042\
    private int getFullscreenSnapshotNavigationBarHeight() {\
        View aliceRoot = mControlContainer.getView().getRootView();\
        android.view.WindowInsets aliceInsets = aliceRoot.getRootWindowInsets();\
        if (aliceInsets == null) return 0;\
        WindowInsetsCompat aliceCompatInsets =\
                WindowInsetsCompat.toWindowInsetsCompat(aliceInsets, aliceRoot);\
        return Math.max(\
                aliceCompatInsets\
                        .getInsetsIgnoringVisibility(\
                                WindowInsetsCompat.Type.navigationBars())\
                        .bottom,\
                aliceCompatInsets\
                        .getInsetsIgnoringVisibility(\
                                WindowInsetsCompat.Type.mandatorySystemGestures())\
                        .bottom);\
    }\
    // Alice patch end 0042\
\
' "$path9"

sed -i '/^    private void captureSearchToolbarSnapshot() {$/,/^    private void updateSearchToolbarSnapshot() {$/c\
    private void captureSearchToolbarSnapshot() {\
        View aliceControlContainer = mControlContainer.getView();\
        // Alice patch start 0042\
        if (!mAliceFullscreenSnapshotVisible\
                \&\& !mIsOmniboxFocusedSupplier.get()\
                \&\& mIsTabSwitcherFinishedShowingSupplier.get()) {\
            return;\
        }\
        if (mCurrentPosition.get() != ControlsPosition.BOTTOM\
                || (mLayerVisibility == LayerVisibility.HIDDEN\
                        \&\& !mAliceFullscreenSnapshotVisible)\
                || !(aliceControlContainer.getParent() instanceof ViewGroup)) {\
            return;\
        }\
\
        ViewGroup aliceParent;\
        if (mAliceFullscreenSnapshotVisible) {\
            aliceParent = getFullscreenToolbarSnapshotParent();\
            if (aliceParent == null) return;\
        } else if (aliceControlContainer.getParent() instanceof ViewGroup) {\
            aliceParent = (ViewGroup) aliceControlContainer.getParent();\
        } else {\
            return;\
        }\
        // Alice patch end 0042\
        ImageView aliceSnapshot = mSearchToolbarSnapshot;\
        if (aliceSnapshot != null \&\& aliceSnapshot.getParent() != aliceParent) {\
            if (aliceSnapshot.getParent() instanceof ViewGroup) {\
                ((ViewGroup) aliceSnapshot.getParent()).removeView(aliceSnapshot);\
            }\
            aliceSnapshot = null;\
            mSearchToolbarSnapshot = null;\
        }\
\
        int aliceWidth = aliceControlContainer.getWidth();\
        int aliceToolbarHeight =\
                mControlContainer.getToolbarHeight()\
                        + mControlContainer.getToolbarHairlineHeight();\
        // Alice patch start 0042\
        int aliceNavigationBarHeight = getNavigationBarHeight();\
        if (mAliceFullscreenSnapshotVisible \&\& aliceNavigationBarHeight == 0) {\
            aliceNavigationBarHeight =\
                    getFullscreenSnapshotNavigationBarHeight();\
        }\
        // Alice patch end 0042\
        int aliceSnapshotHeight = aliceToolbarHeight + aliceNavigationBarHeight;\
        int aliceColor = mControlContainer.getToolbarBackgroundColor();\
        if (aliceWidth <= 0 || aliceToolbarHeight <= 0) return;\
\
        boolean aliceSnapshotCreated = false;\
        if (aliceSnapshot == null) {\
            aliceSnapshot = new ImageView(aliceParent.getContext());\
            aliceSnapshot.setClickable(false);\
            aliceSnapshot.setFocusable(false);\
            aliceSnapshot.setImportantForAccessibility(\
                    View.IMPORTANT_FOR_ACCESSIBILITY_NO);\
            aliceSnapshot.setScaleType(ImageView.ScaleType.FIT_XY);\
            aliceSnapshot.setVisibility(View.INVISIBLE);\
            // Alice patch start 0042\
            ViewGroup.LayoutParams aliceSnapshotParams;\
            if (aliceParent instanceof CoordinatorLayout) {\
                CoordinatorLayout.LayoutParams aliceCoordinatorParams =\
                        new CoordinatorLayout.LayoutParams(\
                                ViewGroup.LayoutParams.MATCH_PARENT, aliceSnapshotHeight);\
                aliceCoordinatorParams.gravity = Gravity.BOTTOM;\
                aliceSnapshotParams = aliceCoordinatorParams;\
            } else {\
                android.widget.FrameLayout.LayoutParams aliceFrameParams =\
                        new android.widget.FrameLayout.LayoutParams(\
                                ViewGroup.LayoutParams.MATCH_PARENT, aliceSnapshotHeight);\
                aliceFrameParams.gravity = Gravity.BOTTOM;\
                aliceSnapshotParams = aliceFrameParams;\
            }\
            int aliceIndex = aliceParent.indexOfChild(aliceControlContainer);\
            if (aliceIndex < 0) aliceIndex = aliceParent.getChildCount();\
            aliceParent.addView(aliceSnapshot, aliceIndex, aliceSnapshotParams);\
            // Alice patch end 0042\
            mSearchToolbarSnapshot = aliceSnapshot;\
            aliceSnapshotCreated = true;\
        }\
        assert aliceSnapshot != null;\
\
        if (aliceSnapshotCreated \&\& mSearchToolbarSnapshotBitmap != null) {\
            aliceSnapshot.setImageBitmap(mSearchToolbarSnapshotBitmap);\
        }\
\
        ViewGroup.LayoutParams aliceParams = aliceSnapshot.getLayoutParams();\
        if (aliceParams.height != aliceSnapshotHeight) {\
            aliceParams.height = aliceSnapshotHeight;\
            aliceSnapshot.setLayoutParams(aliceParams);\
        }\
\
        boolean aliceNeedsCapture =\
                mSearchToolbarSnapshotBitmap == null\
                        || mSearchToolbarSnapshotWidth != aliceWidth\
                        || mSearchToolbarSnapshotHeight != aliceSnapshotHeight\
                        || mSearchToolbarSnapshotNavigationBarHeight\
                                != aliceNavigationBarHeight\
                        || mSearchToolbarSnapshotColor != aliceColor;\
        if (aliceNeedsCapture) {\
            aliceSnapshot.setVisibility(View.INVISIBLE);\
            Bitmap aliceBitmap =\
                    Bitmap.createBitmap(\
                            aliceWidth,\
                            aliceSnapshotHeight,\
                            Bitmap.Config.ARGB_8888);\
            android.graphics.Canvas aliceCanvas = new android.graphics.Canvas(aliceBitmap);\
            aliceCanvas.drawColor(aliceColor);\
            View aliceCaptureView =\
                    aliceControlContainer.findViewById(R.id.toolbar_container);\
            if (aliceCaptureView == null) aliceCaptureView = aliceControlContainer;\
            org.chromium.ui.base.ViewUtils.captureBitmap(\
                    aliceCaptureView, aliceCanvas);\
            releaseSearchToolbarSnapshot();\
            mSearchToolbarSnapshotBitmap = aliceBitmap;\
            mSearchToolbarSnapshotWidth = aliceWidth;\
            mSearchToolbarSnapshotHeight = aliceSnapshotHeight;\
            mSearchToolbarSnapshotNavigationBarHeight = aliceNavigationBarHeight;\
            mSearchToolbarSnapshotColor = aliceColor;\
            aliceSnapshot.setImageBitmap(aliceBitmap);\
        }\
        aliceSnapshot.setTranslationY(0);\
        // Alice patch start 0042\
        if (mAliceFullscreenSnapshotVisible) {\
            aliceSnapshot.setTranslationZ(1);\
            aliceSnapshot.bringToFront();\
            aliceSnapshot.setVisibility(View.VISIBLE);\
        } else {\
            aliceSnapshot.setVisibility(View.INVISIBLE);\
        }\
        // Alice patch end 0042\
    }\
\
    private void updateSearchToolbarSnapshot() {' "$path9"

sed -i '/^    private void updateSearchToolbarSnapshot() {$/,/^    }$/c\
    private void updateSearchToolbarSnapshot() {\
        boolean aliceFocused = mIsOmniboxFocusedSupplier.get();\
        boolean aliceFullscreenSnapshot = mAliceFullscreenSnapshotVisible;\
        // Alice patch start 0042\
        boolean aliceShouldShow =\
                (aliceFocused || aliceFullscreenSnapshot)\
                        \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                        \&\& (aliceFullscreenSnapshot\
                                || mLayerVisibility != LayerVisibility.HIDDEN);\
        if (!aliceShouldShow) {\
            if (mSearchToolbarSnapshot != null) {\
                mSearchToolbarSnapshot.setVisibility(View.INVISIBLE);\
            }\
            if (!aliceFocused\
                    \&\& !aliceFullscreenSnapshot\
                    \&\& !mAliceFullscreenSnapshotCached) {\
                releaseSearchToolbarSnapshot();\
            }\
            return;\
        }\
        if (aliceFullscreenSnapshot \&\& mSearchToolbarSnapshotBitmap == null) {\
            captureSearchToolbarSnapshot();\
            if (mSearchToolbarSnapshotBitmap == null) return;\
        }\
\
        ImageView aliceSnapshot = mSearchToolbarSnapshot;\
        if (aliceSnapshot != null\
                \&\& mSearchToolbarSnapshotBitmap != null\
                \&\& aliceSnapshot.isAttachedToWindow()\
                \&\& (aliceSnapshot.getWidth() <= 0\
                        || aliceSnapshot.getHeight() <= 0)) {\
            aliceSnapshot.postOnAnimation(\
                    ToolbarPositionController.this::updateSearchToolbarSnapshot);\
            return;\
        }\
        if (aliceSnapshot != null\
                \&\& mSearchToolbarSnapshotBitmap != null\
                \&\& aliceSnapshot.getWidth() > 0\
                \&\& aliceSnapshot.getHeight() > 0) {\
            aliceSnapshot.setTranslationY(0);\
            if (aliceFullscreenSnapshot) {\
                aliceSnapshot.setTranslationZ(1);\
                aliceSnapshot.bringToFront();\
            } else {\
                moveSearchToolbarSnapshotBelowScrim();\
            }\
            aliceSnapshot.setVisibility(View.VISIBLE);\
        }\
        // Alice patch end 0042\
    }' "$path9"

# System UI 退出动画期间，原生逻辑会延迟 500ms 再更新 viewport。日志确认
# 导航栏避让恰好在这段延迟后才恢复；现在由显式全屏同步处理，不再等待。
sed -i 's|^    private static final long SYSTEM_UI_VIEWPORT_UPDATE_DELAY_MS = 500;$|    // Alice patch start 0042\
    private static final long SYSTEM_UI_VIEWPORT_UPDATE_DELAY_MS = 0;\
    // Alice patch end 0042|' "$path1"

# persistent fullscreen 在 controls 尚未隐藏时就会先变成 true。直接观察
# supplier，确保进入 PENDING 阶段的第一刻就把底部避设置零。
sed -i '/^    private int mAliceNavigationBarWidth;$/a\
    // Alice patch start 0042\
    private static final long ALICE_ENTRY_VIEWPORT_SETTLE_MS = 320;\
    private @Nullable NonNullObservableSupplier<Boolean> mAliceFullscreenModeSupplier;\
    private final Callback<Boolean> mAliceFullscreenModeObserver =\
            this::onAliceFullscreenModeChanged;\
    private boolean mAliceEntryViewportPending;\
    private int mAliceEntryViewportLockedWidth;\
    private int mAliceEntryViewportLockedHeight;\
    private int mAliceEntryViewportWaitFrames;\
    private int mAliceEntryViewportStableFrames;\
    private boolean mAliceEntryControlsHiddenRequested;\
    private int mAliceEntrySystemBarsWaitFrames;\
    private @Nullable Runnable mAliceEntryTransitionReadyCallback;\
    private boolean mAliceExitViewportPending;\
    private int mAliceExitViewportLockedHeight;\
    private int mAliceLastRequestedWebContentsWidth;\
    private int mAliceLastRequestedWebContentsHeight;\
    private boolean mAliceHubViewportTransition;\
    private final Runnable mAliceEntryViewportCommit = this::finishAliceEntryViewport;\
    private final Runnable mAliceExitViewportCommit = this::finishAliceExitViewport;\
    private boolean aliceIsLandscapeLayout() {\
        View aliceContentView = getContentView();\
        if (aliceContentView != null\
                \&\& aliceContentView.isAttachedToWindow()\
                \&\& aliceContentView.getWidth() > aliceContentView.getHeight()\
                \&\& mCompositorView.getWidth() > mCompositorView.getHeight()) {\
            return true;\
        }\
        return getResources().getConfiguration().orientation\
                == android.content.res.Configuration.ORIENTATION_LANDSCAPE;\
    }\
    private boolean aliceIsLandscapeFullscreenTarget() {\
        if (aliceIsLandscapeLayout()) return true;\
        int aliceRequestedOrientation =\
                mActivity == null\
                        ? android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED\
                        : mActivity.getRequestedOrientation();\
        return aliceRequestedOrientation\
                        == android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE\
                || aliceRequestedOrientation\
                        == android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE\
                || aliceRequestedOrientation\
                        == android.content.pm.ActivityInfo\
                                .SCREEN_ORIENTATION_REVERSE_LANDSCAPE\
                || aliceRequestedOrientation\
                        == android.content.pm.ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE;\
    }\
    private boolean aliceIsPortraitFullscreen() {\
        return mBrowserControlsManager != null\
                \&\& mBrowserControlsManager\
                        .getFullscreenManager()\
                        .getPersistentFullscreenMode()\
                \&\& !FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()\
                \&\& !aliceIsLandscapeLayout();\
    }\
    // Alice patch end 0042' "$path1"

# 进入 persistent fullscreen 时底部避让必须立即归零，不能读取正在隐藏的
# controls offset；普通状态继续使用包含导航栏 chin 的 browser controls 总高度。
sed -i '/^        int verticalViewportInsets =$/,/^                        + (aliceInFullscreen ? 0 : mAliceNavigationBarInset);$/c\
        // Alice patch start 0042\
        int verticalViewportInsets;\
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
        // Alice patch end 0042' "$path1"

# 进入全屏后系统栏隐藏和屏幕旋转会连续改变 view 高度。过渡期间保持旧
# WebContents 高度；横屏、系统栏隐藏和连续稳定帧全部就绪后，再一次性提交。
sed -i '/^        if (isAttachedToWindow(view)) {$/i\
        // Alice patch start 0042\
        mAliceLastRequestedWebContentsWidth = webContentsWidth;\
        mAliceLastRequestedWebContentsHeight = webContentsHeight;\
        if (mAliceEntryViewportPending) {\
            View alicePendingContentView = getContentView();\
            boolean alicePendingViewsLandscape =\
                    alicePendingContentView != null\
                            \&\& alicePendingContentView.isAttachedToWindow()\
                            \&\& alicePendingContentView.getWidth()\
                                    > alicePendingContentView.getHeight()\
                            \&\& mCompositorView.getWidth() > mCompositorView.getHeight();\
            if (alicePendingViewsLandscape) {\
                removeCallbacks(mAliceEntryViewportCommit);\
                postOnAnimation(mAliceEntryViewportCommit);\
                return;\
            } else if (aliceIsLandscapeLayout()) {\
                if (mAliceEntryViewportLockedWidth <= 0) {\
                    mAliceEntryViewportLockedWidth = webContentsWidth;\
                }\
                if (mAliceEntryViewportLockedHeight <= 0) {\
                    mAliceEntryViewportLockedHeight = webContentsHeight;\
                }\
                webContentsWidth = mAliceEntryViewportLockedWidth;\
                webContentsHeight = mAliceEntryViewportLockedHeight;\
                return;\
            }\
        } else if (mAliceExitViewportPending) {\
            if (height > width) {\
                removeCallbacks(mAliceExitViewportCommit);\
                postOnAnimation(mAliceExitViewportCommit);\
            } else {\
                if (mAliceExitViewportLockedHeight <= 0) {\
                    mAliceExitViewportLockedHeight = webContentsHeight;\
                }\
                webContentsHeight = mAliceExitViewportLockedHeight;\
            }\
        }\
        // Alice patch end 0042\
\
' "$path1"

# 0032 曾把导航栏 chin 从 browser controls 总高度里拆掉，再由 Compositor 手工
# 补一次导航栏。恢复为单一高度源，退出时 chin 的高度变化会直接通知 WebContents。
sed -i '/^    private int mTotalMinHeight = INVALID_HEIGHT;$/a\
    // Alice patch start 0042\
    private int mAliceLastChinHeight;\
    private boolean mAliceExitingFullscreen;\
    // Alice patch end 0042' "$path7"

sed -i '/^    public BrowserControlsStateProvider getBrowserControls() {$/i\
    // Alice patch start 0042\
    public void setAliceExitingFullscreen(boolean exiting) {\
        mAliceExitingFullscreen = exiting;\
    }\
    // Alice patch end 0042\
\
' "$path7"

sed -i '/^    private void updateBrowserControlsHeight(boolean animate) {$/,/^    }$/c\
    private void updateBrowserControlsHeight(boolean animate) {\
        if (animate) {\
            mBrowserControlsSizer.setAnimateBrowserControlsHeightChanges(true);\
        }\
        // Alice patch start 0042\
        int aliceBottomControlsHeight = mTotalHeight;\
        int aliceBottomControlsMinHeight = mTotalMinHeight;\
        BottomControlsLayer aliceChin = mLayers.get(LayerType.BOTTOM_CHIN);\
        if (aliceChin != null) {\
            int aliceChinHeight = aliceChin.getHeight();\
            if (aliceChinHeight > 0) {\
                mAliceLastChinHeight = aliceChinHeight;\
            } else {\
                aliceChinHeight = mAliceLastChinHeight;\
            }\
            boolean aliceChinAccounted =\
                    aliceChin.getHeight() > 0\
                            \&\& mLayerVisibilities.get(LayerType.BOTTOM_CHIN);\
            if (aliceChinHeight > 0\
                    \&\& aliceChin.getLayerVisibility() != LayerVisibility.HIDDEN\
                    \&\& mAliceExitingFullscreen\
                    \&\& !aliceChinAccounted) {\
                aliceBottomControlsHeight += aliceChinHeight;\
                aliceBottomControlsMinHeight =\
                        Math.max(aliceBottomControlsMinHeight, aliceChinHeight);\
            }\
        }\
        mBrowserControlsSizer.setBottomControlsHeight(\
                aliceBottomControlsHeight, aliceBottomControlsMinHeight);\
        // Alice patch end 0042\
        if (animate) {\
            mBrowserControlsSizer.setAnimateBrowserControlsHeightChanges(false);\
        }\
    }' "$path7"

# fullscreen 时 chin 必须从 bottom controls 中排除；退出后同一次高度计算
# 立即把它补回，不再等待主 toolbar 层从 HIDING 转为 VISIBLE。
sed -i '/^    public @LayerVisibility int getLayerVisibility() {$/a\
        // Alice patch start 0042\
        if (mFullscreenManager.getPersistentFullscreenMode()\
                \&\& FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()) {\
            return LayerVisibility.HIDDEN;\
        }\
        // Alice patch end 0042' "$path6"

# 先退出 layout-fullscreen，再请求系统栏显示。反过来会让 show() 在旧窗口
# 状态下启动，实际 navigationBars inset 要等退出布局完成后才恢复。
sed -i '/^    void showSystemBars(View contentView) {$/,/^    }$/c\
    void showSystemBars(View contentView) {\
        WindowInsetsControllerCompat windowInsetsController = getWindowInsetsController();\
        // Alice patch start 0042\
        if (FullscreenManager.FullscreenTransitionState\
                .isViewportSyncEnabled()) {\
            windowInsetsController.setSystemBarsBehavior(\
                    WindowInsetsControllerCompat.BEHAVIOR_DEFAULT);\
            unsetLayoutFullscreen(contentView);\
            windowInsetsController.show(WindowInsetsCompat.Type.systemBars());\
        } else {\
            windowInsetsController.setSystemBarsBehavior(\
                    WindowInsetsControllerCompat.BEHAVIOR_DEFAULT);\
            windowInsetsController.show(WindowInsetsCompat.Type.systemBars());\
            unsetLayoutFullscreen(contentView);\
        }\
        // Alice patch end 0042\
    }' "$path8"

# 0034 在底置工具栏时使用固定高度。改为至少取 browser controls 的总高度，
# 这样包含系统导航栏 chin，且不再需要在 Compositor 额外叠加导航栏。
sed -i 's|^                aliceBottomControlsInset = aliceToolbarHeight + aliceToolbarHairlineHeight;$|                // Alice patch start 0042\
                aliceBottomControlsInset =\
                        Math.max(\
                                aliceToolbarHeight\
                                        + aliceToolbarHairlineHeight\
                                        + mAliceNavigationBarInset,\
                                mBrowserControlsManager.getBottomControlsHeight());\
                // Alice patch end 0042|' "$path1"

# 替换 0033 的退出收尾：立即恢复原生 controls 流程，同步提交最终视口，并显式
# 请求 Android controls 可见性刷新，避免 offsets 已归零时 showAndroidControls()
# 提前返回，导致工具栏要等下一次滑动才出现。
sed -i '/^    \/\/ Alice patch start 0033$/,/^    \/\/ Alice patch end 0033$/c\
    // Alice patch start 0042\
    public void finishAliceFullscreenExit() {\
        if (!FullscreenManager.FullscreenTransitionState\
                .isViewportSyncEnabled()) {\
            onViewportChanged();\
            tryUpdateControlsAndWebContentsSizing();\
            updateWebContentsSize(getCurrentTab());\
            FullscreenManager.FullscreenTransitionState\
                    .setExitingFullscreen(false);\
            requestRender();\
            View aliceContentView = getContentView();\
            if (aliceContentView != null) {\
                aliceContentView.postInvalidateOnAnimation();\
            }\
            return;\
        }\
        FullscreenManager.FullscreenTransitionState.setExitingFullscreen(false);\
        mControlsResizeView = true;\
        onControlsResizeViewChanged(getWebContents(), /* controlsResizeView= */ true);\
        onBrowserControlsHeightChanged();\
        onViewportChanged();\
        tryUpdateControlsAndWebContentsSizing();\
        updateWebContentsSize(getCurrentTab());\
        onBrowserControlsHeightChanged();\
        requestRender();\
        if (mBrowserControlsManager != null) {\
            mBrowserControlsManager.refreshAliceAndroidControlsVisibility();\
        }\
        View aliceContentView = getContentView();\
        if (aliceContentView != null) {\
            aliceContentView.postInvalidateOnAnimation();\
        }\
    }\
\
    public void applyAliceFullscreenExitViewport() {\
        if (!FullscreenManager.FullscreenTransitionState\
                .isViewportSyncEnabled()) {\
            return;\
        }\
        mControlsResizeView = true;\
        onControlsResizeViewChanged(getWebContents(), /* controlsResizeView= */ true);\
        onBrowserControlsHeightChanged();\
        if (mBrowserControlsManager != null) {\
            mBrowserControlsManager.showAndroidControls(/* animate= */ false);\
            mBrowserControlsManager.refreshAliceAndroidControlsVisibility();\
        }\
        onViewportChanged();\
        updateWebContentsSize(getCurrentTab());\
        onBrowserControlsHeightChanged();\
        requestRender();\
        View aliceContentView = getContentView();\
        if (aliceContentView != null) {\
            aliceContentView.requestApplyInsets();\
            aliceContentView.requestLayout();\
            aliceContentView.invalidate();\
        }\
    }\
\
    public void applyAliceFullscreenEntryViewport() {\
        if (!mAliceEntryViewportPending) {\
            mAliceEntryViewportPending = true;\
            mAliceEntryViewportWaitFrames = 0;\
            mAliceEntryViewportStableFrames = 0;\
            mAliceEntryControlsHiddenRequested = false;\
            mAliceEntrySystemBarsWaitFrames = 0;\
            mAliceEntryViewportLockedWidth =\
                    mAliceLastRequestedWebContentsWidth > 0\
                            ? mAliceLastRequestedWebContentsWidth\
                            : getViewportSize().x;\
            mAliceEntryViewportLockedHeight =\
                    mAliceLastRequestedWebContentsHeight > 0\
                            ? mAliceLastRequestedWebContentsHeight\
                            : getViewportSize().y;\
        }\
        removeCallbacks(mAliceEntryViewportCommit);\
        postOnAnimationDelayed(\
                mAliceEntryViewportCommit, ALICE_ENTRY_VIEWPORT_SETTLE_MS);\
        onViewportChanged();\
        requestRender();\
    }\
\
    public void setAliceEntryTransitionReadyCallback(@Nullable Runnable callback) {\
        mAliceEntryTransitionReadyCallback = callback;\
    }\
\
    private void finishAliceEntryViewport() {\
        if (!mAliceEntryViewportPending) return;\
        View aliceEntryContentView = getContentView();\
        boolean aliceEntryViewsLandscape =\
                aliceEntryContentView != null\
                        \&\& aliceEntryContentView.isAttachedToWindow()\
                        \&\& aliceEntryContentView.getWidth()\
                                > aliceEntryContentView.getHeight()\
                        \&\& mCompositorView.getWidth() > mCompositorView.getHeight();\
        int aliceRequestedOrientation =\
                mActivity == null\
                        ? android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED\
                        : mActivity.getRequestedOrientation();\
        boolean aliceRequestedLandscape =\
                aliceRequestedOrientation\
                                == android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE\
                        || aliceRequestedOrientation\
                                == android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE\
                        || aliceRequestedOrientation\
                                == android.content.pm.ActivityInfo\
                                        .SCREEN_ORIENTATION_REVERSE_LANDSCAPE\
                        || aliceRequestedOrientation\
                                == android.content.pm.ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE;\
        boolean aliceWaitForLandscape =\
                getResources().getConfiguration().orientation\
                                == android.content.res.Configuration.ORIENTATION_LANDSCAPE\
                        || aliceRequestedLandscape;\
        if (aliceEntryViewsLandscape\
                \&\& mAliceEntryViewportStableFrames++ < 1) {\
            postOnAnimationDelayed(mAliceEntryViewportCommit, 16);\
            return;\
        }\
        if (aliceWaitForLandscape \&\& !aliceEntryViewsLandscape) {\
            if (mAliceEntryViewportWaitFrames++ < 60) {\
                postOnAnimationDelayed(mAliceEntryViewportCommit, 16);\
                return;\
            }\
        }\
        if (!aliceEntryViewsLandscape\
                \&\& (!aliceWaitForLandscape\
                        || mAliceEntryViewportWaitFrames >= 60)) {\
            FullscreenManager.FullscreenTransitionState\
                    .setViewportSyncEnabled(false);\
            FullscreenManager.FullscreenTransitionState\
                    .setEnteringFullscreen(false);\
            mAliceEntryViewportPending = false;\
            mAliceEntryViewportLockedWidth = 0;\
            mAliceEntryViewportLockedHeight = 0;\
            mAliceEntryViewportWaitFrames = 0;\
            mAliceEntryViewportStableFrames = 0;\
            mAliceEntryControlsHiddenRequested = false;\
            mAliceEntrySystemBarsWaitFrames = 0;\
            Runnable aliceOnReady = mAliceEntryTransitionReadyCallback;\
            mAliceEntryTransitionReadyCallback = null;\
            if (aliceOnReady != null) {\
                aliceOnReady.run();\
            }\
            return;\
        }\
        FullscreenManager.FullscreenTransitionState\
                .setViewportSyncEnabled(true);\
        if (!mAliceEntryControlsHiddenRequested) {\
            FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(false);\
            mAliceEntryControlsHiddenRequested = true;\
            if (mBrowserControlsManager != null) {\
                mBrowserControlsManager.hideAndroidControls(/* animate= */ false);\
                mBrowserControlsManager.refreshAliceAndroidControlsVisibility();\
            }\
            postOnAnimationDelayed(mAliceEntryViewportCommit, 16);\
            return;\
        }\
        WindowInsetsCompat aliceEntryInsets =\
                ViewCompat.getRootWindowInsets(getRootView());\
        boolean aliceEntrySystemBarsHidden =\
                aliceEntryInsets != null\
                        \&\& !aliceEntryInsets.isVisible(\
                                WindowInsetsCompat.Type.statusBars())\
                        \&\& !aliceEntryInsets.isVisible(\
                                WindowInsetsCompat.Type.navigationBars());\
        if (!aliceEntrySystemBarsHidden\
                \&\& mAliceEntrySystemBarsWaitFrames++ < 90) {\
            postOnAnimationDelayed(mAliceEntryViewportCommit, 16);\
            return;\
        }\
        FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(false);\
        mAliceEntryViewportPending = false;\
        mAliceEntryViewportLockedWidth = 0;\
        mAliceEntryViewportLockedHeight = 0;\
        mAliceEntryViewportWaitFrames = 0;\
        mAliceEntryViewportStableFrames = 0;\
        mAliceEntryControlsHiddenRequested = false;\
        mAliceEntrySystemBarsWaitFrames = 0;\
        onViewportChanged();\
        onBrowserControlsHeightChanged();\
        updateWebContentsSize(getCurrentTab());\
        Runnable onReady = mAliceEntryTransitionReadyCallback;\
        mAliceEntryTransitionReadyCallback = null;\
        requestRender(onReady);\
    }\
\
    private void finishAliceExitViewport() {\
        if (!mAliceExitViewportPending\
                || !FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()) {\
            mAliceExitViewportPending = false;\
            return;\
        }\
        mAliceExitViewportPending = false;\
        mAliceExitViewportLockedHeight = 0;\
        onViewportChanged();\
        updateWebContentsSize(getCurrentTab());\
        onBrowserControlsHeightChanged();\
        requestRender();\
    }\
\
    private void onAliceFullscreenModeChanged(Boolean fullscreen) {\
        if (!Boolean.TRUE.equals(fullscreen)\
                \&\& !FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()) {\
            FullscreenManager.FullscreenTransitionState\
                    .setEnteringFullscreen(false);\
            FullscreenManager.FullscreenTransitionState\
                    .setExitingFullscreen(false);\
            mAliceEntryViewportPending = false;\
            mAliceExitViewportPending = false;\
            mAliceEntryTransitionReadyCallback = null;\
            removeCallbacks(mAliceEntryViewportCommit);\
            removeCallbacks(mAliceExitViewportCommit);\
            return;\
        }\
        if (Boolean.TRUE.equals(fullscreen)) {\
            if (!aliceIsLandscapeFullscreenTarget()) {\
                FullscreenManager.FullscreenTransitionState\
                        .setEnteringFullscreen(false);\
                FullscreenManager.FullscreenTransitionState\
                        .setViewportSyncEnabled(false);\
                mAliceEntryViewportPending = false;\
                mAliceExitViewportPending = false;\
                mAliceEntryTransitionReadyCallback = null;\
                removeCallbacks(mAliceEntryViewportCommit);\
                removeCallbacks(mAliceExitViewportCommit);\
                return;\
            }\
            FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(true);\
            mAliceExitViewportPending = false;\
            mAliceExitViewportLockedHeight = 0;\
            removeCallbacks(mAliceExitViewportCommit);\
            applyAliceFullscreenEntryViewport();\
        } else {\
            FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(false);\
            mAliceEntryViewportPending = false;\
            mAliceEntryViewportLockedWidth = 0;\
            mAliceEntryViewportLockedHeight = 0;\
            mAliceEntryViewportWaitFrames = 0;\
            mAliceEntryViewportStableFrames = 0;\
            mAliceEntryControlsHiddenRequested = false;\
            mAliceEntrySystemBarsWaitFrames = 0;\
            mAliceEntryTransitionReadyCallback = null;\
            removeCallbacks(mAliceEntryViewportCommit);\
            mAliceExitViewportPending = true;\
            mAliceExitViewportLockedHeight =\
                    mAliceLastRequestedWebContentsHeight > 0\
                            ? mAliceLastRequestedWebContentsHeight\
                            : getViewportSize().y;\
            removeCallbacks(mAliceExitViewportCommit);\
            postOnAnimationDelayed(mAliceExitViewportCommit, 700);\
        }\
    }\
\
    // Alice patch end 0042
' "$path1"

sed -i '/^    public void setBrowserControlsManager(BrowserControlsManager manager) {$/,/^    }$/s|^        mBrowserControlsManager.addObserver(this);$|        // Alice patch start 0042\
        mBrowserControlsManager.addObserver(this);\
        if (mAliceFullscreenModeSupplier != null) {\
            mAliceFullscreenModeSupplier.removeObserver(mAliceFullscreenModeObserver);\
        }\
        mAliceFullscreenModeSupplier =\
                mBrowserControlsManager\
                        .getFullscreenManager()\
                        .getPersistentFullscreenModeSupplier();\
        mAliceFullscreenModeSupplier.addSyncObserverAndPostIfNonNull(\
                mAliceFullscreenModeObserver);\
        // Alice patch end 0042|' "$path1"

sed -i '/^    public void shutDown() {$/,/^    }$/s|^            mBrowserControlsManager.removeObserver(this);$|            // Alice patch start 0042\
            mBrowserControlsManager.removeObserver(this);\
            if (mAliceFullscreenModeSupplier != null) {\
                mAliceFullscreenModeSupplier.removeObserver(mAliceFullscreenModeObserver);\
                mAliceFullscreenModeSupplier = null;\
            }\
            removeCallbacks(mAliceEntryViewportCommit);\
            removeCallbacks(mAliceExitViewportCommit);\
            FullscreenManager.FullscreenTransitionState.setViewportSyncEnabled(false);\
            FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(false);\
            mAliceEntryControlsHiddenRequested = false;\
            mAliceEntrySystemBarsWaitFrames = 0;\
            // Alice patch end 0042|' "$path1"

# 进入过渡期间底部工具栏继续按 shown 状态参与 renderer viewport 计算。Android
# 控件可以不可见，但不能让页面在系统栏/旋转完成前先向上抬头一个工具栏高度。
sed -i '/^        \/\/ This min\/max logic is here to handle changes in the browser controls height\./i\
        // Alice patch start 0042\
        boolean aliceLandscapeTransition =\
                mActivity.getResources().getConfiguration().orientation\
                        == android.content.res.Configuration.ORIENTATION_LANDSCAPE;\
        if (!aliceLandscapeTransition \&\& mControlContainer != null) {\
            android.view.View aliceControlsView = mControlContainer.getView();\
            aliceLandscapeTransition =\
                    aliceControlsView.getWidth() > aliceControlsView.getHeight();\
        }\
        if (!aliceLandscapeTransition) {\
            int aliceRequestedOrientation = mActivity.getRequestedOrientation();\
            aliceLandscapeTransition =\
                    aliceRequestedOrientation\
                                    == android.content.pm.ActivityInfo\
                                            .SCREEN_ORIENTATION_LANDSCAPE\
                            || aliceRequestedOrientation\
                                    == android.content.pm.ActivityInfo\
                                            .SCREEN_ORIENTATION_SENSOR_LANDSCAPE\
                            || aliceRequestedOrientation\
                                    == android.content.pm.ActivityInfo\
                                            .SCREEN_ORIENTATION_REVERSE_LANDSCAPE\
                            || aliceRequestedOrientation\
                                    == android.content.pm.ActivityInfo\
                                            .SCREEN_ORIENTATION_USER_LANDSCAPE;\
        }\
        if (FullscreenManager.FullscreenTransitionState.isEnteringFullscreen()\
                \&\& aliceLandscapeTransition\
                \&\& getControlsPosition() == ControlsPosition.BOTTOM) {\
            topControlsOffset = 0;\
            bottomControlsOffset = 0;\
            topContentOffset = getTopControlsHeight();\
            topControlsMinHeightOffset = getTopControlsMinHeight();\
            bottomControlsMinHeightOffset = getBottomControlsMinHeight();\
        }\
        // Alice patch end 0042\
\
' "$path3"

# 0033 在退出全屏时直接跳过了 BrowserControlsManager 的 SHOWN 约束，使控件
# 等到最后才定位。恢复原生约束流程，让退出时立即走正常的 SHOWN 路径。
sed -i '/^    private void onConstraintsChanged(@BrowserControlsState int constraints) {$/,/^        if (constraints == BrowserControlsState.SHOWN) {$/c\
    private void onConstraintsChanged(@BrowserControlsState int constraints) {\
        // Alice patch start 0042\
        if (!FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()\
                \&\& FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()) {\
            scheduleVisibilityUpdate();\
            return;\
        }\
        // Alice patch end 0042\
\
        if (constraints == BrowserControlsState.SHOWN) {' "$path3"

# offsets 已经归零时 showAndroidControls(false) 会提前返回，不会重新派发可见性。
# 退出收尾显式请求一次同步刷新，确保工具栏不依赖下一次滑动才出现。
sed -i '/^    private void scheduleVisibilityUpdate() {$/i\
    // Alice patch start 0042\
    public void refreshAliceAndroidControlsVisibility() {\
        mForceRelayoutOnVisibilityChange = true;\
        scheduleVisibilityUpdate(/* immediate= */ true);\
    }\
    // Alice patch end 0042\
\
' "$path3"

# 进入全屏观察者执行时 persistent fullscreen 已为 true，立即把视口底部
# 避让置零，不能等待正在隐藏的 browser controls 发完 offset。
sed -i '/^                                \.setExitingFullscreen(false);$/a\
                        // Alice patch start 0042\
                        mBottomControlsStacker.setAliceExitingFullscreen(false);\
                        if (FullscreenManager.FullscreenTransitionState\
                                .isEnteringFullscreen()) {\
                            if (mToolbarPositionController != null) {\
                                mToolbarPositionController.showFullscreenToolbarSnapshot();\
                                mCompositorViewHolder.setAliceEntryTransitionReadyCallback(\
                                        () -> {\
                                            if (mToolbarPositionController != null) {\
                                                mToolbarPositionController\
                                                        .hideFullscreenToolbarSnapshot();\
                                            }\
                                        });\
                            }\
                            mCompositorViewHolder.applyAliceFullscreenEntryViewport();\
                        }\
                        // Alice patch end 0042\
' "$path2"
# 0033 在 tab 校验之前就标记“正在退出”。只有真正会通知观察者的退出才
# 开启退出同步，避免错误 tab 或重复退出把控件永久留在隐藏状态。
sed -i '/^    private boolean shouldSkipEnterFullscreenRequest(FullscreenOptions options) {$/i\
    // Alice patch start 0042\
    private boolean aliceIsFullscreenLandscape() {\
        return mActivity.getResources().getConfiguration().orientation\
                == android.content.res.Configuration.ORIENTATION_LANDSCAPE;\
    }\
    // Alice patch end 0042\
\
' "$path4"

sed -i '/^    public void onEnterFullscreen(Tab tab, FullscreenOptions options) {$/a\
        // Alice patch start 0042\
        FullscreenManager.FullscreenTransitionState.setViewportSyncEnabled(false);\
        FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(true);\
        // Alice patch end 0042\
' "$path4"

sed -i '/^                    enterPersistentFullscreenMode(options);$/i\
                    // Alice patch start 0042\
                    FullscreenManager.FullscreenTransitionState\
                            .setViewportSyncEnabled(false);\
                    // Alice patch end 0042\
\
' "$path4"

sed -i 's|^        if (shouldSkipEnterFullscreenRequest(options)) return;$|        if (shouldSkipEnterFullscreenRequest(options)) {\
            // Alice patch start 0042\
            FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(false);\
            // Alice patch end 0042\
            return;\
        }|' "$path4"

sed -i '/^    public void onExitFullscreen(Tab tab) {$/,/^        if (tab != mTab) return;$/c\
    public void onExitFullscreen(Tab tab) {\
        // Alice patch start 0042\
        if (tab != mTab) return;\
        FullscreenManager.FullscreenTransitionState.setViewportSyncEnabled(\
                aliceIsFullscreenLandscape());\
        FullscreenManager.FullscreenTransitionState.setEnteringFullscreen(false);\
        // Alice patch end 0042\
' "$path4"

sed -i '/^        boolean wasInPersistentFullscreenMode = getPersistentFullscreenMode();$/a\
        // Alice patch start 0042\
        if (wasInPersistentFullscreenMode || mNotifyOnNextExit) {\
            FullscreenManager.FullscreenTransitionState.setExitingFullscreen(true);\
        }\
        // Alice patch end 0042' "$path4"

# 退出时直接把 browser controls 放到完全显示位置，不等待 SHOWN 动画。
sed -i 's|^\( *\)mTab, BrowserControlsState.SHOWN, \(true\|false\));$|\1// Alice patch start 0042\
\1mTab, BrowserControlsState.SHOWN, false);\
\1// Alice patch end 0042|' "$path4"

# 退出期间强制无动画 SHOWN；正常浏览仍使用 BOTH 约束。
sed -i '/^    private void updateEnabledState() {$/,/^    }$/c\
    private void updateEnabledState() {\
        if (mTab.isFrozen()) return;\
        // Alice patch start 0042\
        if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
            update(BrowserControlsState.SHOWN, false);\
        } else {\
            update(BrowserControlsState.BOTH, getConstraints() != BrowserControlsState.HIDDEN);\
        }\
        // Alice patch end 0042\
    }' "$path5"

# 0033 原本在退出期间跳过 WebContents sizing；这里恢复逐帧同步。
sed -i '/^            \/\/ Alice patch start 0033$/,/^            \/\/ Alice patch end 0033$/c\
            // Alice patch start 0042\
            tryUpdateControlsAndWebContentsSizing();\
            // Alice patch end 0042' "$path1"

# Hub 期间网页虽然不可见，但仍会因为顶部工具栏暂时脱离而提交整屏尺寸。
# 顶部地址栏必须保持进入 Hub 前的尺寸，直到返回 BROWSING 的动画完全结束。
sed -i '/^    private void onBrowserControlsHeightChanged() {$/,/^    }$/{
    /^    }$/a\
    // Alice patch start 0042\
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
    // Alice patch end 0042
}' "$path1"

sed -i '/^    private void onBrowserControlsHeightChanged() {$/a\
        // Alice patch start 0042\
        if (aliceShouldDeferBrowserControlsViewportForHub()) return;\
        // Alice patch end 0042\
' "$path1"

sed -i '/^        if (tab == null) return;$/a\
        // Alice patch start 0042\
        if (tab == mTabVisible \&\& aliceShouldDeferBrowserControlsViewportForHub()) return;\
        // Alice patch end 0042\
' "$path1"

sed -i '/^    private void tryUpdateControlsAndWebContentsSizing() {$/a\
        // Alice patch start 0042\
        if (aliceShouldDeferBrowserControlsViewportForHub()) return;\
        // Alice patch end 0042\
' "$path1"

# 全屏退出和系统栏恢复期间必须让 renderer 以 resize-content 模式重新布局，
# 否则只会改变绘制高度，fixed 底部栏仍停在 overlay 的旧位置。
sed -i '/^            boolean controlsResizeView =$/,/^                            || BrowserControlsUtils\.controlsResizeView(mBrowserControlsManager);$/c\
            // Alice patch start 0042\
            boolean aliceFullscreenTransition =\
                    FullscreenManager.FullscreenTransitionState\
                                    .isViewportSyncEnabled()\
                            \&\& (mShowingFullscreen\
                                    || mBrowserControlsManager\
                                            .getFullscreenManager()\
                                            .getPersistentFullscreenMode()\
                                    || FullscreenManager.FullscreenTransitionState\
                                            .isExitingFullscreen());\
            boolean controlsResizeView =\
                    aliceFullscreenTransition\
                            || org.chromium.components.browser_ui.bottomsheet.BottomSheetContent\
                                    .FullWindowPresentationState.isActive()\
                            || BrowserControlsUtils.controlsResizeView(mBrowserControlsManager);\
            // Alice patch end 0042' "$path1"

# controls 每个 offset 帧都同步 WebContents。底置工具栏由 Android view 控制，
# 不能等 controls idle 后再一次性改网页尺寸。
sed -i '/^    public void onControlsOffsetChanged($/,/^    }$/c\
    // Alice patch start 0042\
    public void onControlsOffsetChanged(\
            int topOffset,\
            int topControlsMinHeightOffset,\
            boolean topControlsMinHeightChanged,\
            int bottomOffset,\
            int bottomControlsMinHeightOffset,\
            boolean bottomControlsMinHeightChanged,\
            boolean requestNewFrame,\
            boolean isVisibilityForced) {\
        if (!isVisibilityForced \&\& getResourceManager() != null) {\
            getResourceManager()\
                    .assertResourceExists(AndroidResourceType.DYNAMIC, R.id.control_container);\
        }\
\
        boolean aliceRefreshViewport =\
                mBrowserControlsManager != null\
                        \&\& ((mBrowserControlsManager.getControlsPosition()\
                                                == BrowserControlsStateProvider\
                                                        .ControlsPosition.BOTTOM\
                                        \&\& !mBrowserControlsManager\
                                                .getFullscreenManager()\
                                                .getPersistentFullscreenMode()\
                                        \&\& !FullscreenManager.FullscreenTransitionState\
                                                .isExitingFullscreen())\
                                || (FullscreenManager.FullscreenTransitionState\
                                                .isViewportSyncEnabled()\
                                        \&\& !aliceIsPortraitFullscreen()\
                                        \&\& (mBrowserControlsManager\
                                                        .getFullscreenManager()\
                                                        .getPersistentFullscreenMode()\
                                                || FullscreenManager.FullscreenTransitionState\
                                                        .isExitingFullscreen())));\
        boolean aliceSuppressPortraitFullscreenViewportRefresh =\
                mBrowserControlsManager != null\
                        \&\& (mBrowserControlsManager\
                                        .getFullscreenManager()\
                                        .getPersistentFullscreenMode()\
                                || FullscreenManager.FullscreenTransitionState\
                                        .isExitingFullscreen())\
                        \&\& !FullscreenManager.FullscreenTransitionState\
                                .isViewportSyncEnabled()\
                        \&\& !aliceIsLandscapeLayout();\
        if (!aliceSuppressPortraitFullscreenViewportRefresh) {\
            onViewportChanged();\
        }\
        boolean scrollingWithBciv = mInGesture || mContentViewScrolling;\
        if ((requestNewFrame || topControlsMinHeightChanged || bottomControlsMinHeightChanged)\
                \&\& !scrollingWithBciv) {\
            requestRender();\
        }\
        updateContentViewChildrenDimension();\
        if (aliceRefreshViewport) {\
            updateWebContentsSize(getCurrentTab());\
        }\
        // Alice patch end 0042\
    }' "$path1"

# Android controls 从不可见切到可见时，页面必须和工具栏同一轮回流。
sed -i 's#^    public void onBottomControlsHeightChanged($#    // Alice patch start 0042\
    public void onAndroidControlsVisibilityChanged(int visibility) {\
        if (mBrowserControlsManager != null\
                \&\& ((mBrowserControlsManager.getControlsPosition()\
                                        == BrowserControlsStateProvider.ControlsPosition.BOTTOM\
                                \&\& !mBrowserControlsManager\
                                        .getFullscreenManager()\
                                        .getPersistentFullscreenMode()\
                                \&\& !FullscreenManager.FullscreenTransitionState\
                                        .isExitingFullscreen())\
                        || (FullscreenManager.FullscreenTransitionState\
                                        .isViewportSyncEnabled()\
                                \&\& (mBrowserControlsManager\
                                                .getFullscreenManager()\
                                                .getPersistentFullscreenMode()\
                                        || FullscreenManager.FullscreenTransitionState\
                                                .isExitingFullscreen())))) {\
            onViewportChanged();\
            updateWebContentsSize(getCurrentTab());\
            requestRender();\
        }\
    }\
\
    // Alice patch end 0042\
    @Override\
    public void onBottomControlsHeightChanged(#' "$path1"

# 系统导航栏显隐也会改变 viewport；全屏期间逐次同步，避免只等 controls offset。
sed -i '/^        \/\/ Notify the compositor layout that the size has changed\./i\
        // Alice patch start 0042\
        if (mBrowserControlsManager != null\
                \&\& FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()\
                \&\& (mShowingFullscreen\
                        || mBrowserControlsManager\
                                .getFullscreenManager()\
                                .getPersistentFullscreenMode()\
                        || FullscreenManager.FullscreenTransitionState\
                                .isExitingFullscreen())) {\
            updateWebContentsSize(getCurrentTab());\
            requestRender();\
        }\
        // Alice patch end 0042\
\
' "$path1"

# 退出时不再轮询 controls idle。一次布局后立即刷新视口和工具栏，再补一帧
# 处理地址栏/底栏在导航栏 inset 恢复后的第二次布局。
sed -i '/^    \/\/ Alice patch start 0033$/,/^    \/\/ Alice patch end 0033$/c\
    // Alice patch start 0042\
    private void refreshToolbarAfterFullscreen() {\
        View aliceControlContainer = mControlContainer.getView();\
        if (!FullscreenManager.FullscreenTransitionState\
                .isViewportSyncEnabled()) {\
            Runnable aliceRefresh =\
                    new Runnable() {\
                        @Override\
                        public void run() {\
                            if (!BrowserControlsUtils.areBrowserControlsIdle(\
                                    mBrowserControlsSizer)) {\
                                aliceControlContainer.postOnAnimation(this);\
                                return;\
                            }\
                            aliceControlContainer.postOnAnimation(\
                                    () -> {\
                                        ToolbarManager.this\
                                                .updateToolbarSceneLayerSuppression();\
                                        mCompositorViewHolder\
                                                .finishAliceFullscreenExit();\
                                    });\
                        }\
                    };\
            aliceControlContainer.postOnAnimation(aliceRefresh);\
            return;\
        }\
        aliceControlContainer.postOnAnimation(\
                () -> {\
                    aliceControlContainer.requestApplyInsets();\
                    aliceControlContainer.requestLayout();\
                    mBottomControlsStacker.requestLayerUpdate(false);\
                    mCompositorViewHolder.finishAliceFullscreenExit();\
                    updateToolbarSceneLayerSuppression();\
                    aliceControlContainer.postOnAnimation(\
                            () -> {\
                                aliceControlContainer.requestApplyInsets();\
                                aliceControlContainer.requestLayout();\
                                mBottomControlsStacker.requestLayerUpdate(false);\
                                updateToolbarSceneLayerSuppression();\
                            });\
                });\
    }\
    // Alice patch end 0042
' "$path2"

sed -i '/^    private void refreshToolbarAfterFullscreen() {$/i\
    // Alice patch start 0042\
    private void scheduleAliceFullscreenSnapshotRelease() {\
        cancelAliceFullscreenSnapshotRelease();\
        mAliceFullscreenSnapshotReleaseRunnable =\
                () -> releaseAliceFullscreenToolbarSnapshotNow();\
        mControlContainer\
                .getView()\
                .postOnAnimationDelayed(\
                        mAliceFullscreenSnapshotReleaseRunnable, 700);\
    }\
\
    private void cancelAliceFullscreenSnapshotRelease() {\
        if (mAliceFullscreenSnapshotReleaseRunnable == null) return;\
        mControlContainer\
                .getView()\
                .removeCallbacks(mAliceFullscreenSnapshotReleaseRunnable);\
        mAliceFullscreenSnapshotReleaseRunnable = null;\
    }\
\
    private void releaseAliceFullscreenToolbarSnapshotNow() {\
        cancelAliceFullscreenSnapshotRelease();\
        if (mToolbarPositionController != null) {\
            mToolbarPositionController.releaseFullscreenToolbarSnapshot();\
        }\
        mBottomControlsStacker.setAliceExitingFullscreen(false);\
        mBottomControlsStacker.requestLayerUpdate(false);\
    }\
    // Alice patch end 0042\
\
' "$path2"

# persistent fullscreen 刚变为 false 就立即按已恢复的导航栏停止避让高度更新，
# 不等待 refreshToolbarAfterFullscreen() 的下一动画帧。
sed -i '/^                        refreshToolbarAfterFullscreen();$/i\
                        // Alice patch start 0042\
                        if (FullscreenManager.FullscreenTransitionState\
                                .isViewportSyncEnabled()) {\
                            mBottomControlsStacker.setAliceExitingFullscreen(true);\
                            if (mToolbarPositionController != null) {\
                                mToolbarPositionController.showFullscreenToolbarSnapshot();\
                            }\
                            scheduleAliceFullscreenSnapshotRelease();\
                            updateToolbarSceneLayerSuppression();\
                            mControlContainer.getView().post(\
                                    () -> {\
                                        mBottomControlsStacker.requestLayerUpdate(false);\
                                        mCompositorViewHolder.applyAliceFullscreenExitViewport();\
                                    });\
                        }\
                        // Alice patch end 0042\
' "$path2"
