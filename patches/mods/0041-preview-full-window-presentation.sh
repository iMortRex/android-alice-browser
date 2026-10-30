#!/bin/bash
# 让预览网页使用稳定的全窗口展示：同步布局标题栏，并在打开前铺好遮罩。

set -e

path1="components/browser_ui/bottomsheet/android/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetContent.java"
path2="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheetControllerImpl.java"
path3="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabSheetContent.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path7="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"

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

sed -i '/^        if (inset == mVisualViewportInsetBottomPx) return;$/i\
        // Alice patch start 0041\
        int aliceSupplierInset = -1;\
        if (mCurrentInsetSupplier != null \&\& mCurrentInsetSupplier.get() != null) {\
            aliceSupplierInset = mCurrentInsetSupplier.get().visualViewportBottomInset;\
        }\
        org.chromium.base.Log.i(\
                "AliceNav",\
                "tabHidden=%b contentAttached=%b rawSupplier=%d applied=%d previous=%d",\
                mTab.isHidden(),\
                getContentView() != null \&\& getContentView().isAttachedToWindow(),\
                aliceSupplierInset,\
                inset,\
                mVisualViewportInsetBottomPx);\
        // Alice patch end 0041\
' "$path4"

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
        aliceCover.setBackgroundColor(mControlContainer.getToolbarBackgroundColor());\
        aliceCover.setVisibility(View.VISIBLE);\
        final View aliceCoverForPost = aliceCover;\
        if (aliceContentGroup.getChildAt(aliceContentGroup.getChildCount() - 1)\
                != aliceCoverForPost) {\
            aliceCoverForPost.post(\
                    () -> {\
                        if (mAliceStartupNavigationBarCover == aliceCoverForPost\
                                \&\& aliceCoverForPost.getParent() == aliceContentGroup\
                                \&\& aliceContentGroup.getChildAt(\
                                                aliceContentGroup.getChildCount() - 1)\
                                        != aliceCoverForPost) {\
                            aliceCoverForPost.bringToFront();\
                        }\
                    });\
        }\
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

sed -i '/^        boolean aliceVisible =$/,/^                                        aliceControlContainer));$/c\
        // Alice patch start 0041\
        boolean aliceFullWindowPreview =\
                BottomSheetContent.FullWindowPresentationState.isActive();\
        Tab aliceStartupTab = mActiveTabSupplier.get();\
        boolean aliceInitialPageLoading =\
                aliceStartupTab == null || aliceStartupTab.isLoading();\
        if (aliceToolbarReady \&\& !aliceInitialPageLoading) {\
            mAliceInitialPageReady = true;\
        }\
        if (aliceToolbarOnBottom \&\& !mAliceInitialPageReady) {\
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
        boolean aliceVisible =\
                aliceToolbarOnBottom\
                        \&\& aliceNavigationBarHeight > 0\
                        \&\& aliceParentReachesWindowBottom\
                        \&\& (aliceFullWindowPreview\
                                || mLayerVisibility != LayerVisibility.HIDDEN\
                                || mIsImeAnimationRunning\
                                || mKeyboardVisibilityDelegate.isKeyboardShowing(\
                                        aliceControlContainer));\
        // Alice patch end 0041' "$path7"

sed -i '/^        aliceBackground.setVisibility(aliceVisible ? View.VISIBLE : View.INVISIBLE);$/a\
        // Alice patch start 0041\
        org.chromium.base.Log.i(\
                "AliceNav",\
                "toolbarLayer=%d navHeight=%d controlsH=%d"\
                        + " backgroundVisible=%b preview=%b",\
                mLayerVisibility,\
                aliceNavigationBarHeight,\
                aliceControlContainer.getHeight(),\
                aliceVisible,\
                aliceFullWindowPreview);\
        // Alice patch end 0041' "$path7"

sed -i '/^        int webContentsHeight = height - verticalViewportInsets;$/a\
        // Alice patch start 0041\
        org.chromium.base.Log.i(\
                "AliceNav",\
                "viewport height=%d controls=%d nav=%d hidingTokens=%b resizeView=%b result=%d",\
                height,\
                controlsInsets,\
                mAliceNavigationBarInset,\
                mBrowserControlsManager != null \&\& mBrowserControlsManager.hasHidingTokens(),\
                mControlsResizeView,\
                webContentsHeight);\
        // Alice patch end 0041' "$path5"

sed -i '/^            boolean controlsResizeView =$/,/^                    BrowserControlsUtils\.controlsResizeView(mBrowserControlsManager);$/c\
        // Alice patch start 0041\
            boolean controlsResizeView =\
                    org.chromium.components.browser_ui.bottomsheet.BottomSheetContent\
                                    .FullWindowPresentationState.isActive()\
                            || BrowserControlsUtils.controlsResizeView(mBrowserControlsManager);\
        // Alice patch end 0041' "$path5"

sed -i '/^            if (controlsResizeView != mControlsResizeView) {$/i\
            // Alice patch start 0041\
            org.chromium.base.Log.i(\
                    "AliceNav",\
                    "controlsResizeView=%b forcedByPreview=%b",\
                    controlsResizeView,\
                    org.chromium.components.browser_ui.bottomsheet.BottomSheetContent\
                            .FullWindowPresentationState.isActive());\
            // Alice patch end 0041\
' "$path5"

