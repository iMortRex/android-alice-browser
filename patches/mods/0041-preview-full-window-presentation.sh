#!/bin/bash
# 让预览网页使用稳定的全窗口展示：同步布局标题栏，并在打开前铺好遮罩。
# 预览面板不再避让导航栏，网页内容底部保留导航栏高度的安全区。

set -e

path1="components/browser_ui/bottomsheet/android/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetContent.java"
path2="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetControllerImpl.java"
path3="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabSheetContent.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path7="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path9="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetCoordinator.java"
path10="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabMediator.java"
path11="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetMediator.java"
path12="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path13="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeBottomChinMediator.java"
pathTabUi="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
pathAnimData="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimationData.java"
sed -i '/^    private int mBottomBarHeight;$/a\
// Alice patch start 0041\
    // Alice: generation counter for the deferred shrink/expand rect captures.\
    private int mAliceCaptureGeneration;\
// Alice patch end 0041\
' "$pathTabUi"


# 检测是否已应用
if grep -q 'Alice patch start 0041' "$path1"; then
    exit 100
fi

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
        // Alice patch end 0041' "$path7"

sed -i '/^    private @Nullable View mNavigationBarBackground;$/a\
    // Alice patch start 0041\
    private @Nullable View mAliceStartupNavigationBarCover;\
    private boolean mAliceInitialPageReady;\
    // Alice patch end 0041' "$path7"

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
' "$path7"

sed -i '/^        mNavigationBarBackground = null;$/a\
        // Alice patch start 0041\
        removeAliceStartupNavigationBarCover();\
        // Alice patch end 0041' "$path7"

sed -i '/^        aliceBackground.setTranslationY(0);$/a\
        // Alice patch start 0041\
        boolean aliceFullWindowPreview =\
                BottomSheetContent.FullWindowPresentationState.isActive();\
        // Alice patch end 0041' "$path7"

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
        // Alice patch end 0041' "$path7"

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
        // Alice patch end 0041' "$path7"

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
sed -i '/^        int bottomInsetAdjustment = (mTargetState == SheetState\.HIDDEN) ? 0 : e2eBottomInset;$/c\
        // Alice patch start 0041\
        // Alice: keep a negative inset while hiding so the full-window preview slides\
        // fully off the screen; positive insets still zero out for the hidden state.\
        int bottomInsetAdjustment =\
                (mTargetState == SheetState.HIDDEN \&\& e2eBottomInset > 0)\
                        ? 0\
                        : e2eBottomInset;\
        // Alice patch end 0041' "$path11"

# BottomSheet 不参与预览内容区的触摸竞争，标题栏仍保留原有拖动行为。
sed -i '/^        if (!mIsTouchEnabled) return true;$/a\
        // Alice patch start 0041\
        if (mSheetContent != null\
                \&\& mSheetContent.shouldHandleContentTouchEvents()\
                \&\& isTouchEventInSheetContent(e)) {\
            return false;\
        }\
        // Alice patch end 0041' "$path11"

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
' "$path11"

sed -i '/^    private int mPreviousScreenHeight;$/a\
    // Alice patch start 0041\
    private boolean mFullWindowImeCropped;\
    private float mFullWindowPreviewHeightBeforeIme;\
    private int mFullWindowCurrentImeInset;\
    private boolean mFullWindowImeAnimationRunning;\
    private boolean mRestoringFullWindowImeCrop;\
    private @Nullable KeyboardVisibilityDelegate mKeyboardVisibilityDelegate;\
    // Alice patch end 0041\
' "$path9"

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
' "$path9"

sed -i '/^    private static final float HEIGHT_UNSPECIFIED = -1\.0f;$/a\
    // Alice patch start 0041\
    private static final float FULL_WINDOW_PREVIEW_HEIGHT_RATIO = 0.9f;\
    // Alice patch end 0041\
' "$path9"

sed -i '/^        mWindow = window;$/a\
        // Alice patch start 0041\
        mKeyboardVisibilityDelegate = keyboardDelegate;\
        // Alice patch end 0041' "$path9"

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
        // Alice patch end 0041' "$path9"

sed -i '/^        mInsetObserver = insetObserver;$/a\
        // Alice patch start 0041\
        mInsetObserver.addObserver(mImeResetObserver);\
        // Alice patch end 0041' "$path9"

# Alice: the fake navigation bar height tracks the edge-to-edge inset.
sed -i '/^        if (!bottomMarginChanged) return;$/i\
// Alice patch start 0041\
        // Alice: the fake navigation bar tracks the edge-to-edge inset, which is\
        // zero unless the preview is covering the bottom controls.\
        updateAliceNavBarHeight();\
// Alice patch end 0041\
' "$path9"

