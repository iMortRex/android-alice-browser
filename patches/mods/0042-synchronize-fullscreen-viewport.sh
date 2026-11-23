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
path7="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenHtmlApiHandlerCompat.java"
path8="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0042' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

sed -i '/^import org\.chromium\.chrome\.browser\.flags\.ChromeFeatureList;$/a\
// Alice patch start 0042\
import org.chromium.chrome.browser.fullscreen.FullscreenManager;\
// Alice patch end 0042' "$path8"

sed -i '/^    private boolean mInTabSwitcherTransition;$/a\
    // Alice patch start 0042\
    private int mAliceFullscreenExitReadyFrames;\
    // Alice patch end 0042' "$path2"

sed -i '0,/^                            mInTabSwitcherTransition = true;$/{s//                            mInTabSwitcherTransition = true;\
                            \/\/ Alice patch start 0042\
                            finishAliceFullscreenToolbarExit();\
                            \/\/ Alice patch end 0042/}' "$path2"

# 全屏退出只捕获系统导航栏高度；不再使用独立的工具栏 Bitmap 快照。
sed -i '/^    private int mSearchToolbarSnapshotColor;$/a\
    // Alice patch start 0042\
    private int mAliceFullscreenCapturedNavigationBarHeight;\
    // Alice patch end 0042' "$path8"

sed -i '/^    void requestSearchToolbarSnapshotCapture() {$/i\
    // Alice patch start 0042\
    void captureFullscreenNavigationBarHeight() {\
        mAliceFullscreenCapturedNavigationBarHeight =\
                getFullscreenSnapshotNavigationBarHeight();\
    }\
\
    int getAliceFullscreenCapturedNavigationBarHeight() {\
        return mAliceFullscreenCapturedNavigationBarHeight;\
    }\
    // Alice patch end 0042\
\
' "$path8"

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
' "$path8"

sed -i '/^    private void captureSearchToolbarSnapshot() {$/,/^    private void updateSearchToolbarSnapshot() {$/c\
    private void captureSearchToolbarSnapshot() {\
        View aliceControlContainer = mControlContainer.getView();\
        if (!mIsOmniboxFocusedSupplier.get()\
                \&\& mIsTabSwitcherFinishedShowingSupplier.get()) {\
            return;\
        }\
        if (mCurrentPosition.get() != ControlsPosition.BOTTOM\
                || mLayerVisibility == LayerVisibility.HIDDEN\
                || !(aliceControlContainer.getParent() instanceof ViewGroup)) {\
            return;\
        }\
\
        ViewGroup aliceParent = (ViewGroup) aliceControlContainer.getParent();\
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
        int aliceNavigationBarHeight = getNavigationBarHeight();\
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
        aliceSnapshot.setVisibility(View.INVISIBLE);\
    }\
\
    private void updateSearchToolbarSnapshot() {' "$path8"

# System UI 退出动画期间，原生逻辑会延迟 500ms 再更新 viewport。日志确认
# 导航栏避让恰好在这段延迟后才恢复；现在由显式全屏同步处理，不再等待。
sed -i 's|^    private static final long SYSTEM_UI_VIEWPORT_UPDATE_DELAY_MS = 500;$|    // Alice patch start 0042\
    private static final long SYSTEM_UI_VIEWPORT_UPDATE_DELAY_MS = 0;\
    // Alice patch end 0042|' "$path1"

# persistent fullscreen 在 controls 尚未隐藏时就会先变成 true。直接观察
# supplier，确保进入 PENDING 阶段的第一刻就把底部避设置零。
sed -i '/^    private @Nullable BrowserControlsManager mBrowserControlsManager;$/a\
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
    private int mAliceExitFrozenNavigationBarHeight;\
    private int mAliceLastRequestedWebContentsWidth;\
    private int mAliceLastRequestedWebContentsHeight;\
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
        }\
        // Alice patch end 0042\
\
' "$path1"

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
    }' "$path7"

# 提交退出视口后等待该帧真正完成合成，再释放工具栏快照并恢复原生 controls。
# 方法块依赖上游已有的 BrowserControlsManager setter，不能依赖其他补丁的标记。
sed -i '/^    public void setBrowserControlsManager(BrowserControlsManager manager) {$/i\
    // Alice patch start 0042\
    public void finishAliceFullscreenExit() {\
        if (!FullscreenManager.FullscreenTransitionState\
                .isViewportSyncEnabled()) {\
            onViewportChanged();\
            tryUpdateControlsAndWebContentsSizing();\
            updateWebContentsSize(getCurrentTab());\
            FullscreenManager.FullscreenTransitionState\
                    .setExitingFullscreen(false);\
            mAliceExitViewportPending = false;\
            mAliceExitFrozenNavigationBarHeight = 0;\
            requestRender();\
            View aliceContentView = getContentView();\
            if (aliceContentView != null) {\
                aliceContentView.postInvalidateOnAnimation();\
            }\
            return;\
        }\
        mControlsResizeView = true;\
        onControlsResizeViewChanged(getWebContents(), /* controlsResizeView= */ true);\
        onBrowserControlsHeightChanged();\
        onViewportChanged();\
        tryUpdateControlsAndWebContentsSizing();\
        updateWebContentsSize(getCurrentTab());\
        onBrowserControlsHeightChanged();\
        FullscreenManager.FullscreenTransitionState.setExitingFullscreen(false);\
        mAliceExitViewportPending = false;\
        mAliceExitFrozenNavigationBarHeight = 0;\
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
        View aliceContentView = getContentView();\
        if (aliceContentView != null) {\
            aliceContentView.requestApplyInsets();\
            aliceContentView.requestLayout();\
            aliceContentView.invalidate();\
        }\
        requestRender();\
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
    public void setAliceFullscreenExitNavigationBarHeight(int height) {\
        mAliceExitFrozenNavigationBarHeight = Math.max(0, height);\
        if (mAliceExitFrozenNavigationBarHeight > 0\
                \&\& FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()) {\
            mAliceNavigationBarInset = mAliceExitFrozenNavigationBarHeight;\
        }\
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
        mAliceExitFrozenNavigationBarHeight = 0;\
        onViewportChanged();\
        updateWebContentsSize(getCurrentTab());\
        onBrowserControlsHeightChanged();\
        requestRender();\
    }\
