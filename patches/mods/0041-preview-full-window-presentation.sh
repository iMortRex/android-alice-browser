#!/bin/bash
# 让预览网页使用稳定的全窗口展示：同步布局标题栏，并在打开前铺好遮罩。
# 预览面板的 0.9 高度按屏幕计算，并扣除导航栏高度，避免顶部被额外抬高。

set -e

path1="components/browser_ui/bottomsheet/android/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetContent.java"
path2="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetControllerImpl.java"
path3="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabSheetContent.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path6="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path7="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetCoordinator.java"
path8="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetMediator.java"
path9="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path10="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeBottomChinMediator.java"
path11="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"

# 检测是否已应用
if grep -q 'Alice patch start 0041' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

sed -i '/^    private final int mBottomBarHeight;$/a\
// Alice patch start 0041\
    // Alice: generation counter for the deferred shrink/expand rect captures.\
    private int mAliceCaptureGeneration;\
// Alice patch end 0041\
' "$path11"

# 0) 预览网页覆盖当前 Tab 时，背景 Tab 可能被标记为 hidden，但其 ContentView
#    仍附着在窗口。此时保留 visual viewport inset，导航栏避让不会被清零。
sed -i '/^                mTab\.isHidden()$/c\
        // Alice patch start 0041\
                (mTab.isHidden()\
                                \&\& (getContentView() == null\
                                        || !getContentView().isAttachedToWindow()))\
        // Alice patch end 0041' "$path4"

# 0.1) Keep the navigation-bar background owned by the toolbar visible while the
#     full-window preview is covering the toolbar layer.
sed -i '/^    float MAX_HEIGHT_RATIO = 1.0f;$/a\
    // Alice patch start 0041\
    final class FullWindowPresentationState {\
        private static volatile boolean sActive;\
\
        public static void setActive(boolean active) {\
            sActive = active;\
        }\
\
        public static boolean isActive() {\
            return sActive;\
        }\
    }\
    // Alice patch end 0041\
' "$path1"

sed -i '/^        if (aliceParams.height != aliceNavigationBarHeight) {$/,/^        }$/c\
        // Alice patch start 0041\
        if (aliceParams.height != aliceNavigationBarHeight) {\
            aliceParams.height = aliceNavigationBarHeight;\
            aliceBackground.setLayoutParams(aliceParams);\
        }\
        // Alice patch end 0041' "$path6"

sed -i '/^    private @Nullable View mNavigationBarBackground;$/a\
    // Alice patch start 0041\
    private @Nullable View mAliceStartupNavigationBarCover;\
    private boolean mAliceInitialPageReady;\
    // Alice patch end 0041' "$path6"

sed -i '/^    private int getNavigationBarHeight() {$/i\
    // Alice patch start 0041\
    private void updateAliceStartupNavigationBarCover(int navigationBarHeight, View anchor) {\
        if (mAliceInitialPageReady || navigationBarHeight <= 0) {\
            removeAliceStartupNavigationBarCover();\
            return;\
        }\
        View aliceContent = anchor.getRootView().findViewById(android.R.id.content);\
        if (!(aliceContent instanceof ViewGroup)) return;\
        ViewGroup aliceContentGroup = (ViewGroup) aliceContent;\
        View aliceCover = mAliceStartupNavigationBarCover;\
        if (aliceCover == null || aliceCover.getParent() != aliceContentGroup) {\
            removeAliceStartupNavigationBarCover();\
            aliceCover = new View(aliceContentGroup.getContext());\
            aliceCover.setClickable(false);\
            aliceCover.setFocusable(false);\
            aliceCover.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);\
            aliceContentGroup.addView(\
                    aliceCover,\
                    new android.widget.FrameLayout.LayoutParams(\
                            ViewGroup.LayoutParams.MATCH_PARENT,\
                            navigationBarHeight,\
                            Gravity.BOTTOM));\
            mAliceStartupNavigationBarCover = aliceCover;\
        }\
        ViewGroup.LayoutParams aliceCoverParams = aliceCover.getLayoutParams();\
        if (aliceCoverParams.height != navigationBarHeight) {\
            aliceCoverParams.height = navigationBarHeight;\
            aliceCover.setLayoutParams(aliceCoverParams);\
        }\
        aliceCover.setTranslationZ(-1f);\
        aliceCover.setBackgroundColor(mControlContainer.getToolbarBackgroundColor());\
        aliceCover.setVisibility(View.VISIBLE);\
    }\
\
    private void removeAliceStartupNavigationBarCover() {\
        View aliceCover = mAliceStartupNavigationBarCover;\
        if (aliceCover != null && aliceCover.getParent() instanceof ViewGroup) {\
            ViewGroup aliceCoverParent = (ViewGroup) aliceCover.getParent();\
            aliceCover.setVisibility(View.GONE);\
            aliceCoverParent.post(\
                    () -> {\
                        if (aliceCover.getParent() == aliceCoverParent) {\
                            aliceCoverParent.removeView(aliceCover);\
                        }\
                    });\
        }\
        mAliceStartupNavigationBarCover = null;\
    }\
    // Alice patch end 0041\
\
' "$path6"

sed -i '/^        mNavigationBarBackground = null;$/a\
        // Alice patch start 0041\
        removeAliceStartupNavigationBarCover();\
        // Alice patch end 0041' "$path6"

sed -i '/^        aliceBackground.setTranslationY(0);$/a\
        // Alice patch start 0041\
        boolean aliceFullWindowPreview =\
                BottomSheetContent.FullWindowPresentationState.isActive();\
        // Alice patch end 0041' "$path6"

sed -i '/^        int aliceBackgroundColor =$/,/^        aliceBackground.setBackgroundColor(aliceBackgroundColor);$/c\
        int aliceConfiguredBackgroundColor =\
                aliceFullWindowPreview\
                                || mNavigationBarBackgroundColor == Integer.MIN_VALUE\
                        ? mControlContainer.getToolbarBackgroundColor()\
                        : mNavigationBarBackgroundColor;\
        if (!aliceFullWindowPreview) {\
            mNavigationBarBackgroundColor = aliceConfiguredBackgroundColor;\
        }\
        // Alice patch start 0041\
        aliceBackground.setBackgroundColor(aliceConfiguredBackgroundColor);\
        // Alice patch end 0041' "$path6"