# Alice: clamp the shrink/expand animation rects' bottom to the top of the bottom
# buttons so the animated preview occasionally does not lag behind the grid cards.
sed -i '/^        Rect finalRect = animationData\.getFinalRect();$/a\
// Alice patch start 0040\
// Alice: occasionally the animation rects extend behind the bottom toolbar;\
// clamp their bottom to the top of the bottom buttons so the animated\
// preview stays in sync with the grid cards.\
if (toolbarView != null \&\& !animationData.isTopToolbar()) {\
    int aliceBottomMargin = animationData.getBottomMargin();\
    int aliceButtonsTop = mHubContainerView.getHeight() - aliceBottomMargin;\
    initialRect.bottom = Math.min(initialRect.bottom, aliceButtonsTop);\
    finalRect.bottom = Math.min(finalRect.bottom, aliceButtonsTop);\
}\
// Alice patch end 0040\
' "$path12"

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
' "$path13"

sed -i '/^    private void updateHeightAndVisibility() {$/,/^        int newHeight = mIsDrawingToEdge ? mEdgeToEdgeBottomInsetPx : 0;$/c\
    private void updateHeightAndVisibility() {\
        // Alice patch start 0032\
        // Alice: gate on the stable fullscreen state; the dispatched drawing flag\
        // goes stale during rotation and fullscreen transitions, which briefly\
        // removed the navigation-bar avoidance.\
        boolean aliceDrawingToEdge =\
                mAliceForceChin\
                        || (!mFullscreenManager.getPersistentFullscreenMode()\
                                \&\& (mIsDrawingToEdge\
                                        || mEdgeToEdgeBottomInsetPx > 0));\
        int newHeight = aliceDrawingToEdge ? mEdgeToEdgeBottomInsetPx : 0;\
'
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
' "$path13"

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
' "$path13"

sed -i '/^    public void onToEdgeChange(\$/i\
// Alice patch start 0041\
// Alice: the authoritative inset state arrived; drop the exit force.\
' "$path13"

sed -i '/^        mEdgeToEdgeBottomInsetPx = bottomInset;$/a\
// Alice patch start 0041\
        mAliceForceChin = false;\
// Alice patch end 0041\
' "$path13"

# Alice: the chin visibility uses the same stable gate.
sed -i '/^        boolean newVisibility =$/,/^                        \&\& !isKeyboardVisible;$/c\
        boolean newVisibility =\
                aliceDrawingToEdge\
                        \&\& isBottomChinAllowed(\
                                mLayoutManager.getActiveLayoutType(), mEdgeToEdgeBottomInsetPx)\
                        \&\& !isKeyboardVisible;\
'

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
        }
' "$path12"

sed -i '/^    private void updateAliceNavBarHeight() {$/,/^    }$/c\
    // Alice patch start 0041\
    private void updateAliceNavBarHeight() {\
        if (mAliceNavBarView == null) return;\
        if (mEdgeToEdgeBottomInsetSupplier.get() == null) return;\
        int aliceNavBarHeight = getEdgeToEdgeBottomInset();\
        ViewGroup.LayoutParams aliceNavBarParams = mAliceNavBarView.getLayoutParams();\
        if (aliceNavBarParams.height != aliceNavBarHeight) {\
            aliceNavBarParams.height = aliceNavBarHeight;\
            mAliceNavBarView.setLayoutParams(aliceNavBarParams);\
        }\
    }\
    // Alice patch end 0041\
' "$path9"

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
sed -i '/^        Runnable provideAnimationData =$/i\
// Alice patch start 0041\
        // Alice: rapid tab switching can leave several deferred captures in flight;\
        // only the newest one may publish its rects.\
        final int aliceCaptureGeneration = ++mAliceCaptureGeneration;\
// Alice patch end 0041\
' "$pathTabUi"

sed -i '/^        Runnable provideAnimationData =$/a\
// Alice patch start 0041\
        if (aliceCaptureGeneration != mAliceCaptureGeneration) return;\
// Alice patch end 0041\
' "$pathTabUi"


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
    // Alice patch end 0041' "$path9"

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
                    // Alice patch end 0041' "$path9"

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
                    // Alice patch end 0041' "$path9"

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
                    // Alice patch end 0041' "$path9"

sed -i '/^        mModel\.set(BottomSheetProperties\.CONTAINER_TOUCH_ENABLED, state != SheetState\.SCROLLING);$/c\
        // Alice patch start 0041\
        boolean fullWindowContent =\
                mSheetContent != null \&\& mSheetContent.shouldUseFullWindowPresentation();\
        mModel.set(\
                BottomSheetProperties.CONTAINER_TOUCH_ENABLED,\
                state != SheetState.SCROLLING || fullWindowContent);\
        // Alice patch end 0041' "$path11"