\
    private void onAliceFullscreenModeChanged(Boolean fullscreen) {\
        FullscreenManager.FullscreenTransitionState.setPersistentFullscreen(\
                Boolean.TRUE.equals(fullscreen));\
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
            removeCallbacks(mAliceExitViewportCommit);\
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

sed -i '/^    public void onExitFullscreen(Tab tab) {$/a\
        // Alice patch start 0042\
        if (tab != mTab \&\& tab != mTabInFullscreen) return;\
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
sed -i 's|^\( *\)mTab, BrowserControlsState.SHOWN, true);$|\1// Alice patch start 0042\
\1mTab, BrowserControlsState.SHOWN, false);\
\1// Alice patch end 0042|' "$path4"
sed -i 's|^\( *\)TabBrowserControlsConstraintsHelper\.update(mTab, BrowserControlsState\.SHOWN, true);$|\1// Alice patch start 0042\
\1TabBrowserControlsConstraintsHelper.update(mTab, BrowserControlsState.SHOWN, false);\
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

# 退出时逐帧等待 controls idle；连续 3 帧 idle 且底部高度恢复后刷新视口和
# 工具栏，再补一帧处理地址栏/底栏在导航栏 inset 恢复后的第二次布局。
sed -i '/^    private void updateToolbarSceneLayerSuppression() {$/i\
    // Alice patch start 0042\
    private void finishAliceFullscreenToolbarExitWhenReady() {\
        if (!FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()\
                || mToolbarPositionController == null) {\
            mAliceFullscreenExitReadyFrames = 0;\
            return;\
        }\
        int aliceRequiredBottomControlsHeight =\
                mControlContainer.getToolbarHeight()\
                        + mControlContainer.getToolbarHairlineHeight()\
                        + mToolbarPositionController\
                                .getAliceFullscreenCapturedNavigationBarHeight();\
        boolean aliceReady =\
                BrowserControlsUtils.areBrowserControlsIdle(mBrowserControlsSizer)\
                        \&\& mBottomControlsStacker.getTotalHeight()\
                                >= aliceRequiredBottomControlsHeight;\
        mAliceFullscreenExitReadyFrames =\
                aliceReady ? mAliceFullscreenExitReadyFrames + 1 : 0;\
        if (mAliceFullscreenExitReadyFrames < 3) {\
            mControlContainer.getView()\
                    .postOnAnimation(\
                            this::finishAliceFullscreenToolbarExitWhenReady);\
            return;\
        }\
        mAliceFullscreenExitReadyFrames = 0;\
        mCompositorViewHolder.finishAliceFullscreenExit();\
        finishAliceFullscreenToolbarExit();\
    }\
\
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
                                        aliceControlContainer.requestApplyInsets();\
                                        aliceControlContainer.requestLayout();\
                                        mBottomControlsStacker.requestLayerUpdate(false);\
                                        ToolbarManager.this\
                                                .updateToolbarSceneLayerSuppression();\
                                    });\
                        }\
                    };\
            aliceControlContainer.postOnAnimation(aliceRefresh);\
            finishAliceFullscreenToolbarExitWhenReady();\
            return;\
        }\
        aliceControlContainer.postOnAnimation(\
                () -> {\
                    aliceControlContainer.requestApplyInsets();\
                    aliceControlContainer.requestLayout();\
                    mBottomControlsStacker.requestLayerUpdate(false);\
                    updateToolbarSceneLayerSuppression();\
                    aliceControlContainer.postOnAnimation(\
                            () -> {\
                                aliceControlContainer.requestApplyInsets();\
                                aliceControlContainer.requestLayout();\
                                mBottomControlsStacker.requestLayerUpdate(false);\
                                updateToolbarSceneLayerSuppression();\
                            });\
                });\
        finishAliceFullscreenToolbarExitWhenReady();\
    }\
    // Alice patch end 0042
' "$path2"
sed -i '/^    private void refreshToolbarAfterFullscreen() {$/i\
    // Alice patch start 0042\
    private void finishAliceFullscreenToolbarExit() {\
        mAliceFullscreenExitReadyFrames = 0;\
        FullscreenManager.FullscreenTransitionState.setPersistentFullscreen(false);\
        if (mToolbarPositionController != null) {\
            mToolbarPositionController.setAliceFullscreenExitLayout(false);\
        }\
        mBottomControlsStacker.requestLayerUpdate(false);\
        updateToolbarSceneLayerSuppression();\
    }\
    // Alice patch end 0042\
\
' "$path2"