sed -i '/^        boolean aliceVisible =$/,/^                                        aliceControlContainer));$/c\
        // Alice patch start 0041\
        Tab aliceStartupTab = mActiveTabSupplier.get();\
        boolean aliceInitialPageLoading =\
                aliceStartupTab == null || aliceStartupTab.isLoading();\
        if (aliceToolbarReady \&\& !aliceInitialPageLoading) {\
            mAliceInitialPageReady = true;\
        }\
        // Alice: suppress the startup navigation-bar cover during search/Omnibox focus.\
        if (aliceToolbarOnBottom\
                \&\& !mAliceInitialPageReady\
                \&\& !mIsOmniboxFocusedSupplier.get()) {\
            updateAliceStartupNavigationBarCover(\
                    aliceNavigationBarHeight, aliceControlContainer);\
        } else {\
            removeAliceStartupNavigationBarCover();\
        }\
        int[] aliceParentLocation = new int[2];\
        int[] aliceRootLocation = new int[2];\
        aliceParent.getLocationInWindow(aliceParentLocation);\
        View aliceRoot = aliceParent.getRootView();\
        aliceRoot.getLocationInWindow(aliceRootLocation);\
        boolean aliceParentReachesWindowBottom =\
                aliceParentLocation[1] + aliceParent.getHeight()\
                        >= aliceRootLocation[1] + aliceRoot.getHeight();\
        if (mAliceTabSwitcherBackgroundAlpha < 0f) {\
            mAliceTabSwitcherBackgroundAlpha =\
                    mIsTabSwitcherFinishedShowingSupplier.get() ? 0f : 1f;\
        }\
        boolean aliceTabSwitcherHidden =\
                mIsTabSwitcherFinishedShowingSupplier.get()\
                        \&\& mAliceTabSwitcherBackgroundAlpha <= 0f;\
        // Alice: suppress the navigation-bar background while search/Omnibox is focused.\
        boolean aliceVisible =\
                aliceToolbarOnBottom\
                        \&\& aliceNavigationBarHeight > 0\
                        \&\& !mIsOmniboxFocusedSupplier.get()\
                        \&\& !aliceTabSwitcherHidden\
                        \&\& !FullscreenManager.FullscreenTransitionState\
                                .isPersistentFullscreen()\
                        \&\& aliceParentReachesWindowBottom\
                        \&\& (aliceFullWindowPreview\
                                || FullscreenManager.FullscreenTransitionState\
                                        .isExitingFullscreen()\
                                || mLayerVisibility != LayerVisibility.HIDDEN\
                                || mIsImeAnimationRunning\
                                || mKeyboardVisibilityDelegate.isKeyboardShowing(\
                                        aliceControlContainer));\
        // Alice patch end 0041' "$path6"

sed -i '/^            boolean controlsResizeView =$/,/^                    BrowserControlsUtils\.controlsResizeView(mBrowserControlsManager);$/c\
        // Alice patch start 0041\
            boolean controlsResizeView =\
                    org.chromium.components.browser_ui.bottomsheet.BottomSheetContent\
                                    .FullWindowPresentationState.isActive()\
                            || BrowserControlsUtils.controlsResizeView(mBrowserControlsManager);\
        // Alice patch end 0041' "$path5"

# 1) 为预览面板提供“全窗口展示”能力，默认不影响其他底部面板
sed -i '/^    default boolean coversBottomControls() {$/i\
    // Alice patch start 0041\
    /**\
     * @return Whether this content should present as a full-window modal immediately. This shows\
     *     the sheet above browser controls and prepares the scrim before opening. System\
     *     navigation bar handling stays with the existing inset/color patches.\
     */\
    default boolean shouldUseFullWindowPresentation() {\
        return false;\
    }\
    // Alice patch end 0041\
\
' "$path1"

sed -i '/^    default boolean coversBottomControls() {$/i\
    // Alice patch start 0041\
    default void onSheetHeightChanged(int sheetHeight) {}\
    // Alice patch end 0041\
\
' "$path1"

sed -i '/^    default boolean coversBottomControls() {$/i\
    // Alice patch start 0041\
    /**\
     * Requests the page background color used by the simulated navigation bar.\
     *\
     * @param callback Receives an ARGB color, or transparent when unavailable.\
     */\
    default void getPageBackgroundColor(org.chromium.base.Callback<Integer> callback) {\
        org.chromium.base.Callback.runNullSafe(callback, Color.TRANSPARENT);\
    }\
    // Alice patch end 0041\
\
' "$path1"

sed -i '/^    default boolean coversBottomControls() {$/i\
    // Alice patch start 0041\
    default int getToolbarBackgroundHeight() {\
        return 0;\
    }\
    // Alice patch end 0041\
\
' "$path1"

sed -i '/^    int getVerticalScrollOffset();$/i\
    // Alice patch start 0041\
    /**\
     * @return Whether non-toolbar touch events should be delivered directly to this content.\
     */\
    default boolean shouldHandleContentTouchEvents() {\
        return false;\
    }\
    // Alice patch end 0041\
\
' "$path1"

# Alice: a negative inset pushes the full-window preview below the container bottom;
# keep it while hiding so the preview slides fully off the screen instead of stopping
# at the navigation-bar top edge.
sed -i '/^        float bottomInsetAdjustment =$/,+1c\
        // Alice patch start 0041\
        // Alice: keep a negative inset while hiding so the full-window preview slides\
        // fully off the screen; positive insets still zero out for the hidden state.\
        float bottomInsetAdjustment =\
                mTargetState == SheetState.HIDDEN\
                        ? (e2eBottomInset < 0 ? e2eBottomInset : 0f)\
                        : currentOffsetPx <= 0\
                                ? 0f\
                                : Math.min(currentOffsetPx, e2eBottomInset);\
        // Alice patch end 0041' "$path8"