sed -i '/^    private @Px int getViewportBottomInset(@Px int e2eBottomInset) {$/,/^    }$/c\
    // Alice patch start 0041\
    private @Px int getViewportBottomInset(@Px int e2eBottomInset) {\
        @Px int viewportBottomInset = e2eBottomInset;\
\
        if (shouldFollowImeForSheetPosition()) {\
            return isKeyboardShowing() || mFullWindowImeAnimationRunning\
                    ? 0\
                    : viewportBottomInset;\
        }\
\
        if (isSheetOpen()) {\
            int visibleViewport = mVisibleViewportRect.height();\
            viewportBottomInset =\
                    Math.max(viewportBottomInset, mContainerHeight - visibleViewport);\
        }\
        return viewportBottomInset;\
    }\
\
    private boolean shouldFollowImeForSheetPosition() {\
        BottomSheetContent content = getCurrentSheetContent();\
        return content != null \&\& content.shouldUseFullWindowPresentation();\
    }\
    // Alice patch end 0041' "$path9"

sed -i '/^    private boolean isFullHeightWrapContent() {$/,/^    }$/c\
    // Alice patch start 0041\
    private boolean isFullHeightWrapContent() {\
        BottomSheetContent content = getCurrentSheetContent();\
        return content != null\
                \&\& !content.shouldUseFullWindowPresentation()\
                \&\& content.getFullHeightRatio() == HeightMode.WRAP_CONTENT;\
    }\
    // Alice patch end 0041' "$path9"

sed -i '/^        if (isFullHeightWrapContent() \&\& state == SheetState\.FULL) {$/i\
        // Alice patch start 0041\
        BottomSheetContent content = getCurrentSheetContent();\
        if (content != null\
                \&\& content.shouldUseFullWindowPresentation()\
                \&\& state == SheetState.FULL) {\
            return FULL_WINDOW_PREVIEW_HEIGHT_RATIO * getMaxSheetHeight();\
        }\
        // Alice patch end 0041' "$path9"

# getFullRatio() must agree with the FULL height override above. The preview content
# reports WRAP_CONTENT, which would otherwise be returned as a negative ratio and make
# getMaxOffsetPx() negative: the first swipe clamps the offset straight to 0 and the
# preview disappears without any settle animation.
sed -i '/^        if (mContainerHeight <= 0 || content == null) return 0;$/a\
        // Alice patch start 0041\
        if (content.shouldUseFullWindowPresentation()) {\
            return FULL_WINDOW_PREVIEW_HEIGHT_RATIO;\
        }\
        // Alice patch end 0041' "$path9"

sed -i '/^        float translationY =$/i\
        // Alice patch start 0041\
        float effectiveOffset = mCurrentOffsetPx;\
        // Alice: the resting inset of the preview is keyboard-independent so the\
        // keyboard animation does not sink it before the IME branch takes over.\
        int positionBottomInset =\
                shouldFollowImeForSheetPosition()\
                        ? getAliceNavigationBarInset()\
                        : bottomInset;\

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
                mView.setClipBounds(\
                        new Rect(0, 0, clipWidth, croppedHeight));\
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
' "$path9"

# Alice: navigation-bar inset helper for the full-window preview positioning above.
# Alice: fake navigation bar below the preview window, following its animations.
sed -i '/^    private final BottomSheetView mView;$/a\
// Alice patch start 0041\
    private View mAliceNavBarView;\
// Alice patch end 0041\
' "$path9"

sed -i '/^        mSheetContainer\.removeView(mView);$/i\
// Alice patch start 0041\
        // Alice: a fake navigation bar that sits below the preview window, in the\
        // zone the content avoids, with the same background as the title bar. As a\
        // child of the sheet view it follows every preview window animation.\
        Context aliceNavBarContext = mView.getContext();\
        mAliceNavBarView = new View(aliceNavBarContext);\
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
                mAliceNavBarView.setBackground(\
                        new ColorDrawable(aliceNavBarSample.getPixel(32, 56)));\
            } finally {\
                aliceNavBarSample.recycle();\
            }\
        }\
        mView.addView(\
                mAliceNavBarView,\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, 0, Gravity.BOTTOM));\
// Alice patch end 0041\
' "$path9"

sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0041\
import android.graphics.Bitmap;\
import android.graphics.Canvas;\
import android.graphics.drawable.ColorDrawable;\
import android.graphics.drawable.Drawable;\
// Alice patch end 0041\
' "$path9"

sed -i '/^import android\.view\.MotionEvent;$/i\
// Alice patch start 0041\
import android.view.Gravity;\
// Alice patch end 0041\
' "$path9"

sed -i '/^import android\.view\.Window;$/a\
// Alice patch start 0041\
import android.widget.FrameLayout;\
// Alice patch end 0041\
' "$path9"

