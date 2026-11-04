#!/bin/bash
# 让预览网页使用稳定的全窗口展示：同步布局标题栏，并在打开前铺好遮罩。

set -e

path1="components/browser_ui/bottomsheet/android/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetContent.java"
path2="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetControllerImpl.java"
path3="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabSheetContent.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path7="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path9="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheet.java"
path10="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabMediator.java"

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
        // Alice: suppress the navigation-bar background while search/Omnibox is focused.\
        boolean aliceVisible =\
                aliceToolbarOnBottom\
                        \&\& aliceNavigationBarHeight > 0\
                        \&\& !mIsOmniboxFocusedSupplier.get()\
                        \&\& aliceParentReachesWindowBottom\
                        \&\& (aliceFullWindowPreview\
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

# BottomSheet 不参与预览内容区的触摸竞争，标题栏仍保留原有拖动行为。
sed -i '/^        if (!mIsTouchEnabled) return true;$/a\
        // Alice patch start 0041\
        if (mSheetContent != null\
                \&\& mSheetContent.shouldHandleContentTouchEvents()\
                \&\& isTouchEventInSheetContent(e)) {\
            return false;\
        }\
        // Alice patch end 0041' "$path9"

sed -i '/^        return mCachedLocation\[1\] + mToolbarHolder\.getHeight() > event\.getRawY();$/a\
    // Alice patch start 0041\
    private boolean isTouchEventInSheetContent(MotionEvent event) {\
        if (mSheetContent == null) return false;\
        Rect contentBounds = new Rect();\
        if (!mSheetContent.getContentView().getGlobalVisibleRect(contentBounds)) {\
            return false;\
        }\
        return contentBounds.contains(\
                (int) event.getRawX(), (int) event.getRawY());\
    }\
    // Alice patch end 0041' "$path9"

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
                                BottomSheet.this::restoreFullWindowImeCrop);\
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
                                                    BottomSheet.this)\
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

sed -i '/^    private static final float HALF_HEIGHT_RATIO = 0\.75f;$/a\
    // Alice patch start 0041\
    private static final float FULL_WINDOW_PREVIEW_HEIGHT_RATIO = 0.9f;\
    // Alice patch end 0041\
' "$path9"

sed -i '/^        mWindow = window;$/a\
        // Alice patch start 0041\
        mKeyboardVisibilityDelegate = keyboardDelegate;\
        // Alice patch end 0041' "$path9"

sed -i '/^        mIsTouchEnabled = false;$/a\
        // Alice patch start 0041\
        setClipBounds(null);\
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

sed -i '/^    private void onInsetChanged() {$/,/^    }$/c\
    // Alice patch start 0041\
    private void onInsetChanged() {\
        if (mFullWindowImeCropped\
                \&\& !isKeyboardShowing()\
                \&\& !mFullWindowImeAnimationRunning) {\
            restoreFullWindowImeCrop();\
            return;\
        }\
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
            setClipBounds(null);\
            ViewGroup.LayoutParams layoutParams = getLayoutParams();\
            layoutParams.height = ViewGroup.LayoutParams.MATCH_PARENT;\
            setLayoutParams(layoutParams);\
            mFullWindowImeCropped = false;\
            mFullWindowPreviewHeightBeforeIme = 0;\
            if (mSheetContent != null \&\& fullPreviewHeight > 0) {\
                mSheetContent.onSheetHeightChanged((int) fullPreviewHeight);\
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

sed -i '/^        ViewGroup\.LayoutParams bgParams = mSheetBackground\.getLayoutParams();$/i\
        // Alice patch start 0041\
        if (shouldFollowImeForSheetPosition() \&\& mFullWindowImeCropped) {\
            targetBgHeight = ViewGroup.LayoutParams.MATCH_PARENT;\
            mSheetBackground.setVisibility(View.VISIBLE);\
            mToolbarHolder.setBackgroundColor(Color.TRANSPARENT);\
        } else {\
            mSheetBackground.setVisibility(View.VISIBLE);\
            mToolbarHolder.setBackgroundColor(Color.TRANSPARENT);\
        }\
        // Alice patch end 0041\
\
' "$path9"

sed -i '/^            mKeyboardCurtain\.setTranslationY(maxWindowHeight);$/a\
            // Alice patch start 0041\
            mKeyboardCurtain.setVisibility(\
                    shouldFollowImeForSheetPosition()\
                            ? View.GONE\
                            : View.VISIBLE);\
            // Alice patch end 0041' "$path9"

sed -i '/^        mModel\.set(BottomSheetProperties\.CONTAINER_TOUCH_ENABLED, state != SheetState\.SCROLLING);$/c\
        // Alice patch start 0041\
        boolean fullWindowContent =\
                mSheetContent != null \&\& mSheetContent.shouldUseFullWindowPresentation();\
        mModel.set(\
                BottomSheetProperties.CONTAINER_TOUCH_ENABLED,\
                state != SheetState.SCROLLING || fullWindowContent);\
        // Alice patch end 0041' "$path9"

sed -i '/^    private int getViewportBottomInset() {$/,/^    }$/c\
    // Alice patch start 0041\
    private int getViewportBottomInset() {\
        assert mEdgeToEdgeBottomInsetSupplier.get() != null;\
        @Px int viewportBottomInset = getEdgeToEdgeBottomInset();\
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
        return mSheetContent != null \&\& mSheetContent.shouldUseFullWindowPresentation();\
    }\
    // Alice patch end 0041' "$path9"