# BottomSheet 不参与预览内容区的触摸竞争，标题栏仍保留原有拖动行为。
sed -i '/^        if (!mIsTouchEnabled) return true;$/a\
        // Alice patch start 0041\
        if (mSheetContent != null\
                \&\& mSheetContent.shouldHandleContentTouchEvents()\
                \&\& isTouchEventInSheetContent(e)) {\
            return false;\
        }\
        // Alice patch end 0041' "$path8"

sed -i '/^    void updateCloseButton(/i\
    // Alice patch start 0041\
    private boolean isTouchEventInSheetContent(MotionEvent event) {\
        if (mSheetContent == null) return false;\
        Rect contentBounds = new Rect();\
        if (!mSheetContent.getContentView().getGlobalVisibleRect(contentBounds)) {\
            return false;\
        }\
        // Alice: the title bar overlays the top of the content view, so exclude it\
        // from the content touch area to keep the original sheet drag behavior.\
        contentBounds.top += mSheetContent.getToolbarBackgroundHeight();\
        return contentBounds.contains(\
                (int) event.getRawX(), (int) event.getRawY());\
    }\
    // Alice patch end 0041\
\
' "$path8"

sed -i '/^    private int mPreviousScreenHeight;$/a\
    // Alice patch start 0041\
    private boolean mFullWindowImeCropped;\
    private float mFullWindowPreviewHeightBeforeIme;\
    private int mFullWindowCurrentImeInset;\
    private boolean mFullWindowImeAnimationRunning;\
    private boolean mRestoringFullWindowImeCrop;\
    private @Nullable KeyboardVisibilityDelegate mKeyboardVisibilityDelegate;\
    // Alice patch end 0041\
' "$path7"

sed -i '/^    private InsetObserver mInsetObserver;$/a\
    // Alice patch start 0041\
    private final InsetObserver.WindowInsetObserver mImeResetObserver =\
            new InsetObserver.WindowInsetObserver() {\
                @Override\
                public void onKeyboardInsetChanged(int inset) {\
                    if (inset == 0\
                            \&\& mFullWindowImeCropped\
                            \&\& !mFullWindowImeAnimationRunning) {\
                        mWindow.getDecorView().post(\
                                BottomSheetCoordinator.this::restoreFullWindowImeCrop);\
                    }\
                }\
            };\
    private int mLastImeAnimationInset;\
    private boolean mImeAnimationClosing;\
    private final Runnable mRestoreWhenImeHidden =\
            new Runnable() {\
                @Override\
                public void run() {\
                    if (!mFullWindowImeCropped) return;\
                    boolean keyboardShowing =\
                            mKeyboardVisibilityDelegate != null\
                                    ? mKeyboardVisibilityDelegate\
                                            .isKeyboardShowing(\
                                                    mView)\
                                    : isKeyboardShowing();\
                    if (keyboardShowing) {\
                        if (mWindow != null) {\
                            mWindow.getDecorView().postOnAnimation(this);\
                        }\
                        return;\
                    }\
                    restoreFullWindowImeCrop();\
                }\
            };\
    // Alice patch end 0041\
' "$path7"

sed -i '/^    private static final float HEIGHT_UNSPECIFIED = -1\.0f;$/a\
    // Alice patch start 0041\
    private static final float FULL_WINDOW_PREVIEW_HEIGHT_RATIO = 0.9f;\
    // Alice patch end 0041\
' "$path7"

sed -i '/^        mWindow = window;$/a\
        // Alice patch start 0041\
        mKeyboardVisibilityDelegate = keyboardDelegate;\
        // Alice patch end 0041' "$path7"

sed -i '/^        mIsDestroyed = true;$/a\
        // Alice patch start 0041\
        mView.setClipBounds(null);\
        if (mInsetObserver != null) {\
            mInsetObserver.removeObserver(mImeResetObserver);\
        }\
        if (mWindow != null) {\
            mWindow.getDecorView().removeCallbacks(\
                    mRestoreWhenImeHidden);\
        }\
        // Alice patch end 0041' "$path7"

sed -i '/^        mInsetObserver = insetObserver;$/a\
        // Alice patch start 0041\
        mInsetObserver.addObserver(mImeResetObserver);\
        // Alice patch end 0041' "$path7"

# Alice: the fake navigation bar height tracks the edge-to-edge inset.
sed -i '/^        if (!bottomMarginChanged) return;$/i\
// Alice patch start 0041\
        // Alice: the fake navigation bar tracks the edge-to-edge inset, which is\
        // zero unless the preview is covering the bottom controls.\
        updateAliceNavBarHeight();\
// Alice patch end 0041\
' "$path7"

# Alice: restore the edge-to-edge drawing state immediately on fullscreen exit;
# the inset event that re-enables it arrives a moment late, which briefly left
# the page un-avoiding the navigation bar.
# Alice: gate the bottom chin on the stable fullscreen state; the dispatched
# drawing flag goes stale during rotation and fullscreen transitions, which
# briefly removed the navigation-bar avoidance.
# Alice: the pre-fullscreen inset memory and the exit-instant force flag.
sed -i '/^    private boolean mIsDrawingToEdge;$/a\
// Alice patch start 0041\
    // Alice: the inset captured before fullscreen and a force flag for the exit\
    // instant, because the fullscreen flag and the inset event clear a moment late.\
    private int mAliceInsetBeforeFullscreen;\
    private boolean mAliceForceChin;\
// Alice patch end 0041\
' "$path10"