sed -i '/^    private @Px int getEdgeToEdgeBottomInset() {$/i\
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
    // Alice patch end 0041\
\
' "$path9"

# Alice: let the preview draw past the container bottom into the navigation-bar area,
# otherwise the parent clipping slices the sheet at the navigation-bar top edge.
sed -i '/^            parent\.setClipChildren(!isPopup);$/c\
            // Alice patch start 0041\
            // Alice: allow the full-window preview to draw past the container bottom\
            // so it can sit flush with the physical screen bottom.\
            parent.setClipChildren(false);\
            // Alice patch end 0041' "$path9"

sed -i '/^                        mCurrentOffsetPx,$/c\
        // Alice patch start 0041\
                        effectiveOffset,\
        // Alice patch end 0041' "$path9"

sed -i '/^                        bottomInset);$/c\
        // Alice patch start 0041\
                        positionBottomInset);\
        // Alice patch end 0041' "$path9"

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

# 3) 预览网页强制使用可参与普通 View 合成的 TextureView
sed -i '/^import android\.view\.LayoutInflater;$/a\
// Alice patch start 0041\
import android.view.MotionEvent;\
// Alice patch end 0041\
' "$path3"

sed -i '/^import android\.view\.ViewTreeObserver;$/a\
// Alice patch start 0041\
import android.view.WindowInsets;\
// Alice patch end 0041\
' "$path3"

sed -i '/^import androidx\.annotation\.StringRes;$/a\
// Alice patch start 0041\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0041\
' "$path3"

sed -i '/^    private static final float FULL_HEIGHT_RATIO = 0\.9f;$/a\
    // Alice patch start 0041\
    private static final String ALICE_EXTENSION_FIT_SCRIPT =\
            """\
            if (location.protocol === "chrome-extension:") {\
              document.documentElement.style.setProperty(\
                      "height", "100%", "important");\
              document.documentElement.style.setProperty(\
                      "min-height", "0", "important");\
              document.documentElement.style.setProperty(\
                      "overflow", "auto", "important");\
              document.documentElement.style.setProperty(\
                      "overflow-y", "auto", "important");\
              document.documentElement.style.setProperty(\
                      "touch-action", "pan-y", "important");\
              if (document.body) {\
                document.body.style.setProperty(\
                        "height", "auto", "important");\
                document.body.style.setProperty(\
                        "min-height", "100%", "important");\
                document.body.style.setProperty(\
                        "overflow", "visible", "important");\
                document.body.style.setProperty(\
                        "overflow-y", "visible", "important");\
                document.body.style.setProperty(\
                        "touch-action", "pan-y", "important");\
              }\
            }\
            (() => {\
              const aliceDeepActiveElement = () => {\
                let active = document.activeElement;\
                while (active \&\& active.shadowRoot \&\& active.shadowRoot.activeElement) {\
                  active = active.shadowRoot.activeElement;\
                }\
                return active;\
              };\
              const aliceParentNode = (node) => {\
                if (node.parentElement) return node.parentElement;\
                const root = node.getRootNode();\
                return root instanceof ShadowRoot ? root.host : null;\
              };\
              const aliceCanScroll = (node) => {\
                const overflowY = getComputedStyle(node).overflowY;\
                return (overflowY === "auto"\
                                || overflowY === "scroll"\
                                || overflowY === "overlay")\
                        \&\& node.scrollHeight > node.clientHeight + 1;\
              };\
              const aliceScrollBy = (node, amount) => {\
                const before = node.scrollTop;\
                node.scrollTop =\
                        Math.min(\
                                node.scrollHeight - node.clientHeight,\
                                before + amount);\
                return amount - (node.scrollTop - before);\
              };\
              window.__aliceRevealFocusedInput = (visibleHeightPx) => {\
                const active = aliceDeepActiveElement();\
                if (!active || typeof active.getBoundingClientRect !== "function") return;\
                const scale = window.devicePixelRatio || 1;\
                const viewportHeight = window.visualViewport\
                        ? window.visualViewport.height\
                        : window.innerHeight;\
                const visibleBottom =\
                        Math.max(\
                                1,\
                                Math.min(visibleHeightPx / scale, viewportHeight) - 12);\
                const inputBottom = active.getBoundingClientRect().bottom;\
                let remaining = inputBottom - visibleBottom;\
                if (remaining <= 0) return;\
                let node = aliceParentNode(active);\
                while (node \&\& remaining > 0.5) {\
                  if (aliceCanScroll(node)) {\
                    remaining = aliceScrollBy(node, remaining);\
                  }\
                  node = aliceParentNode(node);\
                }\
                if (remaining > 0.5) {\
                  const root = document.scrollingElement || document.documentElement;\
                  remaining = aliceScrollBy(root, remaining);\
                  if (remaining > 0.5) window.scrollBy(0, remaining);\
                }\
              };\
            })();\
            """;\
    // Alice patch end 0041\
' "$path3"