# 0.0.1) Log the real Android/Surface bounds. The JS viewport can stay stable
#         while either the ContentView or its SurfaceControl still draws 48px
#         too far down.
sed -i '/^            webContents.setSize(webContentsWidth, webContentsHeight);$/a\
            logAlicePreviewBounds(webContents, view, webContentsWidth, webContentsHeight);\
            int aliceLoggedWidth = webContentsWidth;\
            int aliceLoggedHeight = webContentsHeight;\
            view.postOnAnimationDelayed(\
                    () -> logAlicePreviewBounds(\
                            webContents, view, aliceLoggedWidth, aliceLoggedHeight),\
                    64);\
' "$path5"

sed -i '/^    private static boolean isAttachedToWindow(@Nullable View view) {$/i\
    // Alice patch start 0041\
    private void logAlicePreviewBounds(\
            WebContents webContents, View contentView, int webContentsWidth, int webContentsHeight) {\
        if (webContents.isDestroyed()) return;\
        Rect contentVisibleRect = new Rect();\
        boolean contentVisible = contentView.getGlobalVisibleRect(contentVisibleRect);\
        int[] contentLocation = new int[2];\
        contentView.getLocationInWindow(contentLocation);\
\
        View surfaceView = getActiveSurfaceView();\
        Rect surfaceVisibleRect = new Rect();\
        Rect surfaceFrame = new Rect();\
        int[] surfaceLocation = new int[2];\
        boolean surfaceVisible = false;\
        int surfaceWidth = -1;\
        int surfaceHeight = -1;\
        if (surfaceView != null) {\
            surfaceVisible = surfaceView.getGlobalVisibleRect(surfaceVisibleRect);\
            surfaceView.getLocationInWindow(surfaceLocation);\
            surfaceWidth = surfaceView.getWidth();\
            surfaceHeight = surfaceView.getHeight();\
            if (surfaceView instanceof android.view.SurfaceView) {\
                surfaceFrame.set(\
                        ((android.view.SurfaceView) surfaceView)\
                                .getHolder()\
                                .getSurfaceFrame());\
            }\
        }\
\
        int rendererViewportHeight =\
                org.chromium.content_public.browser.RenderCoordinates\
                        .fromWebContents(webContents)\
                        .getLastFrameViewportHeightPixInt();\
        int controlsHeight =\
                mBrowserControlsManager != null\
                        ? mBrowserControlsManager.getBottomControlsHeight()\
                        : -1;\
        int controlsMinHeight =\
                mBrowserControlsManager != null\
                        ? mBrowserControlsManager.getBottomControlsMinHeight()\
                        : -1;\
        int controlsOffset =\
                mBrowserControlsManager != null\
                        ? mBrowserControlsManager.getBottomControlOffset()\
                        : -1;\
        org.chromium.base.Log.i(\
                "AliceNav",\
                "bounds preview=%b web=%dx%d content=%dx%d loc=%d,%d visible=%b:%s"\
                        + " compositor=%dx%d surface=%dx%d loc=%d,%d visible=%b:%s"\
                        + " frame=%s rendererVP=%d controls=%d/%d offset=%d",\
                org.chromium.components.browser_ui.bottomsheet.BottomSheetContent\
                        .FullWindowPresentationState.isActive(),\
                webContentsWidth,\
                webContentsHeight,\
                contentView.getWidth(),\
                contentView.getHeight(),\
                contentLocation[0],\
                contentLocation[1],\
                contentVisible,\
                contentVisibleRect,\
                mCompositorView.getWidth(),\
                mCompositorView.getHeight(),\
                surfaceWidth,\
                surfaceHeight,\
                surfaceLocation[0],\
                surfaceLocation[1],\
                surfaceVisible,\
                surfaceVisibleRect,\
                surfaceFrame,\
                rendererViewportHeight,\
                controlsHeight,\
                controlsMinHeight,\
                controlsOffset);\
    }\
    // Alice patch end 0041\
\
' "$path5"

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
sed -i '/^        mThinWebView =$/i\
        // Alice patch start 0041\
        ThinWebViewConstraints constraints = new ThinWebViewConstraints();\
        constraints.supportsOpacity = true;\
        constraints.ignoreSizeChanges = true;\
        // Alice patch end 0041\
' "$path3"

sed -i '/^    private ViewGroup mSheetContentView;$/a\
    // Alice patch start 0041\
    private FrameLayout mContentViewport;\
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
        mContentViewport.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, maxSheetHeight));\
\
        FrameLayout.LayoutParams aliceWebViewParams =\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT,\
                        ViewGroup.LayoutParams.MATCH_PARENT);\
        mThinWebView.getView().setLayoutParams(aliceWebViewParams);\
        mContentViewport.addView(mThinWebView.getView());\
        mSheetContentView.addView(mContentViewport);\
        // Alice patch end 0041' "$path3"

# 5) 固定视口尺寸，并在当前遍历中完成布局，拖动时只平移面板
sed -i '/^    void updateContentHeight(int maxViewHeight) {$/,/^    }$/c\
    // Alice patch start 0041\
    void updateContentHeight(int maxViewHeight) {\
        if (maxViewHeight == 0) return;\
\
        int aliceSheetHeight = getMaxSheetHeight(maxViewHeight);\
        int aliceToolbarHeight = getToolbarHeight();\
        int aliceContentHeight = Math.max(0, aliceSheetHeight - aliceToolbarHeight);\
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

sed -i '/^    @Nullable$/i\
    // Alice patch start 0041\
    @Override\
    public boolean shouldUseFullWindowPresentation() {\
        return true;\
    }\
    // Alice patch end 0041\
\
' "$path3"