sed -i '/^    private void updateHeightAndVisibility() {$/,/^        int newHeight = mIsDrawingToEdge ? mEdgeToEdgeBottomInsetPx : 0;$/c\
    private void updateHeightAndVisibility() {\
        // Alice patch start 0041\
        // Alice: gate on the stable fullscreen state; the dispatched drawing flag\
        // goes stale during rotation and fullscreen transitions, which briefly\
        // removed the navigation-bar avoidance.\
        boolean aliceDrawingToEdge =\
                mAliceForceChin\
                        || (!mFullscreenManager.getPersistentFullscreenMode()\
                                \&\& (mIsDrawingToEdge\
                                        || mEdgeToEdgeBottomInsetPx > 0));\
        int newHeight = aliceDrawingToEdge ? mEdgeToEdgeBottomInsetPx : 0;\
        // Alice patch end 0041\
' "$path10"
# Alice: capture the pre-fullscreen inset on enter, restore it at the exit
# instant (the fullscreen flag and the inset event clear a moment late), and
# drop the force once the authoritative inset state arrives.
sed -i '/^    public void onEnterFullscreen(Tab tab, FullscreenOptions options) {$/,/^    }$/c\
    public void onEnterFullscreen(Tab tab, FullscreenOptions options) {\
// Alice patch start 0041\
        // Alice: remember the pre-fullscreen inset for the instant exit restore.\
        mAliceInsetBeforeFullscreen = mEdgeToEdgeBottomInsetPx;\
        updateHeightAndVisibility();\
// Alice patch end 0041\
    }\
' "$path10"

sed -i '/^    public void onExitFullscreen(Tab tab) {$/,/^    }$/c\
    public void onExitFullscreen(Tab tab) {\
// Alice patch start 0041\
        // Alice: at the exit instant the fullscreen flag has not cleared yet, so\
        // restore the pre-fullscreen inset and force the chin on for this frame.\
        if (mAliceInsetBeforeFullscreen > 0) {\
            mEdgeToEdgeBottomInsetPx = mAliceInsetBeforeFullscreen;\
            mIsDrawingToEdge = true;\
            mAliceForceChin = true;\
        }\
        updateHeightAndVisibility();\
// Alice patch end 0041\
    }\
' "$path10"

sed -i '/^    public void onToEdgeChange($/i\
// Alice patch start 0041\
// Alice: the authoritative inset state arrived; drop the exit force.\
// Alice patch end 0041\
' "$path10"

sed -i '/^        mEdgeToEdgeBottomInsetPx = bottomInset;$/a\
// Alice patch start 0041\
        mAliceForceChin = false;\
// Alice patch end 0041\
' "$path10"

# Alice: the chin visibility uses the same stable gate.
sed -i '/^        boolean newVisibility =$/,/^                        \&\& !isKeyboardVisible;$/c\
        boolean newVisibility =\
                aliceDrawingToEdge\
                        \&\& isBottomChinAllowed(\
                                mLayoutManager.getActiveLayoutType(), mEdgeToEdgeBottomInsetPx)\
                        \&\& !isKeyboardVisible;\
' "$path10"

# Alice: hide the stale shrink/expand preview image when a newer animation
# supersedes it; rapid switching and grid scrolling left it lingering offset.
sed -i '/^    private void onAnimationDataAvailable(ShrinkExpandAnimationData animationData) {$/,/^    }$/c\
    private void onAnimationDataAvailable(ShrinkExpandAnimationData animationData) {\
        if (mShrinkExpandImageView == null) return;\
        if (mAnimatorSupplier.get() != null) {\
// Alice patch start 0041\
            // Alice: a newer switch superseded the supplied animation; hide the\
            // stale preview image so it does not linger offset over the grid.\
            mShrinkExpandImageView.setVisibility(View.INVISIBLE);\
            return;\
// Alice patch end 0041\
        }\
\
// Alice patch start 0041\
        // Alice: restore the layout-ready callback so the regular preview image\
        // animator can run instead of falling back on timeout.\
        // Preserve the bitmap because it might have been supplied before the animation data.\
        mShrinkExpandImageView.resetKeepingBitmap(animationData.getInitialRect());\
\
        if (animationData.shouldUseFallbackAnimation()) {\
            supplyFallbackAnimator();\
            return;\
        }\
\
        mShrinkExpandImageView.runOnNextLayout(\
                () -> {\
                    mLayoutSatisfied = true;\
                    maybeSupplyAnimation();\
                });\
// Alice patch end 0041\
    }\
' "$path9"