sed -i '/^        mThinWebView =$/i\
        // Alice patch start 0041\
        ThinWebViewConstraints constraints = new ThinWebViewConstraints();\
        constraints.supportsOpacity = true;\
        android.util.TypedValue aliceBackgroundValue =\
                new android.util.TypedValue();\
        int aliceBackgroundColor = android.graphics.Color.BLACK;\
        if (mContext\
                .getTheme()\
                .resolveAttribute(\
                        android.R.attr.colorBackground,\
                        aliceBackgroundValue,\
                        true)) {\
            aliceBackgroundColor =\
                    aliceBackgroundValue.resourceId != 0\
                            ? mContext.getColor(aliceBackgroundValue.resourceId)\
                            : aliceBackgroundValue.data;\
        }\
        constraints.backgroundColor = aliceBackgroundColor;\
        constraints.ignoreSizeChanges = true;\
        // Alice patch end 0041\
' "$path3"

sed -i '/^    private ViewGroup mSheetContentView;$/a\
    // Alice patch start 0041\
    private FrameLayout mContentViewport;\
    private int mLastSheetHeight;\
    // Alice patch end 0041' "$path3"

sed -i '/^    @EnsuresNonNull({"mThinWebView", "mSheetContentView"})$/c\
    // Alice patch start 0041\
    @EnsuresNonNull({"mThinWebView", "mSheetContentView", "mContentViewport"})\
    // Alice patch end 0041' "$path3"

sed -i '/^                        mContext,$/,/^                        \/\* enablePermissionRequests= \*\/ false);$/c\
                        // Alice patch start 0041\
                        mContext,\
                        constraints,\
                        intentRequestTracker,\
                        /* enablePermissionRequests= */ false);\
                        // Alice patch end 0041' "$path3"

sed -i '/^    private void createThinWebView(int maxSheetHeight, IntentRequestTracker intentRequestTracker) {$/i\
    // Alice patch start 0041\
    void applyExtensionViewportConstraint() {\
        if (mWebContents == null || mWebContents.isDestroyed()) return;\
        mWebContents\
                .getMainFrame()\
                .executeJavaScriptInIsolatedWorld(ALICE_EXTENSION_FIT_SCRIPT, 1, null);\
    }\
\
    private void applyPreviewImeVisibleHeight(int visibleHeightPx) {\
        if (mWebContents == null || mWebContents.isDestroyed()) return;\
        String aliceScript =\
                "if (window.__aliceRevealFocusedInput) {"\
                        + "window.__aliceRevealFocusedInput("\
                        + visibleHeightPx\
                        + ");}";\
        mWebContents\
                .getMainFrame()\
                .executeJavaScriptInIsolatedWorld(aliceScript, 1, null);\
    }\
    // Alice patch end 0041\
\
' "$path3"

sed -i '/^                        \.build());$/a\
\
        // Alice patch start 0041\
        mWebContentView.setOnTouchListener(\
                (view, event) -> {\
                    if (event.getActionMasked() == MotionEvent.ACTION_DOWN\
                            \&\& view.getParent() != null) {\
                        view.getParent().requestDisallowInterceptTouchEvent(true);\
                    }\
                    return false;\
                });\
        // Alice patch end 0041' "$path3"

# 4) 在标题栏下方建立独立裁剪视口，网页只在该范围内绘制
sed -i '/^        mSheetContentView = new FrameLayout(mContext);$/,/^        mSheetContentView.addView(mThinWebView.getView());$/c\
        // Alice patch start 0041\
        mSheetContentView = new FrameLayout(mContext);\
        mSheetContentView.setClipChildren(true);\
        mSheetContentView.setClipToPadding(true);\
\
        mContentViewport = new FrameLayout(mContext);\
        mContentViewport.setClipChildren(true);\
        mContentViewport.setClipToPadding(true);\
        mContentViewport.setBackgroundColor(aliceBackgroundColor);\
        mContentViewport.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, maxSheetHeight));\
\
        FrameLayout.LayoutParams aliceWebViewParams =\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT,\
                        maxSheetHeight);\
        mThinWebView.getView().setBackgroundColor(aliceBackgroundColor);\
        mThinWebView.getView().setLayoutParams(aliceWebViewParams);\
        mContentViewport.addView(mThinWebView.getView());\
        mSheetContentView.addView(mContentViewport);\
        // Alice patch end 0041' "$path3"