sed -i '/^    private boolean isFullHeightWrapContent() {$/,/^    }$/c\
    // Alice patch start 0041\
    private boolean isFullHeightWrapContent() {\
        return mSheetContent != null\
                \&\& !mSheetContent.shouldUseFullWindowPresentation()\
                \&\& mSheetContent.getFullHeightRatio() == HeightMode.WRAP_CONTENT;\
    }\
    // Alice patch end 0041' "$path9"

sed -i '/^        if (mContainerHeight <= 0 || mSheetContent == null) return 0;$/a\
        // Alice patch start 0041\
        if (mSheetContent != null \&\& mSheetContent.shouldUseFullWindowPresentation()) {\
            return FULL_WINDOW_PREVIEW_HEIGHT_RATIO;\
        }\
        // Alice patch end 0041' "$path9"

sed -i '/^        float translationY =$/i\
        // Alice patch start 0041\
        float effectiveOffset = mCurrentOffsetPx;\
        int positionBottomInset = bottomInset;\
        if (!mRestoringFullWindowImeCrop\
                \&\& shouldFollowImeForSheetPosition()\
                \&\& (isKeyboardShowing() || mFullWindowImeAnimationRunning)) {\
            int imeInset =\
                    mFullWindowImeAnimationRunning\
                            ? mFullWindowCurrentImeInset\
                            : mInsetObserver.getSupplierForKeyboardInset().get();\
            if (imeInset > 0 || mFullWindowImeCropped) {\
                WindowInsetsCompat rawInsets =\
                        mInsetObserver.getLastRawWindowInsets();\
                int navigationBarInset =\
                        rawInsets != null\
                                ? rawInsets\
                                        .getInsets(\
                                                WindowInsetsCompat.Type.navigationBars())\
                                        .bottom\
                                : getEdgeToEdgeBottomInset();\
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
                int clipWidth =\
                        getWidth() > 0 ? getWidth() : mContainerWidth;\
                setClipBounds(\
                        new Rect(0, 0, clipWidth, croppedHeight));\
                mFullWindowImeCropped = true;\
                positionBottomInset = imeInset + navigationBarInset;\
                updateContentContainerHeight();\
                mBottomSheetContentContainer.setIsTouchEnabled(true);\
                if (mSheetContent != null) {\
                    mSheetContent.onSheetHeightChanged(croppedHeight);\
                }\
            }\
        }\
        // Alice patch end 0041\
\
' "$path9"

sed -i '/^                (mContainerHeight - mCurrentOffsetPx)$/c\
        // Alice patch start 0041\
                (mContainerHeight - effectiveOffset)\
        // Alice patch end 0041' "$path9"

sed -i '/^                        - (mTargetState == SheetState.HIDDEN ? 0 : bottomInset);$/c\
        // Alice patch start 0041\
                        - (mTargetState == SheetState.HIDDEN\
                                ? 0\
                                : positionBottomInset);\
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

sed -i '/^    private static final float FULL_HEIGHT_RATIO = 0\.9f;$/a\
    // Alice patch start 0041\
    private static final String ALICE_EXTENSION_FIT_SCRIPT =\
            """\
            if (location.protocol === 'chrome-extension:') {\
              document.documentElement.style.setProperty(\
                      'height', '100%', 'important');\
              document.documentElement.style.setProperty(\
                      'min-height', '0', 'important');\
              document.documentElement.style.setProperty(\
                      'overflow', 'auto', 'important');\
              document.documentElement.style.setProperty(\
                      'overflow-y', 'auto', 'important');\
              document.documentElement.style.setProperty(\
                      'touch-action', 'pan-y', 'important');\
              if (document.body) {\
                document.body.style.setProperty(\
                        'height', 'auto', 'important');\
                document.body.style.setProperty(\
                        'min-height', '100%', 'important');\
                document.body.style.setProperty(\
                        'overflow', 'visible', 'important');\
                document.body.style.setProperty(\
                        'overflow-y', 'visible', 'important');\
                document.body.style.setProperty(\
                        'touch-action', 'pan-y', 'important');\
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
                return (overflowY === 'auto'\
                                || overflowY === 'scroll'\
                                || overflowY === 'overlay')\
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
                if (!active || typeof active.getBoundingClientRect !== 'function') return;\
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
    // Alice patch end 0041' "$path3"

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
            applyPreviewImeVisibleHeight(contentHeight);\
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