sed -i '/^    @Px$/{
N
/\n    int getEdgeToEdgeBottomInset() {$/{
i\
    // Alice patch start 0041\
    private int getAliceNavigationBarVisualHeight() {\
        WindowInsetsCompat aliceRawInsets = mInsetObserver.getLastRawWindowInsets();\
        if (aliceRawInsets != null) {\
            int aliceVisualHeight = Math.max(\
                    aliceRawInsets\
                            .getInsetsIgnoringVisibility(\
                                    WindowInsetsCompat.Type.navigationBars())\
                            .bottom,\
                    aliceRawInsets\
                            .getInsetsIgnoringVisibility(\
                                    WindowInsetsCompat.Type.mandatorySystemGestures())\
                            .bottom);\
            if (aliceVisualHeight > 0) return aliceVisualHeight;\
        }\
        return getEdgeToEdgeBottomInset();\
    }\
\
    private int getAliceCurrentImeInset() {\
        return mFullWindowImeAnimationRunning\
                ? Math.max(0, mFullWindowCurrentImeInset)\
                : Math.max(\
                        0,\
                        mInsetObserver.getSupplierForKeyboardInset().get());\
    }\
\
    private void updateAliceNavBarHeight() {\
        if (mAliceNavBarView == null) return;\
        int aliceNavigationBarHeight = getAliceNavigationBarVisualHeight();\
        int aliceNavBarHeight =\
                getAliceCurrentImeInset() > aliceNavigationBarHeight\
                        ? 0\
                        : aliceNavigationBarHeight;\
        int aliceNavBarLayoutHeight =\
                aliceNavBarHeight > 0 ? aliceNavBarHeight + 1 : 0;\
        ViewGroup.LayoutParams aliceNavBarParams = mAliceNavBarView.getLayoutParams();\
        if (aliceNavBarParams.height != aliceNavBarLayoutHeight) {\
            aliceNavBarParams.height = aliceNavBarLayoutHeight;\
            mAliceNavBarView.setLayoutParams(aliceNavBarParams);\
        }\
        mAliceNavBarView.setTranslationY(\
                Math.max(0f, getFullWindowPreviewHeight() - 1f));\
        if (aliceNavBarLayoutHeight > 0) {\
            scheduleAliceNavBarColorSample();\
        }\
    }\
\
    private void scheduleAliceNavBarColorSample() {\
        View aliceNavBarView = mAliceNavBarView;\
        if (aliceNavBarView == null\
                || mAliceNavBarColorSamplePending\
                || (!mAliceNavBarHasOpaqueColor\
                        \&\& mAliceNavBarColorSampleAttempts >= 60)) {\
            return;\
        }\
        BottomSheetContent alicePreviewContent = getCurrentSheetContent();\
        if (alicePreviewContent == null) {\
            aliceNavBarView.setBackgroundColor(mAliceNavBarFallbackColor);\
            return;\
        }\
        mAliceNavBarColorSamplePending = true;\
        alicePreviewContent.getPageBackgroundColor(\
                aliceColor -> {\
                    mAliceNavBarColorSamplePending = false;\
                    if (mAliceNavBarView != aliceNavBarView) return;\
                    if (android.graphics.Color.alpha(aliceColor) == 0xFF) {\
                        mAliceNavBarHasOpaqueColor = true;\
                        mAliceNavBarColorSampleAttempts = 0;\
                        aliceNavBarView.setBackgroundColor(aliceColor);\
                        scheduleAliceNavBarColorPoll();\
                    } else {\
                        mAliceNavBarHasOpaqueColor = false;\
                        mAliceNavBarColorSampleAttempts++;\
                        aliceNavBarView.setBackgroundColor(mAliceNavBarFallbackColor);\
                        if (mAliceNavBarColorSampleAttempts < 60) {\
                            scheduleAliceNavBarColorPoll();\
                        }\
                    }\
                });\
    }\
\
    private void scheduleAliceNavBarColorPoll() {\
        View aliceNavBarView = mAliceNavBarView;\
        if (aliceNavBarView == null || mAliceNavBarColorPollScheduled) return;\
        mAliceNavBarColorPollScheduled = true;\
        int alicePollDelayMs = mAliceNavBarHasOpaqueColor ? 500 : 50;\
        aliceNavBarView.postDelayed(\
                () -> {\
                    mAliceNavBarColorPollScheduled = false;\
                    BottomSheetContent alicePreviewContent = getCurrentSheetContent();\
                    if (mAliceNavBarView == aliceNavBarView\
                            \&\& alicePreviewContent != null\
                            \&\& alicePreviewContent.shouldUseFullWindowPresentation()) {\
                        scheduleAliceNavBarColorSample();\
                    }\
                },\
                alicePollDelayMs);\
    }\
    // Alice patch end 0041
}
}' "$path7"

sed -i '/^        onSheetContentChanged(content);$/a\
        // Alice patch start 0041\
        if (content != null \&\& content.shouldUseFullWindowPresentation()) {\
            updateAliceNavBarHeight();\
            scheduleAliceNavBarColorSample();\
        }\
        // Alice patch end 0041' "$path7"

# Alice: the preview toolbar keeps the progress bar's space while hidden so the\
# toolbar height never changes and the page does not shift when it hides.\
sed -i '/^    public void setProgressVisible(boolean visible) {$/,/^    }$/c\
    public void setProgressVisible(boolean visible) {\
        // Alice patch start 0041\
        // Alice: INVISIBLE keeps the progress bar layout space so the toolbar\
        // height never changes; hiding it used to shift the whole page up.\
        ProgressBar progressBar = mToolbarView.findViewById(R.id.progress_bar);\
        progressBar.setVisibility(visible ? View.VISIBLE : View.INVISIBLE);\
// Alice patch end 0041\
    }\
' "$path3"

# Alice: capture the shrink animation's thumbnail rect one frame after the tab
# grid layout settles; capturing inline occasionally reads a not-yet-final card
# position, which offsets the animated preview.
sed -i '/^        Runnable provideAnimationData =$/{
i\
        // Alice patch start 0041\
        // Alice: rapid tab switching can leave several deferred captures in flight;\
        // only the newest one may publish its rects.\
        final int aliceCaptureGeneration = ++mAliceCaptureGeneration;\
        // Alice patch end 0041
n
a\
// Alice patch start 0041\
        if (aliceCaptureGeneration != mAliceCaptureGeneration) return;\
// Alice patch end 0041
}' "$path11"


sed -i '/^    private void onInsetChanged() {$/,/^    }$/c\
    // Alice patch start 0041\
    private void onInsetChanged() {\
        if (mFullWindowImeCropped\
                \&\& !isKeyboardShowing()\
                \&\& !mFullWindowImeAnimationRunning) {\
            restoreFullWindowImeCrop();\
            return;\
        }\
        updateAliceNavBarHeight();\
        updateContentContainerHeight();\
        if (shouldFollowImeForSheetPosition()) {\
            setSheetOffsetFromBottom(\
                    getSheetHeightForState(SheetState.FULL),\
                    StateChangeReason.NONE,\
                    /* reportOpenClosed= */ false);\
        }\
    }\
\
    private void restoreFullWindowImeCrop() {\
        if (!mFullWindowImeCropped || mRestoringFullWindowImeCrop) return;\
        mRestoringFullWindowImeCrop = true;\
        try {\
            float fullPreviewHeight = mFullWindowPreviewHeightBeforeIme;\
            mView.setClipBounds(null);\
            ViewGroup.LayoutParams layoutParams = mView.getLayoutParams();\
            layoutParams.height = ViewGroup.LayoutParams.MATCH_PARENT;\
            mView.setLayoutParams(layoutParams);\
            mFullWindowImeCropped = false;\
            mFullWindowPreviewHeightBeforeIme = 0;\
            BottomSheetContent previewContent = getCurrentSheetContent();\
            if (previewContent != null \&\& fullPreviewHeight > 0) {\
                previewContent.onSheetHeightChanged((int) fullPreviewHeight);\
            }\
            if (fullPreviewHeight > 0) {\
                mCurrentOffsetPx = fullPreviewHeight;\
                setSheetState(SheetState.FULL, false);\
            }\
        } finally {\
            mRestoringFullWindowImeCrop = false;\
        }\
    }\
    // Alice patch end 0041' "$path7"