# 5) 固定视口尺寸，并在当前遍历中完成布局，拖动时只平移面板
sed -i '/^    void updateContentHeight(int maxViewHeight) {$/i\
    // Alice patch start 0041\
    private void ensureAliceWebViewStableHeight(int contentHeight) {\
        FrameLayout.LayoutParams params =\
                (FrameLayout.LayoutParams) mThinWebView.getView().getLayoutParams();\
        if (params.height < contentHeight) {\
            params.height = contentHeight;\
            mThinWebView.getView().setLayoutParams(params);\
        }\
    }\
    // Alice patch end 0041\
\
' "$path3"

sed -i '/^    void updateContentHeight(int maxViewHeight) {$/,/^    }$/c\
    // Alice patch start 0041\
    void updateContentHeight(int maxViewHeight) {\
        if (maxViewHeight == 0) return;\
\
        int aliceSheetHeight = getMaxSheetHeight(maxViewHeight);\
        int aliceToolbarHeight = getToolbarHeight();\
        int aliceContentHeight = Math.max(0, aliceSheetHeight - aliceToolbarHeight);\
        // Alice: the web contents fill the whole visible area so nothing is truncated.\
        ensureAliceWebViewStableHeight(aliceContentHeight);\
        int aliceWidth = mSheetContentView.getWidth();\
        if (aliceWidth <= 0) {\
            aliceWidth = mContext.getResources().getDisplayMetrics().widthPixels;\
        }\
\
        FrameLayout.LayoutParams aliceViewportParams =\
                (FrameLayout.LayoutParams) mContentViewport.getLayoutParams();\
        aliceViewportParams.height = aliceContentHeight;\
        aliceViewportParams.topMargin = aliceToolbarHeight;\
        mContentViewport.setLayoutParams(aliceViewportParams);\
        mSheetContentView.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, aliceSheetHeight));\
        mSheetContentView.setPadding(0, 0, 0, 0);\
\
        mThinWebView.resizeWebContents(aliceWidth, aliceContentHeight);\
        mContentViewport.forceLayout();\
        mContentViewport.measure(\
                View.MeasureSpec.makeMeasureSpec(aliceWidth, View.MeasureSpec.EXACTLY),\
                View.MeasureSpec.makeMeasureSpec(\
                        aliceContentHeight, View.MeasureSpec.EXACTLY));\
        mContentViewport.layout(\
                0,\
                aliceToolbarHeight,\
                aliceWidth,\
                aliceToolbarHeight + aliceContentHeight);\
        ViewUtils.requestLayout(mSheetContentView, "Alice preview fixed viewport");\
    }\
\
' "$path3"

sed -i '/^    private int getToolbarHeight() {$/,/^    }$/c\
    // Alice patch start 0041\
    private int getToolbarHeight() {\
        int shadowHeight =\
                mContext.getResources().getDimensionPixelSize(R.dimen.action_bar_shadow_height);\
        int toolbarHeight = mToolbarView.getHeight();\
        if (toolbarHeight == 0) toolbarHeight = mToolbarView.getMeasuredHeight();\
        return Math.max(0, toolbarHeight - shadowHeight);\
    }\
    // Alice patch end 0041' "$path3"

# 6) 预览网页在首次显示前完成标题栏测量
sed -i '/^        mOnToolbarCreatedCallback\.onResult(mToolbarView);$/a\
        // Alice patch start 0041\
        // The toolbar must be measured before the sheet is measured for the first time.\
        // Otherwise the page content starts at the sheet top and covers the title bar.\
        int aliceToolbarWidth = mContext.getResources().getDisplayMetrics().widthPixels;\
        mToolbarView.measure(\
                View.MeasureSpec.makeMeasureSpec(aliceToolbarWidth, View.MeasureSpec.EXACTLY),\
                View.MeasureSpec.makeMeasureSpec(\
                        getMaxSheetHeight(maxViewHeight), View.MeasureSpec.AT_MOST));\
        mToolbarView.layout(\
                0, 0, mToolbarView.getMeasuredWidth(), mToolbarView.getMeasuredHeight());\
        updateContentHeight(maxViewHeight);\
        // Alice patch end 0041\
' "$path3"

sed -i '/^                        if (navigation.hasCommitted()) {$/a\
                            // Alice patch start 0041\
                            mSheetContent.applyExtensionViewportConstraint();\
                            // Alice patch end 0041' "$path10"

sed -i '/^                        if (mSheetContent != null) mSheetContent\.setProgress(progress);$/a\
                        // Alice patch start 0041\
                        if (progress >= 1f \&\& mSheetContent != null) {\
                            mSheetContent.applyExtensionViewportConstraint();\
                        }\
                        // Alice patch end 0041' "$path10"