sed -i '/^                    public void onEnd(WindowInsetsAnimationCompat animation) {$/,/^                    }$/c\
                    // Alice patch start 0041\
                    public void onEnd(WindowInsetsAnimationCompat animation) {\
                        mFullWindowImeAnimationRunning = false;\
                        mFullWindowCurrentImeInset =\
                                mInsetObserver.getSupplierForKeyboardInset().get();\
                        onInsetChanged();\
                        if (mFullWindowImeCropped\
                                \&\& (mImeAnimationClosing || !isKeyboardShowing())) {\
                            mWindow.getDecorView().removeCallbacks(\
                                    mRestoreWhenImeHidden);\
                            mWindow\
                                    .getDecorView()\
                                    .postOnAnimation(\
                                            mRestoreWhenImeHidden);\
                        }\
                        mMediator.notifyInsetAnimationEnd();\
                    }\
                    // Alice patch end 0041' "$path7"

sed -i '/^                    public void onPrepare(WindowInsetsAnimationCompat animation) {$/,/^                    }$/c\
                    // Alice patch start 0041\
                    public void onPrepare(WindowInsetsAnimationCompat animation) {\
                        if ((animation.getTypeMask()\
                                        \& WindowInsetsCompat.Type.ime())\
                                != 0) {\
                            mFullWindowImeAnimationRunning = true;\
                            mImeAnimationClosing = mFullWindowImeCropped;\
                            mFullWindowCurrentImeInset =\
                                    mInsetObserver\
                                            .getSupplierForKeyboardInset()\
                                            .get();\
                            mLastImeAnimationInset =\
                                    mInsetObserver\
                                            .getSupplierForKeyboardInset()\
                                            .get();\
                        }\
                        maybeCacheStateForImeAnimation(animation);\
                        mMediator.notifyBeforeInsetAnimationStart();\
                    }\
                    // Alice patch end 0041' "$path7"

sed -i '/^                    public void onProgress($/,/^                    }$/c\
                    // Alice patch start 0041\
                    public void onProgress(\
                            WindowInsetsCompat insets,\
                            List<WindowInsetsAnimationCompat> list) {\
                        int imeInset =\
                                insets.getInsets(\
                                                WindowInsetsCompat.Type.ime())\
                                        .bottom;\
                        int systemBarInset =\
                                insets.getInsets(\
                                                WindowInsetsCompat.Type.systemBars())\
                                        .bottom;\
                        int currentImeInset =\
                                Math.max(0, imeInset - systemBarInset);\
                        if (imeInset < mLastImeAnimationInset) {\
                            mImeAnimationClosing = true;\
                        }\
                        mFullWindowCurrentImeInset = currentImeInset;\
                        mLastImeAnimationInset = imeInset;\
                        onInsetChanged();\
                    }\
                    // Alice patch end 0041' "$path7"

sed -i '/^        mModel\.set(BottomSheetProperties\.CONTAINER_TOUCH_ENABLED, state != SheetState\.SCROLLING);$/c\
        // Alice patch start 0041\
        boolean fullWindowContent =\
                mSheetContent != null \&\& mSheetContent.shouldUseFullWindowPresentation();\
        mModel.set(\
                BottomSheetProperties.CONTAINER_TOUCH_ENABLED,\
                state != SheetState.SCROLLING || fullWindowContent);\
        // Alice patch end 0041' "$path8"

sed -i '/^    private void updateViewport(@Px int e2eBottomInset) {$/i\
    // Alice patch start 0041\
    private boolean shouldFollowImeForSheetPosition() {\
        BottomSheetContent content = getCurrentSheetContent();\
        return content != null \&\& content.shouldUseFullWindowPresentation();\
    }\
    // Alice patch end 0041\
\
' "$path7"

# Alice: the full-window preview owns the IME crop animation, so the visible
# viewport must not shrink underneath it while the keyboard is moving.
sed -i '/^        decorView\.getWindowVisibleDisplayFrame(mVisibleViewportRect);$/a\
        // Alice patch start 0041\
        if (shouldFollowImeForSheetPosition()) {\
            mVisibleViewportRect.bottom =\
                    decorView.getBottom()\
                            - ((isKeyboardShowing() || mFullWindowImeAnimationRunning)\
                                    ? 0\
                                    : e2eBottomInset);\
            return;\
        }\
        // Alice patch end 0041' "$path7"

sed -i '/^        bottomInset = Math\.min(bottomInset, decorHeight);$/i\
        // Alice patch start 0041\
        if (shouldFollowImeForSheetPosition()) {\
            bottomInset =\
                    (isKeyboardShowing() || mFullWindowImeAnimationRunning)\
                            ? 0\
                            : e2eBottomInset;\
        }\
        // Alice patch end 0041\
' "$path7"

sed -i '/^    private boolean isFullHeightWrapContent() {$/,/^    }$/c\
    // Alice patch start 0041\
    private boolean isFullHeightWrapContent() {\
        BottomSheetContent content = getCurrentSheetContent();\
        return content != null\
                \&\& !content.shouldUseFullWindowPresentation()\
                \&\& content.getFullHeightRatio() == HeightMode.WRAP_CONTENT;\
    }\
    // Alice patch end 0041' "$path7"

sed -i '/^        if (isFullHeightWrapContent() \&\& state == SheetState\.FULL) {$/i\
        // Alice patch start 0041\
        BottomSheetContent content = getCurrentSheetContent();\
        if (content != null\
                \&\& content.shouldUseFullWindowPresentation()\
                \&\& state == SheetState.FULL) {\
            return getFullWindowPreviewHeight();\
        }\
        // Alice patch end 0041' "$path7"

# getFullRatio() must agree with the FULL height override above. The preview content
# reports WRAP_CONTENT, which would otherwise be returned as a negative ratio and make
# getMaxOffsetPx() negative: the first swipe clamps the offset straight to 0 and the
# preview disappears without any settle animation.
sed -i '/^        if (mContainerHeight <= 0 || content == null) return 0;$/a\
        // Alice patch start 0041\
        if (content.shouldUseFullWindowPresentation()) {\
            int maxSheetHeight = getMaxSheetHeight();\
            if (maxSheetHeight <= 0) return 0;\
            return getFullWindowPreviewHeight() / maxSheetHeight;\
        }\
        // Alice patch end 0041' "$path7"

sed -i '/^        float translationY =$/i\
        // Alice patch start 0041\
        float effectiveOffset = mCurrentOffsetPx;\
        // Alice: the resting inset of the preview is keyboard-independent so the\
        // keyboard animation does not sink it before the IME branch takes over.\
        int positionBottomInset =\
                shouldFollowImeForSheetPosition()\
                        ? getAliceNavigationBarInset()\
                        : bottomInset;\
\
        if (!mRestoringFullWindowImeCrop\
                \&\& shouldFollowImeForSheetPosition()\
                \&\& (isKeyboardShowing() || mFullWindowImeAnimationRunning)) {\
            int imeInset =\
                    mFullWindowImeAnimationRunning\
                            ? mFullWindowCurrentImeInset\
                            : mInsetObserver.getSupplierForKeyboardInset().get();\
            if (imeInset > 0 || mFullWindowImeCropped) {\
                int navigationBarInset = getAliceNavigationBarInset();\
                if (!mFullWindowImeCropped\
                        || mFullWindowPreviewHeightBeforeIme <= 0) {\
                    mFullWindowPreviewHeightBeforeIme =\
                            getSheetHeightForState(SheetState.FULL);\
                }\
                effectiveOffset =\
                        Math.max(\
                                1,\
                                mFullWindowPreviewHeightBeforeIme - imeInset);\
                int croppedHeight = (int) effectiveOffset;\
                int clipWidth = mContainerWidth;\
                // Alice: reveal the fake navigation bar progressively as the closing IME\
                // becomes shorter than it instead of exposing the whole sheet at once.\
                int navbarReveal =\
                        Math.max(\
                                0,\
                                getAliceNavigationBarVisualHeight() - imeInset);\
                mView.setClipBounds(\
                        new Rect(0, 0, clipWidth, croppedHeight + navbarReveal));\
                mFullWindowImeCropped = true;\
                positionBottomInset = imeInset + navigationBarInset;\
                updateContentContainerHeight();\
                mMediator.setTouchEnabled(true);\
                BottomSheetContent previewContent = getCurrentSheetContent();\
                if (previewContent != null) {\
                    previewContent.onSheetHeightChanged(croppedHeight);\
                }\
            }\
        }\
        // Alice patch end 0041\
\
' "$path7"

# Alice: navigation-bar inset helper for the full-window preview positioning above.
# Alice: fake navigation bar below the preview window, following its animations.
sed -i '/^    private final BottomSheetView mView;$/a\
// Alice patch start 0041\
    private View mAliceNavBarView;\
    private boolean mAliceNavBarColorSamplePending;\
    private boolean mAliceNavBarColorPollScheduled;\
    private boolean mAliceNavBarHasOpaqueColor;\
    private int mAliceNavBarFallbackColor;\
    private int mAliceNavBarColorSampleAttempts;\
// Alice patch end 0041\
' "$path7"

sed -i '/^        mSheetContainer\.removeView(mView);$/i\
// Alice patch start 0041\
        // Alice: a fake navigation bar that sits below the preview window, in the\
        // zone the content avoids, with the same background as the title bar. As a\
        // child of the sheet view it follows every preview window animation.\
        Context aliceNavBarContext = mView.getContext();\
        mAliceNavBarView = new View(aliceNavBarContext);\
        mAliceNavBarFallbackColor =\
                SemanticColorUtils.getDefaultBgColor(aliceNavBarContext)\
                        | 0xFF000000;\
        Drawable aliceNavBarSource = aliceNavBarContext.getDrawable(\
                org.chromium.components.browser_ui.widget.R.drawable\
                        .bottom_sheet_background);\
        if (aliceNavBarSource != null) {\
            Bitmap aliceNavBarSample = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888);\
            try {\
                aliceNavBarSource.setBounds(0, 0, 64, 64);\
                aliceNavBarSource.draw(new Canvas(aliceNavBarSample));\
                // Alice: sample below the rounded top corners of the drawable, which\
                // are transparent and would otherwise give a fully transparent bar.\
                mAliceNavBarFallbackColor =\
                        aliceNavBarSample.getPixel(32, 56) | 0xFF000000;\
                mAliceNavBarView.setBackground(\
                        new ColorDrawable(mAliceNavBarFallbackColor));\
            } finally {\
                aliceNavBarSample.recycle();\
            }\
        }\
        mView.addView(\
                mAliceNavBarView,\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, 0, Gravity.TOP));\
        mAliceNavBarView.addOnLayoutChangeListener(\
                (view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {\
                    if (view.getHeight() > 0) scheduleAliceNavBarColorSample();\
                });\
// Alice patch end 0041\
' "$path7"

sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0041\
import android.graphics.Bitmap;\
import android.graphics.Canvas;\
import android.graphics.drawable.ColorDrawable;\
import android.graphics.drawable.Drawable;\
// Alice patch end 0041\
' "$path7"

sed -i '/^import android\.view\.MotionEvent;$/i\
// Alice patch start 0041\
import android.view.Gravity;\
// Alice patch end 0041\
' "$path7"

sed -i '/^import android\.view\.Window;$/a\
// Alice patch start 0041\
import android.widget.FrameLayout;\
// Alice patch end 0041\
' "$path7"