sed -i '/^    @Nullable$/i\
    // Alice patch start 0041\
    @Override\
    public boolean shouldUseFullWindowPresentation() {\
        return true;\
    }\
\
    @Override\
    public boolean shouldHandleContentTouchEvents() {\
        return true;\
    }\
\
    @Override\
    public void onSheetHeightChanged(int sheetHeight) {\
        if (sheetHeight <= 0) return;\
        boolean aliceHeightReduced =\
                mLastSheetHeight > 0 \&\& sheetHeight < mLastSheetHeight;\
        mLastSheetHeight = sheetHeight;\
        int aliceToolbarHeight = getToolbarHeight();\
        int aliceContentHeight = Math.max(1, sheetHeight - aliceToolbarHeight);\
        ensureAliceWebViewStableHeight(aliceContentHeight);\
        int aliceWidth = mSheetContentView.getWidth();\
        if (aliceWidth <= 0) {\
            aliceWidth = mContext.getResources().getDisplayMetrics().widthPixels;\
        }\
        mSheetContentView.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, sheetHeight));\
        FrameLayout.LayoutParams aliceViewportParams =\
                (FrameLayout.LayoutParams) mContentViewport.getLayoutParams();\
        aliceViewportParams.height = aliceContentHeight;\
        aliceViewportParams.topMargin = aliceToolbarHeight;\
        mContentViewport.setLayoutParams(aliceViewportParams);\
        mThinWebView.resizeWebContents(aliceWidth, aliceContentHeight);\
        mContentViewport.forceLayout();\
        mContentViewport.measure(\
                View.MeasureSpec.makeMeasureSpec(\
                        aliceWidth, View.MeasureSpec.EXACTLY),\
                View.MeasureSpec.makeMeasureSpec(\
                        aliceContentHeight, View.MeasureSpec.EXACTLY));\
        mContentViewport.layout(\
                0,\
                aliceToolbarHeight,\
                aliceWidth,\
                aliceToolbarHeight + aliceContentHeight);\
        ViewUtils.requestLayout(\
                mSheetContentView, "Alice preview sheet height");\
        if (aliceHeightReduced) {\
            applyPreviewImeVisibleHeight(aliceContentHeight);\
        }\
    }\
\
    @Override\
    public int getToolbarBackgroundHeight() {\
        return getToolbarHeight();\
    }\
    // Alice patch end 0041\
\
' "$path3"

# Alice: the shrink/expand animation queries the grid card rect live on every
# frame, so a grid that scrolls or relayouts mid-animation cannot desync the
# preview image from the cards.
sed -i '/^import android\.util\.Size;$/a\
// Alice patch start 0041\
import java.util.function.Supplier;\
// Alice patch end 0041' "$pathAnimData"

sed -i '/^    private final int mBottomMargin;$/a\
    // Alice patch start 0041\
    // Alice: live grid card rect queried on every animation frame; null falls\
    // back to the cached rects.\
    private @Nullable Supplier<@Nullable Rect> mLiveCardRectSupplier;\
    // Alice patch end 0041' "$pathAnimData"

sed -i '/^    \/\*\* Returns whether to use the fallback animation\. \*\/$/,/^    }$/c\
    /** Returns whether to use the fallback animation. */\
    public boolean shouldUseFallbackAnimation() {\
        return mUseFallbackAnimation;\
    }\
\
    // Alice patch start 0041\
\
    /** Sets a live supplier for the grid card rect used by the animation frames. */\
    public void setLiveCardRectSupplier(@Nullable Supplier<@Nullable Rect> supplier) {\
        mLiveCardRectSupplier = supplier;\
    }\
\
    /** Returns the live grid card rect supplier, or null when only cached rects exist. */\
    public @Nullable Supplier<@Nullable Rect> getLiveCardRectSupplier() {\
        return mLiveCardRectSupplier;\
    }\
    // Alice patch end 0041' "$pathAnimData"

# Alice: attach the live card rect query when the animation data is published.
sed -i '/^                                    bottomMargin));$/a\
        // Alice patch start 0041\
        // Alice: attach a per-frame card rect query so the preview animation\
        // tracks the live grid instead of the rects captured at switch time.\
        @Nullable ShrinkExpandAnimationData aliceAnimationData =\
                animationDataSupplier.get();\
        if (aliceAnimationData != null) {\
            aliceAnimationData.setLiveCardRectSupplier(\
                    () -> {\
                        Rect aliceLiveRect = coordinator.getTabThumbnailRect(tabId);\
                        if (aliceLiveRect.isEmpty()) {\
                            return null;\
                        }\
                        Rect aliceHubRect = new Rect();\
                        hubContainerView.getGlobalVisibleRect(aliceHubRect);\
                        aliceLiveRect.offset(-aliceHubRect.left, -aliceHubRect.top);\
                        // Alice: keep the live rect above the bottom buttons to\
                        // match the cached rect clamp.\
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
                                        hubContainerView.getHeight()\
                                                - aliceBottomMargin);\
                        return aliceLiveRect;\
                    });\
        }\
        // Alice patch end 0041