sed -i '/^    @Px$/{
N
/\n    int getEdgeToEdgeBottomInset() {$/{
i\
    // Alice patch start 0041\
    private int getAliceNavigationBarInset() {\
        WindowInsetsCompat aliceRawInsets = mInsetObserver.getLastRawWindowInsets();\
        if (aliceRawInsets != null) {\
            // Alice: navigation bars only; the mandatory-gesture inset is much\
            // taller than the visible bar and would over-shift the preview.\
            return aliceRawInsets\
                    .getInsetsIgnoringVisibility(\
                            WindowInsetsCompat.Type.navigationBars())\
                    .bottom;\
        }\
        return getEdgeToEdgeBottomInset();\
    }\
\
    private float getFullWindowPreviewHeight() {\
        return Math.max(\
                0f,\
                FULL_WINDOW_PREVIEW_HEIGHT_RATIO * getMaxSheetHeight()\
                        - getAliceNavigationBarInset());\
    }\
    // Alice patch end 0041
}
}' "$path7"

# Alice: let the preview draw past the container bottom into the navigation-bar area,
# otherwise the parent clipping slices the sheet at the navigation-bar top edge.
sed -i '/^            parent\.setClipChildren(!isPopup);$/c\
            // Alice patch start 0041\
            // Alice: allow the full-window preview to draw past the container bottom\
            // so it can sit flush with the physical screen bottom.\
            parent.setClipChildren(false);\
            // Alice patch end 0041' "$path7"

sed -i '/^                        mCurrentOffsetPx,$/c\
        // Alice patch start 0041\
                        effectiveOffset,\
        // Alice patch end 0041' "$path7"

sed -i '/^                        bottomInset);$/c\
        // Alice patch start 0041\
                        positionBottomInset);\
        // Alice patch end 0041' "$path7"

# 2) BottomSheetControllerImpl：记录遮罩及参数，支持打开动画前同步显示
sed -i '/^    private boolean mScrimVisible;$/a\
    // Alice patch start 0041\
    private boolean mScrimShown;\
    private @Nullable PropertyModel mScrimProperties;\
    // Alice patch end 0041' "$path2"

sed -i '/^                    \/\*\*$/,/^                    private boolean mScrimShown;$/c\
                    // Alice patch start 0041\
                    // Alice: scrim visibility is tracked by the controller so it can be shown\
                    // before the opening animation starts.\
                    // Alice patch end 0041' "$path2"

sed -i '/^        PropertyModel scrimProperties = createScrimParams();$/c\
        // Alice patch start 0041\
        PropertyModel scrimProperties = createScrimParams();\
        mScrimProperties = scrimProperties;\
        // Alice patch end 0041' "$path2"

sed -i '/^                        scrimManager\.showScrim(scrimProperties);$/,/^                        onScrimVisibilityChanged(true);$/c\
                        // Alice patch start 0041\
                        if (!mScrimShown) {\
                            showScrimForCurrentContent(/* animate= */ true);\
                        } else {\
                            onScrimVisibilityChanged(true);\
                        }\
                        // Alice patch end 0041' "$path2"

sed -i '/^                        if (mScrimShown) {$/,/^                        }$/c\
                        // Alice patch start 0041\
                        hideScrim();\
                        // Alice patch end 0041' "$path2"

sed -i '/^                    public void onSheetStateChanged(@SheetState int state, int reason) {$/a\
                        // Alice patch start 0041\
                        if (state == SheetState.HIDDEN) hideScrim();\
                        // Alice patch end 0041' "$path2"

sed -i '/^                .with(ScrimProperties.AFFECTS_STATUS_BAR, true)$/a\
                // Alice patch start 0041\
                .with(ScrimProperties.AFFECTS_NAVIGATION_BAR, false)\
                // Alice patch end 0041' "$path2"

sed -i '/^        mBottomSheet.showContent(nextContent);$/a\
        // Alice patch start 0041\
        if (nextContent != null \&\& nextContent.shouldUseFullWindowPresentation()) {\
            BottomSheetContent.FullWindowPresentationState.setActive(true);\
            showScrimForCurrentContent(/* animate= */ false);\
        }\
        // Alice patch end 0041' "$path2"

sed -i '/^    private void onScrimVisibilityChanged(boolean visible) {$/i\
    // Alice patch start 0041\
    private void showScrimForCurrentContent(boolean animate) {\
        ScrimManager scrimManager = assumeNonNull(mScrimManagerSupplier.get());\
        PropertyModel scrimProperties = assumeNonNull(mScrimProperties);\
        BottomSheetContent content = getCurrentSheetContent();\
        if (content != null) {\
            BottomSheetContent.FullWindowPresentationState.setActive(\
                    content.shouldUseFullWindowPresentation());\
        }\
        // Keep the navigation bar under the existing navigation-bar color/inset controller.\
        // Applying the scrim there changes its appearance during the preview transition and\
        // exposes the 48px strip that the page already reserves.\
        scrimProperties.set(ScrimProperties.AFFECTS_NAVIGATION_BAR, false);\
        scrimManager.showScrim(scrimProperties, animate);\
        mScrimShown = true;\
        onScrimVisibilityChanged(true);\
    }\
\
    private void hideScrim() {\
        if (!mScrimShown) return;\
        ScrimManager scrimManager = assumeNonNull(mScrimManagerSupplier.get());\
        PropertyModel scrimProperties = assumeNonNull(mScrimProperties);\
        scrimManager.hideScrim(scrimProperties, /* animate= */ true);\
        mScrimShown = false;\
        BottomSheetContent.FullWindowPresentationState.setActive(false);\
    }\
    // Alice patch end 0041\
\
' "$path2"

sed -i '/^        boolean shouldCover =$/,/^                        || (content != null \&\& content.coversBottomControls());$/c\
        // Alice patch start 0041\
        boolean fullWindowPresentation =\
                content != null \&\& content.shouldUseFullWindowPresentation();\
        boolean shouldCover =\
                (scrimVisible \&\& (mBottomSheet.isSheetOpen() || fullWindowPresentation))\
                        || (content != null \&\& content.coversBottomControls());\
        // Alice patch end 0041' "$path2"