' "$pathTabUi"

# Alice: apply the live card rect on every animation frame, lerping between the
# fixed viewport endpoint and the live card endpoint with the frame fraction.
sed -i '/^import java\.util\.function\.DoubleConsumer;$/a\
// Alice patch start 0041\
import java.util.function.Supplier;\
// Alice patch end 0041' "$path12"

sed -i '/^        Interpolator interpolator = getInterpolator(mAnimationType);$/a\
        // Alice patch start 0041\
        // Alice: record the animation fraction each frame; the live card rect is\
        // applied by the pre-draw listener below, after the frame grid scroll and\
        // layout, so the preview never trails the cards by one frame.\
        shrinkExpandAnimator.addUpdateListener(\
                animation -> {\
                    mAliceLiveFraction = animation.getAnimatedFraction();\
                });\
        mAlicePreDrawListener =\
                () -> {\
                    Supplier<@Nullable Rect> aliceLiveCardSupplier =\
                            animationData.getLiveCardRectSupplier();\
                    @Nullable ShrinkExpandAnimator aliceLiveAnimator =\
                            mShrinkExpandAnimator;\
                    if (aliceLiveCardSupplier == null || aliceLiveAnimator == null) {\
                        return true;\
                    }\
                    Rect aliceLiveCard = aliceLiveCardSupplier.get();\
                    if (aliceLiveCard == null || aliceLiveCard.isEmpty()) {\
                        return true;\
                    }\
                    float aliceFraction = mAliceLiveFraction;\
                    Rect aliceFrom = isShrink ? initialRect : aliceLiveCard;\
                    Rect aliceTo = isShrink ? aliceLiveCard : finalRect;\
                    Rect aliceLiveRect =\
                            new Rect(\
                                    Math.round(\
                                            aliceFrom.left\
                                                    + (aliceTo.left - aliceFrom.left)\
                                                            * aliceFraction),\
                                    Math.round(\
                                            aliceFrom.top\
                                                    + (aliceTo.top - aliceFrom.top)\
                                                            * aliceFraction),\
                                    Math.round(\
                                            aliceFrom.right\
                                                    + (aliceTo.right - aliceFrom.right)\
                                                            * aliceFraction),\
                                    Math.round(\
                                            aliceFrom.bottom\
                                                    + (aliceTo.bottom - aliceFrom.bottom)\
                                                            * aliceFraction));\
                    aliceLiveAnimator.setRect(aliceLiveRect);\
                    return true;\
                };\
        mHubContainerView\
                .getViewTreeObserver()\
                .addOnPreDrawListener(mAlicePreDrawListener);\
        // Alice patch end 0041
' "$path12"

# Alice: fields for the per-frame fraction and the live rect pre-draw listener.
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0041\
import android.view.ViewTreeObserver;\
// Alice patch end 0041' "$path12"

sed -i '/^    private boolean mLayoutSatisfied;$/a\
    // Alice patch start 0041\
    // Alice: fraction of the running shrink/expand animation and the pre-draw\
    // listener that re-applies the live card rect after each frame layout.\
    private float mAliceLiveFraction;\
    private ViewTreeObserver.@Nullable OnPreDrawListener mAlicePreDrawListener;\
    // Alice patch end 0041' "$path12"

sed -i '/^    private void resetState() {$/a\
        // Alice patch start 0041\
        // Alice: detach the live rect pre-draw listener with the animation.\
        if (mAlicePreDrawListener != null) {\
            mHubContainerView\
                    .getViewTreeObserver()\
                    .removeOnPreDrawListener(mAlicePreDrawListener);\
            mAlicePreDrawListener = null;\
        }\
        // Alice patch end 0041' "$path12"

# Alice: place the preview image at the live card rect before the first
# animation frame; the pre-animation placement used the rect captured before
# the grid settled, which flashed an offset position when the grid scrolled.
sed -i '/^                        mShrinkExpandImageView\.setVisibility(View\.VISIBLE);$/a\
                        // Alice patch start 0041\
                        // Alice: place the preview image at the live card rect\
                        // before the first animation frame, so the initial\
                        // placement is not the rect captured before the grid\
                        // settled.\
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
                        // Alice patch end 0041' "$path12"

# Alice: land the shrink animation on the live card rect instead of the cached
# final rect, which may be stale if the grid settled after the capture.
sed -i '/^                        mShrinkExpandImageView\.resetKeepingBitmap(animationData\.getFinalRect());$/c\
                        // Alice patch start 0041\
                        // Alice: land the shrink on the live card rect; the cached\
                        // final rect may be stale if the grid settled after capture.\
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
                        // Alice patch end 0041' "$path12"
