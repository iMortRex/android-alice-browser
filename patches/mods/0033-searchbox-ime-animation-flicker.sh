#!/bin/bash
# 触摸工具栏时预先保存工具栏和导航栏区域，聚焦后再固定显示；弹出输入法
# 时用 IME 动画每一帧的当前 inset 驱动搜索框，并让建议列表止于搜索框
# 上沿。输入法活跃时工具栏背景继续延伸到系统导航栏。顶部地址栏的搜索页
# 背景和遮罩保持全屏，不随输入法缩短。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarCoordinator.java"
path5="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path6="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListViewBinder.java"
path7="chrome/android/java/res/layout/search_activity.xml"
path8="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdown.java"
path9="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"
path10="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdownEmbedder.java"
path11="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/OmniboxSuggestionsDropdownEmbedderImpl.java"
path12="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPage.java"
path13="chrome/browser/fullscreen/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenManager.java"
path14="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path15="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenHtmlApiHandlerBase.java"
path16="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"
path17="chrome/android/java/src/org/chromium/chrome/browser/tab/TabBrowserControlsConstraintsHelper.java"
path18="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarOverlayMediator.java"
path19="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarOverlayCoordinator.java"
path20="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path21="chrome/android/java/src/org/chromium/chrome/browser/searchwidget/SearchActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start 0033' "$path1"; then
    exit 100
fi

# 1) 从根 InsetObserver 接收 IME 动画帧。
sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/i\
// Alice patch start 0033\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path10"

sed -i '/^    View getAnchorView();$/a\
    // Alice patch start 0033\
    default @Nullable InsetObserver getInsetObserver() {\
        return null;\
    }\
\
    default int getWindowHeight() {\
        return 0;\
    }\
    // Alice patch end 0033' "$path10"

sed -i '/^import org\.chromium\.ui\.base\.ViewUtils;$/a\
// Alice patch start 0033\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path11"

sed -i '/^    public View getAnchorView() {$/,/^    }$/c\
    public View getAnchorView() {\
        return mAnchorView;\
    }\
\
    // Alice patch start 0033\
    @Override\
    public @Nullable InsetObserver getInsetObserver() {\
        return mWindowAndroid.getInsetObserver();\
    }\
\
    @Override\
    public int getWindowHeight() {\
        return mWindowAndroid.getDisplay().getDisplayHeight();\
    }\
    // Alice patch end 0033' "$path11"

sed -i '/^import android\.content\.SharedPreferences\.OnSharedPreferenceChangeListener;$/a\
// Alice patch start 0033\
import android.graphics.Bitmap;\
// Alice patch end 0033' "$path1"

sed -i '/^import android\.view\.ViewGroup;$/a\
// Alice patch start 0033\
import android.widget.ImageView;\
// Alice patch end 0033' "$path1"

sed -i '/^import android\.view\.View;$/i\
// Alice patch start 0033\
import android.view.MotionEvent;\
// Alice patch end 0033' "$path1"

sed -i '/^import org\.chromium\.components\.embedder_support\.util\.UrlUtilities;$/i\
// Alice patch start 0033\
import org.chromium.components.browser_ui.widget.TouchEventObserver;\
// Alice patch end 0033' "$path1"

sed -i '/^import androidx\.core\.view\.WindowInsetsCompat;$/a\
// Alice patch start 0033\
import androidx.core.view.WindowInsetsAnimationCompat;\
// Alice patch end 0033' "$path1"

sed -i '/^import java\.util\.function\.Supplier;$/i\
// Alice patch start 0033\
import java.util.List;\
// Alice patch end 0033' "$path1"

sed -i '/^    private final boolean mIsNtpCustomizationV2Enabled;$/a\
    // Alice patch start 0033\
    private @Nullable View mNavigationBarBackground;\
    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;\
    private @Nullable ImageView mSearchToolbarSnapshot;\
    private @Nullable Bitmap mSearchToolbarSnapshotBitmap;\
    private int mSearchToolbarSnapshotWidth;\
    private int mSearchToolbarSnapshotHeight;\
    private int mSearchToolbarSnapshotNavigationBarHeight;\
    private int mSearchToolbarSnapshotColor;\
    private boolean mIsImeAnimationRunning;\
    private int mCurrentImeAnimationHeight = -1;\
    private final InsetObserver.WindowInsetsAnimationListener mImeAnimationListener;\
    private final TouchEventObserver mToolbarTouchObserver =\
            new TouchEventObserver() {\
                @Override\
                public boolean onInterceptTouchEvent(MotionEvent event) {\
                    if (event.getActionMasked() == MotionEvent.ACTION_DOWN\
                            \&\& !mIsOmniboxFocusedSupplier.get()\
                            \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                            \&\& mLayerVisibility != LayerVisibility.HIDDEN) {\
                        releaseSearchToolbarSnapshot();\
                        captureSearchToolbarSnapshot();\
                    }\
                    return false;\
                }\
            };\
    // Alice patch end 0033' "$path1"

sed -i '/^    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;$/a\
\
    // Alice patch start 0033\
    public void setNavigationBarBackgroundColor(int color) {\
        mNavigationBarBackgroundColor = color;\
        if (mNavigationBarBackground != null) {\
            mNavigationBarBackground.setBackgroundColor(color);\
        }\
    }\
    // Alice patch end 0033\
' "$path1"

sed -i '/^        mIsOmniboxFocusedObserver = (focused) -> updateCurrentPosition();$/c\
        // Alice patch start 0033\
        mIsOmniboxFocusedObserver =\
                (focused) -> {\
                    if (focused \&\& mSearchToolbarSnapshotBitmap == null) {\
                        captureSearchToolbarSnapshot();\
                    }\
                    updateCurrentPosition();\
                    updateNavigationBarBackground();\
                    updateSearchToolbarSnapshot();\
                    mControlContainer.getView().postOnAnimation(\
                            ToolbarPositionController.this::updateSearchToolbarSnapshot);\
                };\
        // Alice patch end 0033' "$path1"

# 动画期间缓存每一帧的当前键盘高度。结束后的下一帧再读取最终 root inset，
# 避免 onEnd 与最终 inset 派发顺序不同导致工具栏再跳一次。
sed -i '/^        mKeyboardHeightSupplier\.addSyncObserverAndPostIfNonNull(mKeyboardHeightProgressBarCallback);$/a\
        // Alice patch start 0033\
        mImeAnimationListener =\
                new InsetObserver.WindowInsetsAnimationListener() {\
                    private @Nullable WindowInsetsAnimationCompat mCurrentAnimation;\
\
                    @Override\
                    public void onPrepare(WindowInsetsAnimationCompat animation) {\
                        if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                            return;\
                        }\
                        mCurrentAnimation = animation;\
                        mIsImeAnimationRunning = true;\
                        mCurrentImeAnimationHeight = -1;\
                    }\
\
                    @Override\
                    public void onStart(\
                            WindowInsetsAnimationCompat animation,\
                            WindowInsetsAnimationCompat.BoundsCompat bounds) {}\
\
                    @Override\
                    public void onProgress(\
                            WindowInsetsCompat windowInsets,\
                            List<WindowInsetsAnimationCompat> runningAnimations) {\
                        if (mCurrentAnimation == null) return;\
                        mCurrentImeAnimationHeight =\
                                Math.max(\
                                        0,\
                                        windowInsets\
                                                .getInsets(WindowInsetsCompat.Type.ime())\
                                                .bottom);\
                        updateImeLayerOffsets();\
                    }\
\
                    @Override\
                    public void onEnd(WindowInsetsAnimationCompat animation) {\
                        if (animation != mCurrentAnimation) return;\
                        if (mCurrentImeAnimationHeight >= 0) updateImeLayerOffsets();\
                        mCurrentAnimation = null;\
                        mIsImeAnimationRunning = false;\
                        mCurrentImeAnimationHeight = -1;\
                        mControlContainer\
                                .getView()\
                                .postOnAnimation(\
                                        ToolbarPositionController.this::updateImeLayerOffsets);\
                    }\
                };\
        InsetObserver imeInsetObserver = mWindowAndroid.getInsetObserver();\
        if (imeInsetObserver != null) {\
            imeInsetObserver.addWindowInsetsAnimationListener(mImeAnimationListener);\
        }\
        // Alice patch end 0033' "$path1"

sed -i 's|^        mToolbar\.setToolbarColorObserver(statusBarColorController);$|        // Alice patch start 0033\
        mToolbar.setToolbarColorObserver(\
                new TopToolbarCoordinator.ToolbarColorObserver() {\
                    @Override\
                    public void onToolbarColorChanged(int color) {\
                        statusBarColorController.onToolbarColorChanged(color);\
                        if (mToolbarPositionController != null) {\
                            mToolbarPositionController.setNavigationBarBackgroundColor(color);\
                        }\
                    }\
\
                    @Override\
                    public void onToolbarExpandingOnNtp(boolean isToolbarExpanding) {\
                        statusBarColorController.onToolbarExpandingOnNtp(isToolbarExpanding);\
                    }\
                });\
        // Alice patch end 0033|' "$path2"

sed -i '/^        mSharedPreferences\.registerOnSharedPreferenceChangeListener(this);$/a\
        // Alice patch start 0033\
        mControlContainer.addTouchEventObserver(mToolbarTouchObserver);\
        // Alice patch end 0033' "$path1"

sed -i '/^        mHandler = handler;$/a\
        // Alice patch start 0033\
        mControlContainer\
                .getView()\
                .postOnAnimation(ToolbarPositionController.this::updateNavigationBarBackground);\
        // Alice patch end 0033' "$path1"

# 2) 销毁时注销动画监听。
sed -i '/^        mKeyboardHeightSupplier\.removeObserver(mKeyboardHeightProgressBarCallback);$/a\
        // Alice patch start 0033\
        mControlContainer.removeTouchEventObserver(mToolbarTouchObserver);\
        InsetObserver imeInsetObserver = mWindowAndroid.getInsetObserver();\
        if (imeInsetObserver != null) {\
            imeInsetObserver.removeWindowInsetsAnimationListener(mImeAnimationListener);\
        }\
        if (mNavigationBarBackground != null\
                \&\& mNavigationBarBackground.getParent() instanceof ViewGroup) {\
            ((ViewGroup) mNavigationBarBackground.getParent())\
                    .removeView(mNavigationBarBackground);\
        }\
        mNavigationBarBackground = null;\
        if (mSearchToolbarSnapshot != null\
                \&\& mSearchToolbarSnapshot.getParent() instanceof ViewGroup) {\
            ((ViewGroup) mSearchToolbarSnapshot.getParent())\
                    .removeView(mSearchToolbarSnapshot);\
        }\
        mSearchToolbarSnapshot = null;\
        releaseSearchToolbarSnapshot();\
        // Alice patch end 0033' "$path1"

# 3) 当前帧优先使用动画 inset；动画结束后使用最终 root inset。
sed -i '/^            int keyboardHeight = windowInsetsCompat\.getInsets(WindowInsetsCompat\.Type\.ime())\.bottom;$/c\
            // Alice patch start 0033\
            int keyboardHeight =\
                    mIsImeAnimationRunning && mCurrentImeAnimationHeight >= 0\
                            ? mCurrentImeAnimationHeight\
                            : windowInsetsCompat\
                                    .getInsets(WindowInsetsCompat.Type.ime())\
                                    .bottom;\
            // Alice patch end 0033' "$path1"

# 第一帧 onProgress 到来前不能使用 root 中已经更新的最终 inset，否则搜索框
# 会先闪到最终位置。普通网页表单和搜索页共用同一套逐帧定位。
sed -i '/^        if (mIsOmniboxFocusedSupplier.get() \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM) {$/c\
        // Alice patch start 0033\
        boolean aliceBottomControlsFollowIme =\
                mIsOmniboxFocusedSupplier.get();\
        if (aliceBottomControlsFollowIme\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM) {\
            // Alice patch end 0033' "$path1"

# 4) 工具栏底边取 IME 与导航栏 inset 的较大值。导航栏区域由独立的背景
#    延伸层覆盖，工具栏本身不再为了填背景而永久上移。
sed -i '/^            int maxHeight = windowHeight - keyboardHeight - statusBarHeight;$/c\
            // Alice patch start 0033\
            int aliceNavigationBarHeight = getNavigationBarHeight();\
            int aliceBottomInset =\
                    mIsImeAnimationRunning\
                            ? keyboardHeight\
                            : Math.max(keyboardHeight, aliceNavigationBarHeight);\
            int maxHeight = windowHeight - aliceBottomInset - statusBarHeight;\
            // Alice patch end 0033' "$path1"

sed -i '/^            int maxTranslation = -(windowHeight - layer\.getHeight() - statusBarHeight);$/c\
            // Alice patch start 0033\
            // Use the current IME frame as the minimum absolute bottom offset.\
            // Alice patch end 0033' "$path1"

sed -i '/^            layerYOffset = Math\.max(layerYOffset - keyboardHeight, maxTranslation);$/c\
            // Alice patch start 0033\
            layerYOffset = Math.min(layerYOffset, -aliceBottomInset);\
            // Alice patch end 0033' "$path1"

# 底置工具栏显示真实搜索框，不经过顶部 fakebox 的纵向过渡。
sed -i '/^    private float getLocationBarTranslationY() {$/a\
        // Alice patch start 0033\
        if (urlHasFocus()\
                \&\& isLocationBarShownInGeneralNtp()\
                \&\& isLocationBarShownInNtp()\
                \&\& mBrowserControlsStateProvider != null\
                \&\& mBrowserControlsStateProvider.getControlsPosition()\
                        == ControlsPosition.BOTTOM) {\
            return 0.f;\
        }\
        // Alice patch end 0033' "$path20"

# 5) 搜索页位于底部时，无论 normal 或 overlay 键盘模式都由上面的 inset
#    驱动，避免 resize mode 功能开关把键盘高度清零后产生跳位。
sed -i '/^    private boolean shouldIgnoreKeyboardHeightInResizeMode() {$/,/^    }$/c\
    private boolean shouldIgnoreKeyboardHeightInResizeMode() {\
        // Alice patch start 0033\
        return false;\
        // Alice patch end 0033\
    }' "$path1"

# 6) 底置工具栏内容在输入法或地址栏聚焦时避让系统导航栏高度。
sed -i '/^        viewForLayer\.setTranslationY(layerYOffset);$/i\
        // Alice patch start 0033\
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                \&\& mKeyboardVisibilityDelegate.isKeyboardShowing(\
                        mControlContainer.getView())) {\
            layerYOffset = Math.min(layerYOffset, -getNavigationBarHeight());\
        }\
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                \&\& mIsOmniboxFocusedSupplier.get()\
                \&\& !mIsImeAnimationRunning\
                \&\& !mKeyboardVisibilityDelegate.isKeyboardShowing(\
                        mControlContainer.getView())) {\
            layerYOffset = Math.min(layerYOffset, -getNavigationBarHeight());\
        }\
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                \&\& mIsImeAnimationRunning\
                \&\& !mKeyboardVisibilityDelegate.isKeyboardShowing(\
                        mControlContainer.getView())\
                \&\& layerYOffset > 0) {\
            return;\
        }\
        // Alice patch end 0033\
' "$path1"

# 7) 动画开始、结束和图层刷新时同时校准工具栏与进度条位置。
sed -i '/^    private void updateControlContainerHeight(int height) {$/,/^    }$/c\
    private void updateControlContainerHeight(int height) {\
        assert height >= 0;\
        mControlContainerHeight = height;\
        mBottomControlsStacker.requestLayerUpdate(false);\
    }\
\
    // Alice patch start 0033\
    private void updateImeLayerOffsets() {\
        updateViewOffset(mBottomToolbarLayer, mControlContainer.getView());\
        updateViewOffset(mProgressBarLayer, mToolbarProgressBarContainer);\
    }\
\
    private int getNavigationBarHeight() {\
        View aliceRoot = mControlContainer.getView().getRootView();\
        if (aliceRoot.getContext() instanceof android.app.Activity\
                \&\& ((android.app.Activity) aliceRoot.getContext())\
                        .isInMultiWindowMode()) {\
            return 0;\
        }\
        WindowInsetsCompat aliceCompatInsets = null;\
        InsetObserver aliceInsetObserver = mWindowAndroid.getInsetObserver();\
        if (aliceInsetObserver != null) {\
            aliceCompatInsets = aliceInsetObserver.getLastRawWindowInsets();\
        }\
        if (aliceCompatInsets == null) {\
            android.view.WindowInsets aliceInsets = aliceRoot.getRootWindowInsets();\
            if (aliceInsets != null) {\
                aliceCompatInsets =\
                        WindowInsetsCompat.toWindowInsetsCompat(aliceInsets, aliceRoot);\
            }\
        }\
        if (aliceCompatInsets == null) return 0;\
        boolean aliceKeyboardShowing =\
                mKeyboardVisibilityDelegate.isKeyboardShowing(aliceRoot);\
        if (!aliceCompatInsets.isVisible(WindowInsetsCompat.Type.navigationBars())\
                \&\& !aliceKeyboardShowing) {\
            return 0;\
        }\
        return Math.max(\
                Math.max(\
                        aliceCompatInsets\
                                .getInsetsIgnoringVisibility(\
                                        WindowInsetsCompat.Type.navigationBars())\
                                .bottom,\
                        aliceCompatInsets\
                                .getInsetsIgnoringVisibility(\
                                        WindowInsetsCompat.Type.mandatorySystemGestures())\
                                .bottom),\
                aliceCompatInsets\
                        .getInsetsIgnoringVisibility(\
                                WindowInsetsCompat.Type.tappableElement())\
                        .bottom);\
    }\
\
    private void updateNavigationBarBackground() {\
        View aliceControlContainer = mControlContainer.getView();\
        if (!(aliceControlContainer instanceof ViewGroup)\
                || !(aliceControlContainer.getParent() instanceof ViewGroup)) {\
            return;\
        }\
        ViewGroup aliceContainer = (ViewGroup) aliceControlContainer;\
        ViewGroup aliceParent = (ViewGroup) aliceControlContainer.getParent();\
        CoordinatorLayout.LayoutParams aliceToolbarParams =\
                mControlContainer.mutateToolbarLayoutParams();\
        boolean aliceToolbarOnBottom =\
                mCurrentPosition.get() == ControlsPosition.BOTTOM\
                        || !isToolbarConfiguredToShowOnTop();\
        int aliceToolbarTopMargin = 0;\
        if (aliceToolbarOnBottom\
                \&\& !mIsOmniboxFocusedSupplier.get()) {\
            aliceToolbarTopMargin = mHairlineHeight;\
        }\
        if (aliceToolbarParams.topMargin != aliceToolbarTopMargin) {\
            aliceToolbarParams.topMargin = aliceToolbarTopMargin;\
            aliceContainer.requestLayout();\
        }\
        int aliceNavigationBarHeight = getNavigationBarHeight();\
        if (mNavigationBarBackground == null) {\
            View aliceBackground = new View(aliceContainer.getContext());\
            aliceBackground.setClickable(false);\
            aliceBackground.setFocusable(false);\
            aliceBackground.setImportantForAccessibility(\
                    View.IMPORTANT_FOR_ACCESSIBILITY_NO);\
            aliceBackground.setOnApplyWindowInsetsListener(\
                    (aliceInsetView, aliceWindowInsets) -> {\
                        int aliceBottomInset =\
                                Math.max(\
                                        aliceWindowInsets\
                                                .getInsets(\
                                                        android.view.WindowInsets.Type\
                                                                .navigationBars())\
                                                .bottom,\
                                        aliceWindowInsets\
                                                .getInsets(\
                                                        android.view.WindowInsets.Type\
                                                                .mandatorySystemGestures())\
                                                .bottom);\
                        ViewGroup.LayoutParams aliceInsetParams =\
                                aliceInsetView.getLayoutParams();\
                        if (aliceBottomInset > 0\
                                \&\& aliceInsetParams != null\
                                \&\& aliceInsetParams.height != aliceBottomInset) {\
                            aliceInsetView.post(\
                                    ToolbarPositionController.this::updateNavigationBarBackground);\
                        }\
                        return aliceWindowInsets;\
                    });\
            CoordinatorLayout.LayoutParams aliceParams =\
                    new CoordinatorLayout.LayoutParams(\
                            ViewGroup.LayoutParams.MATCH_PARENT,\
                            aliceNavigationBarHeight);\
            aliceParams.gravity = Gravity.BOTTOM;\
            int aliceIndex = aliceParent.indexOfChild(aliceControlContainer);\
            if (aliceIndex < 0) aliceIndex = aliceParent.getChildCount();\
            aliceParent.addView(aliceBackground, aliceIndex, aliceParams);\
            aliceParent.setClipChildren(false);\
            aliceParent.setClipToPadding(false);\
            mNavigationBarBackground = aliceBackground;\
        }\
\
        View aliceBackground = mNavigationBarBackground;\
        assert aliceBackground != null;\
        CoordinatorLayout.LayoutParams aliceParams =\
                (CoordinatorLayout.LayoutParams) aliceBackground.getLayoutParams();\
        if (aliceParams.height != aliceNavigationBarHeight) {\
            aliceParams.height = aliceNavigationBarHeight;\
            aliceBackground.setLayoutParams(aliceParams);\
        }\
        aliceBackground.setTranslationY(0);\
        int aliceBackgroundColor =\
                mNavigationBarBackgroundColor != Integer.MIN_VALUE\
                        ? mNavigationBarBackgroundColor\
                        : mControlContainer.getToolbarBackgroundColor();\
        mNavigationBarBackgroundColor = aliceBackgroundColor;\
        aliceBackground.setBackgroundColor(aliceBackgroundColor);\
        View aliceVisibleToolbar =\
                aliceControlContainer.findViewById(R.id.toolbar_container);\
        boolean aliceToolbarReady =\
                aliceVisibleToolbar != null \&\& aliceVisibleToolbar.getHeight() > 0;\
        boolean aliceVisible =\
                aliceToolbarOnBottom\
                        \&\& aliceNavigationBarHeight > 0\
                        \&\& !mIsOmniboxFocusedSupplier.get()\
                        \&\& (mLayerVisibility != LayerVisibility.HIDDEN\
                                || mIsImeAnimationRunning\
                                || mKeyboardVisibilityDelegate.isKeyboardShowing(\
                                        aliceControlContainer));\
        aliceBackground.setVisibility(aliceVisible ? View.VISIBLE : View.INVISIBLE);\
        if (!mIsOmniboxFocusedSupplier.get()) {\
            captureSearchToolbarSnapshot();\
        } else {\
            updateSearchToolbarSnapshot();\
        }\
    }\
\
    void requestSearchToolbarSnapshotCapture() {\
        mControlContainer\
                .getView()\
                .postOnAnimation(\
                        () -> {\
                            if (!mIsOmniboxFocusedSupplier.get()) {\
                                captureSearchToolbarSnapshot();\
                            }\
                        });\
    }\
    private void captureSearchToolbarSnapshot() {\
        View aliceControlContainer = mControlContainer.getView();\
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
        if (aliceSnapshot == null) {\
            aliceSnapshot = new ImageView(aliceParent.getContext());\
            aliceSnapshot.setClickable(false);\
            aliceSnapshot.setFocusable(false);\
            aliceSnapshot.setImportantForAccessibility(\
                    View.IMPORTANT_FOR_ACCESSIBILITY_NO);\
            aliceSnapshot.setScaleType(ImageView.ScaleType.FIT_XY);\
            aliceSnapshot.setVisibility(View.INVISIBLE);\
            CoordinatorLayout.LayoutParams aliceParams =\
                    new CoordinatorLayout.LayoutParams(\
                            ViewGroup.LayoutParams.MATCH_PARENT, aliceSnapshotHeight);\
            aliceParams.gravity = Gravity.BOTTOM;\
            int aliceIndex = aliceParent.indexOfChild(aliceControlContainer);\
            if (aliceIndex < 0) aliceIndex = aliceParent.getChildCount();\
            aliceParent.addView(aliceSnapshot, aliceIndex, aliceParams);\
            mSearchToolbarSnapshot = aliceSnapshot;\
        }\
        assert aliceSnapshot != null;\
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
    private void updateSearchToolbarSnapshot() {\
        boolean aliceFocused = mIsOmniboxFocusedSupplier.get();\
        boolean aliceShouldShow =\
                aliceFocused\
                        \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                        \&\& mLayerVisibility != LayerVisibility.HIDDEN;\
        if (!aliceShouldShow) {\
            if (mSearchToolbarSnapshot != null) {\
                mSearchToolbarSnapshot.setVisibility(View.INVISIBLE);\
            }\
            if (!aliceFocused) releaseSearchToolbarSnapshot();\
            return;\
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
            moveSearchToolbarSnapshotBelowScrim();\
            aliceSnapshot.setVisibility(View.VISIBLE);\
        }\
    }\
\
    private void moveSearchToolbarSnapshotBelowScrim() {\
        ImageView aliceSnapshot = mSearchToolbarSnapshot;\
        if (aliceSnapshot == null\
                || !(aliceSnapshot.getParent() instanceof ViewGroup)) {\
            return;\
        }\
        ViewGroup aliceParent = (ViewGroup) aliceSnapshot.getParent();\
        ViewGroup.LayoutParams aliceParams = aliceSnapshot.getLayoutParams();\
        aliceParent.postOnAnimation(\
                () -> {\
                    if (mSearchToolbarSnapshot != aliceSnapshot\
                            || aliceSnapshot.getParent() != aliceParent) {\
                        return;\
                    }\
                    int aliceScrimIndex = -1;\
                    for (int i = 0; i < aliceParent.getChildCount(); i++) {\
                        View aliceChild = aliceParent.getChildAt(i);\
                        if ("ScrimView".equals(aliceChild.getClass().getSimpleName())) {\
                            aliceScrimIndex = i;\
                            break;\
                        }\
                    }\
                    int aliceSnapshotIndex = aliceParent.indexOfChild(aliceSnapshot);\
                    if (aliceScrimIndex < 0 || aliceSnapshotIndex < aliceScrimIndex) return;\
                    aliceParent.removeView(aliceSnapshot);\
                    aliceParent.addView(aliceSnapshot, aliceScrimIndex, aliceParams);\
                });\
    }\
\
    private void releaseSearchToolbarSnapshot() {\
        if (mSearchToolbarSnapshot != null) {\
            mSearchToolbarSnapshot.setImageDrawable(null);\
        }\
        if (mSearchToolbarSnapshotBitmap != null) {\
            mSearchToolbarSnapshotBitmap.recycle();\
            mSearchToolbarSnapshotBitmap = null;\
        }\
        mSearchToolbarSnapshotWidth = 0;\
        mSearchToolbarSnapshotHeight = 0;\
        mSearchToolbarSnapshotNavigationBarHeight = 0;\
        mSearchToolbarSnapshotColor = 0;\
    }\
    // Alice patch end 0033' "$path1"

# 8) 动画开始后但尚未收到第一帧时不更新位置，避免 root inset 的最终值
#    在动画首帧前把工具栏推到终点；导航栏背景仍需立即刷新。
sed -i '/^        if (mLayerVisibility == LayerVisibility.HIDDEN) return;$/c\
        // Alice patch start 0033\
        updateNavigationBarBackground();\
        if (mLayerVisibility == LayerVisibility.HIDDEN) return;\
        if (mCurrentPosition.get() == ControlsPosition.BOTTOM\
                \&\& mIsImeAnimationRunning\
                \&\& mCurrentImeAnimationHeight < 0) {\
            return;\
        }\
        // Alice patch end 0033' "$path1"

# 9) 遮罩通过根 InsetObserver 接收动画帧。子树上的 WindowInsetsAnimation
#    回调会被根节点的 DISPATCH_MODE_STOP 截断，收起键盘时会直接落到终点。
sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/a\
// Alice patch start 0033\
import org.chromium.build.annotations.Nullable;\
// Alice patch end 0033' "$path3"

sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BottomControlsStacker;$/i\
// Alice patch start 0033\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider;\
// Alice patch end 0033' "$path3"

sed -i '/^import org\.chromium\.ui\.base\.DeviceFormFactor;$/i\
// Alice patch start 0033\
import org.chromium.ui.KeyboardVisibilityDelegate;\
// Alice patch end 0033' "$path3"

sed -i '/^import org\.chromium\.ui\.base\.DeviceFormFactor;$/a\
// Alice patch start 0033\
import org.chromium.ui.base.WindowAndroid;\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path3"

sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0033\
import android.view.ViewGroup;\
import android.view.ViewTreeObserver;\
// Alice patch end 0033' "$path3"

sed -i '/^import org\.chromium\.components\.browser_ui\.widget\.scrim\.ScrimProperties;$/a\
// Alice patch start 0033\
import org.chromium.components.browser_ui.widget.scrim.ScrimView;\
// Alice patch end 0033' "$path3"

sed -i '/^                                updateScrimBottomMargin());$/a\
            // Alice patch start 0033\
            mImeBoundaryView = aliceBottomBoundary;\
            ViewTreeObserver.OnPreDrawListener aliceBoundaryPreDrawListener =\
                    () -> {\
                        View aliceBoundary = mImeBoundaryView;\
                        if (aliceBoundary == null) return true;\
                        boolean aliceBottomToolbar = isBottomToolbarActive();\
                        aliceBoundary.getLocationInWindow(mImeBoundaryPosition);\
                        View aliceRoot = aliceBoundary.getRootView();\
                        if (mScrimModel.get(ScrimProperties.TOP_MARGIN) != 0) {\
                            mScrimModel.set(ScrimProperties.TOP_MARGIN, 0);\
                        }\
                        if (mScrimModel.get(ScrimProperties.BOTTOM_MARGIN) != 0) {\
                            mScrimModel.set(ScrimProperties.BOTTOM_MARGIN, 0);\
                        }\
                        @Nullable View aliceScrim = mOmniboxScrimView;\
                        if (aliceScrim == null || aliceScrim.getParent() == null) {\
                            aliceScrim = findOmniboxScrimView(aliceRoot);\
                            mOmniboxScrimView = aliceScrim;\
                        }\
                        if (aliceScrim != null\
                                \&\& aliceScrim.getParent() instanceof View) {\
                            View aliceScrimParent = (View) aliceScrim.getParent();\
                            if (aliceScrim.getLayoutParams()\
                                    instanceof ViewGroup.MarginLayoutParams) {\
                                ViewGroup.MarginLayoutParams aliceScrimParams =\
                                        (ViewGroup.MarginLayoutParams)\
                                                aliceScrim.getLayoutParams();\
                                aliceScrimParams.topMargin = 0;\
                                aliceScrimParams.bottomMargin = 0;\
                            }\
                            aliceScrimParent.getLocationInWindow(mScrimParentPosition);\
                            int aliceScrimBottom =\
                                    aliceBottomToolbar\
                                            ? Math.max(\
                                                    0,\
                                                    Math.min(\
                                                            aliceScrimParent.getHeight(),\
                                                            mImeBoundaryPosition[1]\
                                                                    - mScrimParentPosition[1]))\
                                            : aliceScrimParent.getHeight();\
                            if (aliceScrim.getBottom() != aliceScrimBottom) {\
                                aliceScrim.layout(\
                                        aliceScrim.getLeft(),\
                                        aliceScrim.getTop(),\
                                        aliceScrim.getRight(),\
                                        aliceScrimBottom);\
                            }\
                        }\
                        return true;\
                    };\
            mImeBoundaryPreDrawListener = aliceBoundaryPreDrawListener;\
            aliceBottomBoundary\
                    .getViewTreeObserver()\
                    .addOnPreDrawListener(aliceBoundaryPreDrawListener);\
            // Alice patch end 0033' "$path3"

sed -i '/^                    mScrimModel\.set(ScrimProperties\.TOP_MARGIN, newHeight);$/c\
                    // Alice patch start 0033\
                    mScrimModel.set(\
                            ScrimProperties.TOP_MARGIN,\
                            isBottomToolbarActive() ? 0 : newHeight);\
                    // Alice patch end 0033' "$path3"

sed -i '/^    private final BottomControlsStacker mBottomControlsStacker;$/a\
    // Alice patch start 0033\
    private @Nullable BrowserControlsStateProvider mBrowserControlsStateProvider;\
    private @Nullable InsetObserver mImeInsetObserver;\
    private @Nullable View mImeBoundaryView;\
    private ViewTreeObserver.@Nullable OnPreDrawListener mImeBoundaryPreDrawListener;\
    private final int[] mImeBoundaryPosition = new int[2];\
    private final int[] mScrimParentPosition = new int[2];\
    private @Nullable View mOmniboxScrimView;\
    private boolean mIsImeAnimationRunning;\
    private int mCurrentImeAnimationHeight = -1;\
    private final InsetObserver.WindowInsetsAnimationListener mImeAnimationListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                        return;\
                    }\
                    mIsImeAnimationRunning = true;\
                    mCurrentImeAnimationHeight = -1;\
                }\
\
                @Override\
                public void onStart(\
                        WindowInsetsAnimationCompat animation,\
                        WindowInsetsAnimationCompat.BoundsCompat bounds) {}\
\
                @Override\
                public void onProgress(\
                        WindowInsetsCompat insets,\
                        List<WindowInsetsAnimationCompat> runningAnimations) {\
                    mCurrentImeAnimationHeight =\
                            Math.max(\
                                    0,\
                                    insets.getInsets(WindowInsetsCompat.Type.ime()).bottom);\
                    updateScrimBottomMargin(mCurrentImeAnimationHeight);\
                }\
\
                @Override\
                public void onEnd(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                        return;\
                    }\
                    if (mCurrentImeAnimationHeight >= 0) {\
                        updateScrimBottomMargin(mCurrentImeAnimationHeight);\
                    }\
                    mIsImeAnimationRunning = false;\
                    mCurrentImeAnimationHeight = -1;\
                    if (mContext instanceof Activity) {\
                        View aliceBoundary =\
                                ((Activity) mContext).findViewById(R.id.control_container);\
                        if (aliceBoundary != null) {\
                            aliceBoundary.postOnAnimation(\
                                    LocationBarFocusScrimHandler.this::updateScrimBottomMargin);\
                        }\
                    }\
                }\
            };\
    // Alice patch end 0033' "$path3"

sed -i '/^    public void updateScrimVisualState() {$/i\
    // Alice patch start 0033\
    void setWindowAndroid(\
            WindowAndroid windowAndroid,\
            @Nullable BrowserControlsStateProvider browserControlsStateProvider) {\
        mBrowserControlsStateProvider = browserControlsStateProvider;\
        if (mImeInsetObserver != null) {\
            mImeInsetObserver.removeWindowInsetsAnimationListener(\
                    mImeAnimationListener);\
        }\
        mImeInsetObserver = windowAndroid.getInsetObserver();\
        if (mImeInsetObserver != null) {\
            mImeInsetObserver.addWindowInsetsAnimationListener(mImeAnimationListener);\
        }\
        updateScrimBottomMargin();\
    }\
    // Alice patch end 0033\
' "$path3"

sed -i '/^    private void updateScrimBottomMargin() {$/a\
        // Alice patch start 0033\
        if (!isBottomToolbarActive()) {\
            updateScrimBottomMargin(0);\
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
        if (mIsImeAnimationRunning) {\
            if (mCurrentImeAnimationHeight >= 0) {\
                updateScrimBottomMargin(mCurrentImeAnimationHeight);\
            }\
            return;\
        }\
        // Alice patch end 0033' "$path3"

sed -i '/^    private void updateScrimBottomMargin() {$/i\
    // Alice patch start 0033\
    private @Nullable View findOmniboxScrimView(View view) {\
        if (view.getVisibility() != View.GONE \&\& view instanceof ScrimView) {\
            return view;\
        }\
        if (!(view instanceof ViewGroup)) return null;\
        ViewGroup group = (ViewGroup) view;\
        for (int i = 0; i < group.getChildCount(); i++) {\
            @Nullable View result = findOmniboxScrimView(group.getChildAt(i));\
            if (result != null) return result;\
        }\
        return null;\
    }\
    // Alice patch end 0033\
' "$path3"

sed -i '/^    private void updateScrimBottomMargin(int bottomMargin) {$/,/^    }$/c\
    private void updateScrimBottomMargin(int bottomMargin) {\
        // Alice patch start 0033\
        mScrimModel.set(ScrimProperties.TOP_MARGIN, 0);\
        if (mScrimModel.get(ScrimProperties.BOTTOM_MARGIN) != 0) {\
            mScrimModel.set(ScrimProperties.BOTTOM_MARGIN, 0);\
        }\
        // Alice patch end 0033\
    }\
\
    private boolean isBottomToolbarActive() {\
        // Alice patch start 0033\
        return mBrowserControlsStateProvider != null\
                \&\& mBrowserControlsStateProvider.getControlsPosition()\
                        == BrowserControlsStateProvider.ControlsPosition.BOTTOM;\
        // Alice patch end 0033\
    }' "$path3"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0033\
        if (mImeBoundaryView != null \&\& mImeBoundaryPreDrawListener != null) {\
            ViewTreeObserver aliceBoundaryObserver =\
                    mImeBoundaryView.getViewTreeObserver();\
            if (aliceBoundaryObserver.isAlive()) {\
                aliceBoundaryObserver.removeOnPreDrawListener(\
                        mImeBoundaryPreDrawListener);\
            }\
        }\
        mImeBoundaryView = null;\
        mImeBoundaryPreDrawListener = null;\
        mOmniboxScrimView = null;\
        if (mImeInsetObserver != null) {\
            mImeInsetObserver.removeWindowInsetsAnimationListener(\
                    mImeAnimationListener);\
            mImeInsetObserver = null;\
        }\
        // Alice patch end 0033' "$path3"

sed -i '/^        mWindowAndroid = windowAndroid;$/a\
        // Alice patch start 0033\
        if (scrimHandler != null) {\
            scrimHandler.setWindowAndroid(\
                    windowAndroid, browserControlsStateProvider);\
        }\
        // Alice patch end 0033' "$path4"

# 底置工具栏由 ToolbarPositionController 逐帧移动。bottom_container 不再
# 写入 IME 高度，顶部搜索页的纯色背景也能一直铺到窗口底部。
sed -i '/^    private void updateBottomContainerPosition() {$/,/^    }$/c\
    private void updateBottomContainerPosition() {\
        // Alice patch start 0033\
        MarginLayoutParams aliceLayoutParams =\
                (MarginLayoutParams) mBottomContainerView.getLayoutParams();\
        aliceLayoutParams.bottomMargin = 0;\
        // Alice patch end 0033\
    }' "$path4"

sed -i '/^        mOmniboxAlignment = omniboxAlignment;$/a\
        // Alice patch start 0033\
        if (mEmbedder != null \&\& mEmbedder.isToolbarOnBottom()) {\
            adjustHorizontalPosition();\
            if (!isWidthDifference) return;\
        }\
        // Alice patch end 0033' "$path5"

# 10) 底置工具栏时，推荐内容从搜索框上沿向上排列；内容超出窗口后再滚动。
#     列表保持完整视口高度，底边逐帧贴住搜索框上沿；超出的顶部由父布局裁剪。
sed -i '/^    void onUrlFocusAnimationChanged() {$/a\
        // Alice patch start 0033\
        if (mToolbarOnBottom) {\
            mModel.set(NewTabPageLayoutProperties.TRANSITION_Y, 0f);\
            return;\
        }\
        // Alice patch end 0033' "$path9"

sed -i '/^    void setToolbarOnBottom(boolean toolbarOnBottom) {$/,/^    }$/c\
    void setToolbarOnBottom(boolean toolbarOnBottom) {\
        // Alice patch start 0033\
        if (mToolbarOnBottom == toolbarOnBottom) return;\
        mToolbarOnBottom = toolbarOnBottom;\
        updateToolbarInsets();\
        onUrlFocusAnimationChanged();\
        // Alice patch end 0033\
    }' "$path9"

sed -i '/^    <org\.chromium\.ui\.AsyncViewStub$/i\
    <!-- Alice patch start 0033 -->' "$path7"
sed -i 's|^        app:layout_anchor="@id/toolbar"$|        android:layout_gravity="top"|' \
    "$path7"
sed -i '/^        app:inflatedId="@+id\/search_activity_suggestions_container"\/>$/a\
    <!-- Alice patch end 0033 -->' "$path7"

sed -i '/^        mBrowserControlsStateProvider\.addObserver(this);$/i\
        // Alice patch start 0033\
        mNewTabPageCoordinator.setToolbarOnBottom(\
                mBrowserControlsStateProvider.getControlsPosition()\
                        == ControlsPosition.BOTTOM);\
        // Alice patch end 0033' "$path12"

sed -i '/^import androidx\.annotation\.VisibleForTesting;$/a\
// Alice patch start 0033\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0033' "$path5"

sed -i '/^import org\.chromium\.ui\.base\.ViewUtils;$/a\
// Alice patch start 0033\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path5"

sed -i '/^    private final int\[\] mStickPosition = new int\[2\];$/a\
    // Alice patch start 0033\
    private int mAliceBottomViewportHeight = -1;\
    private boolean mAliceImeAnimationActive;\
    private @Nullable InsetObserver mSuggestionsInsetObserver;\
    private final InsetObserver.WindowInsetsAnimationListener mSuggestionsImeListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if (mEmbedder != null\
                            \&\& mEmbedder.isToolbarOnBottom()\
                            \&\& (animation.getTypeMask()\
                                            \& WindowInsetsCompat.Type.ime())\
                                    != 0) {\
                        mAliceImeAnimationActive = true;\
                        prepareAliceBottomAnchoredAnimation();\
                    }\
                }\
\
                @Override\
                public void onStart(\
                        WindowInsetsAnimationCompat animation,\
                        WindowInsetsAnimationCompat.BoundsCompat bounds) {}\
\
                @Override\
                public void onProgress(\
                        WindowInsetsCompat insets,\
                        java.util.List<WindowInsetsAnimationCompat> runningAnimations) {\
                    if (mEmbedder != null \&\& mEmbedder.isToolbarOnBottom()) {\
                        updateAliceImeViewport(insets);\
                    }\
                }\
\
                @Override\
                public void onEnd(WindowInsetsAnimationCompat animation) {\
                    if (mEmbedder != null\
                            \&\& mEmbedder.isToolbarOnBottom()\
                            \&\& (animation.getTypeMask()\
                                            \& WindowInsetsCompat.Type.ime())\
                                    != 0) {\
                        mAliceImeAnimationActive = false;\
                        postOnAnimation(\
                                OmniboxSuggestionsContainer.this::stickToAnchor);\
                    }\
                }\
            };\
    // Alice patch end 0033' "$path5"

sed -i '/^    private boolean stickToAnchor() {$/i\
    // Alice patch start 0033\
    private int getAliceNavigationBarHeight() {\
        if (getContext() instanceof android.app.Activity\
                \&\& ((android.app.Activity) getContext()).isInMultiWindowMode()) {\
            return 0;\
        }\
        android.view.WindowInsets aliceRootInsets = getRootWindowInsets();\
        if (aliceRootInsets == null) return 0;\
        WindowInsetsCompat aliceInsets =\
                WindowInsetsCompat.toWindowInsetsCompat(aliceRootInsets, getRootView());\
        return Math.max(\
                aliceInsets\
                        .getInsets(WindowInsetsCompat.Type.navigationBars())\
                        .bottom,\
                aliceInsets\
                        .getInsets(WindowInsetsCompat.Type.mandatorySystemGestures())\
                        .bottom);\
    }\
\
    private void updateAliceBottomAnchoredPosition(\
            int aliceTargetTop, int aliceContainerTop) {\
        int aliceWindowHeight = getRootView().getHeight();\
        if (aliceWindowHeight <= 0) aliceWindowHeight = mEmbedder.getWindowHeight();\
        int aliceAnchorHeight = mEmbedder.getAnchorView().getHeight();\
        int aliceViewportHeight =\
                Math.max(\
                        0,\
                        aliceWindowHeight\
                                - getAliceNavigationBarHeight()\
                                - aliceAnchorHeight\
                                - aliceContainerTop);\
        if (aliceViewportHeight <= 0) return;\
        mAliceBottomViewportHeight = aliceViewportHeight;\
        setAliceDropdownStackFromEnd(true);\
        updateAliceDropdownViewportHeight(aliceViewportHeight);\
        float aliceTranslationY =\
                aliceTargetTop - (aliceContainerTop + aliceViewportHeight);\
        if (mDropdown.getTranslationY() != aliceTranslationY) {\
            mDropdown.setTranslationY(aliceTranslationY);\
        }\
    }\
\
    private void prepareAliceBottomAnchoredAnimation() {\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int aliceTargetTop = mStickPosition[1];\
        getLocationInWindow(mStickPosition);\
        updateAliceBottomAnchoredPosition(\
                aliceTargetTop, mStickPosition[1]);\
    }\
\
    private void updateAliceSettledViewport(\
            int aliceTargetTop, int aliceContainerTop) {\
        int aliceViewportHeight = Math.max(0, aliceTargetTop - aliceContainerTop);\
        if (aliceViewportHeight <= 0) return;\
        mAliceBottomViewportHeight = aliceViewportHeight;\
        setAliceDropdownStackFromEnd(true);\
        updateAliceDropdownViewportHeight(aliceViewportHeight);\
        if (mDropdown.getTranslationY() != 0) {\
            mDropdown.setTranslationY(0);\
        }\
    }\
\
    private void updateAliceImeViewport(WindowInsetsCompat insets) {\
        if (mDropdown.getVisibility() != View.VISIBLE) return;\
        int aliceImeHeight = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;\
        int aliceBottomInset = aliceImeHeight;\
        int aliceAnchorHeight = mEmbedder.getAnchorView().getHeight();\
        int aliceWindowHeight = getRootView().getHeight();\
        if (aliceWindowHeight <= 0) aliceWindowHeight = mEmbedder.getWindowHeight();\
        getLocationInWindow(mStickPosition);\
        int aliceContainerTop = mStickPosition[1];\
        int aliceViewportHeight =\
                Math.max(\
                        0,\
                        aliceWindowHeight\
                                - aliceBottomInset\
                                - aliceAnchorHeight\
                                - aliceContainerTop);\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int aliceCurrentAnchorTop = mStickPosition[1];\
        aliceViewportHeight =\
                Math.min(\
                        aliceViewportHeight,\
                        Math.max(0, aliceCurrentAnchorTop - aliceContainerTop));\
        updateAliceBottomAnchoredPosition(\
                aliceCurrentAnchorTop, aliceContainerTop);\
        int aliceBaseBottomPadding = mDropdown.getBaseBottomPadding();\
        if (mDropdown.getPaddingBottom() != aliceBaseBottomPadding) {\
            mDropdown.setPaddingRelative(\
                    mDropdown.getPaddingStart(),\
                    mDropdown.getPaddingTop(),\
                    mDropdown.getPaddingEnd(),\
                    aliceBaseBottomPadding);\
        }\
    }\
    // Alice patch end 0033\
' "$path5"

sed -i '/^    protected void onFinishInflate() {$/,/^    }$/c\
    // Alice patch start 0033\
    protected void onFinishInflate() {\
        super.onFinishInflate();\
        mDropdown = findViewById(R.id.omnibox_suggestions_dropdown);\
    }\
\
    @Override\
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {\
        super.onSizeChanged(width, height, oldWidth, oldHeight);\
        if (width == oldWidth \&\& height == oldHeight) return;\
        mAliceBottomViewportHeight = -1;\
        postOnAnimation(OmniboxSuggestionsContainer.this::stickToAnchor);\
    }\
    // Alice patch end 0033' "$path5"

# 对齐信息变化时同步保留顶部工具栏的额外间距，避免预绘制监听器下一帧才补回，
# 从而出现建议列表向上抖动一帧。
sed -i '/^        mDropdown\.setPaddingRelative($/,/^                mDropdown\.getBaseBottomPadding() + mOmniboxAlignment\.paddingBottom);$/c\
        // Alice patch start 0033\
        int aliceTopPadding =\
                mDropdown.getBaseTopPadding() + mOmniboxAlignment.paddingTop;\
        if (mEmbedder != null \&\& !mEmbedder.isToolbarOnBottom()) {\
            aliceTopPadding +=\
                    getResources()\
                            .getDimensionPixelSize(\
                                    R.dimen.location_bar_vertical_margin);\
        }\
        mDropdown.setPaddingRelative(\
                mDropdown.getPaddingStart(),\
                aliceTopPadding,\
                mDropdown.getPaddingEnd(),\
                mDropdown.getBaseBottomPadding()\
                        + mOmniboxAlignment.paddingBottom);\
        // Alice patch end 0033' "$path5"

# 搜索页只在地址栏位于顶部时保持全屏高度；底置地址栏继续跟随输入法 resize。
sed -i '/^import android\.view\.ViewGroup;$/a\
// Alice patch start 0033\
import android.view.WindowManager;\
// Alice patch end 0033' "$path21"

sed -i '/^import org\.chromium\.chrome\.browser\.tabwindow\.TabWindowInfo;$/a\
// Alice patch start 0033\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0033' "$path21"

sed -i '/^    protected ModalDialogManager createModalDialogManager() {$/,/^    protected void triggerLayoutInflation() {$/{
    /^    @Override$/i\
    // Alice patch start 0033\
    private boolean mAliceSoftInputModePreDrawAttached;\
\
    private void setAliceSoftInputAdjustMode(boolean toolbarOnTop) {\
        int aliceSoftInputMode = getWindow().getAttributes().softInputMode;\
        int aliceTargetAdjustMode =\
                toolbarOnTop\
                        ? WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING\
                        : WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;\
        if ((aliceSoftInputMode \& WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST)\
                == aliceTargetAdjustMode) {\
            return;\
        }\
        aliceSoftInputMode \&= ~WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST;\
        aliceSoftInputMode |= aliceTargetAdjustMode;\
        getWindow().setSoftInputMode(aliceSoftInputMode);\
    }\
\
    @Override\
    protected void onPreCreate() {\
        super.onPreCreate();\
        setAliceSoftInputAdjustMode(\
                AddressBarPreference.isToolbarConfiguredToShowOnTop());\
    }\
\
    private void updateAliceSoftInputMode(View rootView) {\
        if (!mAliceSoftInputModePreDrawAttached) {\
            mAliceSoftInputModePreDrawAttached = true;\
            rootView\
                    .getViewTreeObserver()\
                    .addOnPreDrawListener(\
                            () -> {\
                                updateAliceSoftInputMode(rootView);\
                                return true;\
                            });\
        }\
        View aliceToolbar = rootView.findViewById(R.id.toolbar);\
        if (aliceToolbar == null || rootView.getHeight() <= 0) return;\
        int[] aliceToolbarLocation = new int[2];\
        aliceToolbar.getLocationInWindow(aliceToolbarLocation);\
        setAliceSoftInputAdjustMode(\
                aliceToolbarLocation[1] + aliceToolbar.getHeight() / 2\
                        < rootView.getHeight() / 2);\
    }\
    // Alice patch end 0033
}' "$path21"

sed -i '/^        setContentView(contentView);$/a\
        // Alice patch start 0033\
        contentView.addOnLayoutChangeListener(\
                (view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) ->\
                        updateAliceSoftInputMode(view));\
        contentView.post(() -> updateAliceSoftInputMode(contentView));\
        // Alice patch end 0033' "$path21"

sed -i '/^            getViewTreeObserver().addOnPreDrawListener(mStickListener);$/a\
            // Alice patch start 0033\
            if (mSuggestionsInsetObserver != null) {\
                mSuggestionsInsetObserver.removeWindowInsetsAnimationListener(\
                        mSuggestionsImeListener);\
            }\
            mSuggestionsInsetObserver = mEmbedder.getInsetObserver();\
            if (mSuggestionsInsetObserver != null) {\
                mSuggestionsInsetObserver.addWindowInsetsAnimationListener(\
                        mSuggestionsImeListener);\
            }\
            // Alice patch end 0033' "$path5"

sed -i '/^            getViewTreeObserver().removeOnPreDrawListener(mStickListener);$/a\
            // Alice patch start 0033\
            mAliceBottomViewportHeight = -1;\
            mAliceImeAnimationActive = false;\
            setClipBounds(null);\
            if (mSuggestionsInsetObserver != null) {\
                mSuggestionsInsetObserver.removeWindowInsetsAnimationListener(\
                        mSuggestionsImeListener);\
                mSuggestionsInsetObserver = null;\
            }\
            // Alice patch end 0033' "$path5"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0033\
        if (mSuggestionsInsetObserver != null) {\
            mSuggestionsInsetObserver.removeWindowInsetsAnimationListener(\
                    mSuggestionsImeListener);\
            mSuggestionsInsetObserver = null;\
        }\
        // Alice patch end 0033' "$path5"

sed -i '/^        private @Nullable Callback<Integer> mScrollOffsetListener;$/a\
        // Alice patch start 0033\
        private boolean mAliceBottomAnchored;\
\
        void setAliceBottomAnchored(boolean bottomAnchored) {\
            if (mAliceBottomAnchored == bottomAnchored) return;\
            mAliceBottomAnchored = bottomAnchored;\
            mIsScrolledToTop = !bottomAnchored;\
        }\
        // Alice patch end 0033' "$path8"

sed -i '/^            if (OmniboxFeatures\.sResetSuggestionsScroll\.isEnabled()) {$/c\
            // Alice patch start 0033\
            if (OmniboxFeatures.sResetSuggestionsScroll.isEnabled()\
                    \&\& !mAliceBottomAnchored) {\
            // Alice patch end 0033' "$path8"

sed -i '/^    private float mChildAlpha = 1.0f;$/a\
    // Alice patch start 0033\
    private boolean mAliceBottomAnchored;\
    // Alice patch end 0033' "$path8"

sed -i '/^    public void resetSelection() {$/,/^    }$/c\
    public void resetSelection() {\
        // Alice patch start 0033\
        if (!mAliceBottomAnchored) {\
            mLayoutScrollListener.scrollToPositionWithOffset(0, 0);\
        }\
        // Alice patch end 0033\
        mSelectionController.reset();\
    }' "$path8"

sed -i '/^            if (!mIsScrolledToTop) return;$/c\
            // Alice patch start 0033\
            if (!mIsScrolledToTop || mAliceBottomAnchored) return;\
            // Alice patch end 0033' "$path8"

sed -i '/^                int resultingDeltaY, int requestedDeltaY) {$/a\
            // Alice patch start 0033\
            if (mAliceBottomAnchored) return resultingDeltaY;\
            // Alice patch end 0033' "$path8"

sed -i '/^    public void translateChildrenVertical(float translation) {$/,/^    }$/c\
    public void translateChildrenVertical(float translation) {\
        mChildVerticalTranslation = translation;\
        final int childCount = getChildCount();\
        for (int i = 0; i < childCount; i++) {\
            getChildAt(i).setTranslationY(translation);\
        }\
        invalidateItemDecorations();\
    }\
\
    // Alice patch start 0033\
    void setAliceBottomAnchored(boolean bottomAnchored) {\
        mAliceBottomAnchored = bottomAnchored;\
        mLayoutScrollListener.setAliceBottomAnchored(bottomAnchored);\
    }\
    // Alice patch end 0033' "$path8"

sed -i '/^    private boolean stickToAnchor() {$/,/^    }$/c\
    // Alice patch start 0033\
    private void setAliceDropdownStackFromEnd(boolean stackFromEnd) {\
        mDropdown.setAliceBottomAnchored(stackFromEnd);\
        androidx.recyclerview.widget.RecyclerView.LayoutManager aliceLayoutManager =\
                mDropdown.getLayoutManager();\
        if (!(aliceLayoutManager\
                instanceof androidx.recyclerview.widget.LinearLayoutManager)) {\
            return;\
        }\
        androidx.recyclerview.widget.LinearLayoutManager aliceLinearLayoutManager =\
                (androidx.recyclerview.widget.LinearLayoutManager)\
                        aliceLayoutManager;\
        if (aliceLinearLayoutManager.getStackFromEnd() != stackFromEnd) {\
            aliceLinearLayoutManager.setStackFromEnd(stackFromEnd);\
        }\
    }\
\
    private boolean updateAliceDropdownViewportHeight(int height) {\
        if (height <= 0) return false;\
        ViewGroup.LayoutParams aliceDropdownParams = mDropdown.getLayoutParams();\
        if (aliceDropdownParams.height == height\
                \&\& mDropdown.getHeight() == height) {\
            return false;\
        }\
        aliceDropdownParams.height = height;\
        int aliceWidth = mDropdown.getWidth();\
        if (aliceWidth > 0) {\
            // Apply the size in this traversal instead of scheduling a second layout\
            // that can draw a different viewport for one frame.\
            mDropdown.forceLayout();\
            mDropdown.measure(\
                    MeasureSpec.makeMeasureSpec(aliceWidth, MeasureSpec.EXACTLY),\
                    MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY));\
            mDropdown.layout(\
                    mDropdown.getLeft(),\
                    0,\
                    mDropdown.getLeft() + aliceWidth,\
                    height);\
        }\
        return true;\
    }\
\
    private boolean stickToAnchor() {\
        if (mDropdown == null) return true;\
        if (getTranslationY() != 0) setTranslationY(0);\
        if (mEmbedder == null || !mEmbedder.isToolbarOnBottom()) {\
            setAliceDropdownStackFromEnd(false);\
            mAliceBottomViewportHeight = -1;\
            mAliceImeAnimationActive = false;\
            int aliceTopSpacing =\
                    getResources()\
                            .getDimensionPixelSize(R.dimen.location_bar_vertical_margin);\
            int aliceDesiredTopPadding =\
                    mDropdown.getBaseTopPadding()\
                            + mOmniboxAlignment.paddingTop\
                            + aliceTopSpacing;\
            if (mDropdown.getPaddingTop() != aliceDesiredTopPadding) {\
                mDropdown.setPaddingRelative(\
                        mDropdown.getPaddingStart(),\
                        aliceDesiredTopPadding,\
                        mDropdown.getPaddingEnd(),\
                        mDropdown.getPaddingBottom());\
            }\
            int aliceDesiredBottomPadding = mDropdown.getBaseBottomPadding();\
            if (mDropdown.getPaddingBottom() != aliceDesiredBottomPadding) {\
                mDropdown.setPaddingRelative(\
                        mDropdown.getPaddingStart(),\
                        mDropdown.getPaddingTop(),\
                        mDropdown.getPaddingEnd(),\
                        aliceDesiredBottomPadding);\
            }\
            ViewGroup.LayoutParams aliceDropdownParams = mDropdown.getLayoutParams();\
            int aliceDropdownHeight = ViewGroup.LayoutParams.WRAP_CONTENT;\
            if (mEmbedder != null \&\& mOmniboxAlignment.height > 0) {\
                aliceDropdownHeight = mOmniboxAlignment.height;\
            }\
            if (aliceDropdownParams.height != aliceDropdownHeight) {\
                aliceDropdownParams.height = aliceDropdownHeight;\
                mDropdown.setLayoutParams(aliceDropdownParams);\
            }\
            setClipBounds(null);\
            if (mDropdown.getTranslationY() != 0) mDropdown.setTranslationY(0);\
            return true;\
        }\
        if (mDropdown.getVisibility() != View.VISIBLE) return true;\
        int aliceTopPadding = 0;\
        if (mDropdown.getPaddingTop() != aliceTopPadding) {\
            mDropdown.setPaddingRelative(\
                    mDropdown.getPaddingStart(),\
                    aliceTopPadding,\
                    mDropdown.getPaddingEnd(),\
                    mDropdown.getPaddingBottom());\
        }\
        int aliceBottomPadding = mDropdown.getBaseBottomPadding();\
        if (mDropdown.getPaddingBottom() != aliceBottomPadding) {\
            mDropdown.setPaddingRelative(\
                    mDropdown.getPaddingStart(),\
                    mDropdown.getPaddingTop(),\
                    mDropdown.getPaddingEnd(),\
                    aliceBottomPadding);\
        }\
        View aliceParent =\
                mDropdown.getParent() instanceof View ? (View) mDropdown.getParent() : null;\
        while (aliceParent instanceof ViewGroup) {\
            ((ViewGroup) aliceParent).setClipChildren(true);\
            ((ViewGroup) aliceParent).setClipToPadding(true);\
            aliceParent =\
                    aliceParent.getParent() instanceof View\
                            ? (View) aliceParent.getParent()\
                            : null;\
        }\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int aliceTargetTop = mStickPosition[1];\
        getLocationInWindow(mStickPosition);\
        int aliceContainerTop = mStickPosition[1];\
        if (aliceTargetTop <= aliceContainerTop || getWidth() <= 0) return true;\
        if (mAliceImeAnimationActive) {\
            updateAliceBottomAnchoredPosition(aliceTargetTop, aliceContainerTop);\
        } else {\
            updateAliceSettledViewport(aliceTargetTop, aliceContainerTop);\
        }\
        setClipBounds(null);\
        return true;\
    }\
    // Alice patch end 0033' "$path5"

sed -i '/^            int availableViewportHeight = mOmniboxAlignment\.height;$/c\
            // Alice patch start 0033\
            int availableViewportHeight = MeasureSpec.getSize(heightMeasureSpec);\
            if (availableViewportHeight <= 0) {\
                availableViewportHeight = mOmniboxAlignment.height;\
            }\
            // Alice patch end 0033' "$path5"

sed -i '/^        } else if (propertyKey == SuggestionListProperties\.CHILD_TRANSLATION_Y) {$/,/^        } else if (propertyKey == SuggestionListProperties\.COLOR_SCHEME) {$/c\
        // Alice patch start 0033\
        } else if (propertyKey == SuggestionListProperties.CHILD_TRANSLATION_Y) {\
            float aliceTranslation =\
                    model.get(SuggestionListProperties.CHILD_TRANSLATION_Y);\
            OmniboxSuggestionsDropdownEmbedder aliceEmbedder =\
                    model.get(SuggestionListProperties.EMBEDDER);\
            if (aliceEmbedder != null \&\& aliceEmbedder.isToolbarOnBottom()) {\
                aliceTranslation = 0;\
            }\
            view.dropdown.translateChildrenVertical(aliceTranslation);\
        // Alice patch end 0033\
        } else if (propertyKey == SuggestionListProperties.COLOR_SCHEME) {' "$path6"

sed -i '/^        } else if (propertyKey == SuggestionListProperties\.ALPHA) {$/,/^        } else if (propertyKey == SuggestionListProperties\.APPLY_MARGIN_FOR_LEFT_SIDE_BAR) {$/c\
        // Alice patch start 0033\
        } else if (propertyKey == SuggestionListProperties.ALPHA) {\
            float aliceAlpha = model.get(SuggestionListProperties.ALPHA);\
            OmniboxSuggestionsDropdownEmbedder aliceEmbedder =\
                    model.get(SuggestionListProperties.EMBEDDER);\
            if (aliceEmbedder != null \&\& aliceEmbedder.isToolbarOnBottom()) {\
                aliceAlpha = 1f;\
            }\
            view.dropdown.setChildAlpha(aliceAlpha);\
        // Alice patch end 0033\
        } else if (propertyKey == SuggestionListProperties.APPLY_MARGIN_FOR_LEFT_SIDE_BAR) {' "$path6"

sed -i '/^    private void updateColorScheme(PropertyModel model, SuggestionListViewHolder holder) {$/,/^    }$/c\
    private void updateColorScheme(PropertyModel model, SuggestionListViewHolder holder) {\
        @FuseboxLayoutMode int layoutMode = model.get(SuggestionListProperties.FUSEBOX_LAYOUT_MODE);\
        @ColorInt\
        int backgroundColor =\
                getResourceProvider(model)\
                        .getSuggestionBackgroundColor(layoutMode, /* isDropdownContainer= */ true);\
        OmniboxSuggestionsDropdownEmbedder aliceEmbedder =\
                model.get(SuggestionListProperties.EMBEDDER);\
        boolean aliceBottomAnchored =\
                aliceEmbedder != null \&\& aliceEmbedder.isToolbarOnBottom();\
\
        holder.dropdown.setBackgroundColor(backgroundColor);\
\
        if (aliceBottomAnchored\
                || (model.get(SuggestionListProperties.IS_LARGE_SCREEN)\
                        \&\& layoutMode != FuseboxLayoutMode.SUGGESTIONS_POPOVER)) {\
            holder.container.setBackgroundColor(Color.TRANSPARENT);\
        } else {\
            holder.container.setBackgroundColor(backgroundColor);\
        }\
    }' "$path6"

sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/a\
// Alice patch start 0033\
import org.chromium.build.annotations.Nullable;\
// Alice patch end 0033' "$path6"

sed -i '/^            listItems\.addObserver($/,/^                    });$/c\
            // Alice patch start 0033\
            listItems.addObserver(\
                    new ListObservable.ListObserver<>() {\
                        @Override\
                        public void onItemRangeInserted(\
                                ListObservable source, int index, int count) {\
                            view.dropdown.resetSelection();\
                            updateContainerVisibility(model, view);\
                        }\
\
                        @Override\
                        public void onItemRangeRemoved(\
                                ListObservable source, int index, int count) {\
                            updateContainerVisibility(model, view);\
                        }\
\
                        @Override\
                        public void onItemRangeChanged(\
                                ListObservable<Void> source,\
                                int index,\
                                int count,\
                                @Nullable Void payload) {\
                        }\
                    });\
            // Alice patch end 0033' "$path6"

# 12) 全屏时隐藏 compositor 工具栏层，避免底置工具栏残留在视频画面上。
sed -i '/^public interface FullscreenManager {$/a\
    // Alice patch start 0033\
    final class FullscreenTransitionState {\
        private static volatile boolean sAliceExitingFullscreen;\
\
        public static void setExitingFullscreen(boolean exiting) {\
            sAliceExitingFullscreen = exiting;\
        }\
\
        public static boolean isExitingFullscreen() {\
            return sAliceExitingFullscreen;\
        }\
    }\
    // Alice patch end 0033\
\
' "$path13"

sed -i '/^                    enterPersistentFullscreenMode(options);$/i\
                    // Alice patch start 0033\
                    FullscreenManager.FullscreenTransitionState\
                            .setExitingFullscreen(false);\
                    // Alice patch end 0033\
' "$path15"
sed -i '/^    public void onExitFullscreen(Tab tab) {$/a\
        // Alice patch start 0033\
        FullscreenManager.FullscreenTransitionState.setExitingFullscreen(true);\
        // Alice patch end 0033\
' "$path15"

# 退出全屏时直接把 controls 设为 SHOWN，明确禁止 show 动画；否则 BOTH 会让
# renderer 在退出后的第一帧补播一次工具栏显隐动画。
sed -i '/^    private void resetExitFullscreenLayoutChangeListener(View contentView) {$/,/^    }$/s@^                            mTab, BrowserControlsState.SHOWN, true);$@                            // Alice patch start 0033\n                            mTab, BrowserControlsState.SHOWN, false);\n                            // Alice patch end 0033@' "$path15"

sed -i '/^import org\.chromium\.chrome\.browser\.flags\.ChromeFeatureList;$/a\
// Alice patch start 0033\
import org.chromium.chrome.browser.fullscreen.FullscreenManager;\
// Alice patch end 0033\
' "$path17"
sed -i '/^        int constraints = getConstraints();$/a\
        // Alice patch start 0033\
        if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()\
                \&\& current == BrowserControlsState.BOTH) {\
            constraints = BrowserControlsState.BOTH;\
        }\
        // Alice patch end 0033\
' "$path17"
sed -i '/^    private void updateEnabledState() {$/,/^    }$/s@^        update(BrowserControlsState.BOTH, getConstraints() != BrowserControlsState.HIDDEN);$@        // Alice patch start 0033\n        if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\n            update(BrowserControlsState.SHOWN, false);\n        } else {\n            update(\n                    BrowserControlsState.BOTH,\n                    getConstraints() != BrowserControlsState.HIDDEN);\n        }\n        // Alice patch end 0033@' "$path17"

sed -i '/^        if (constraints == BrowserControlsState.SHOWN) {$/i\
            // Alice patch start 0033\
            if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
                scheduleVisibilityUpdate();\
                return;\
            }\
            if (constraints == BrowserControlsState.HIDDEN) {\
                scheduleVisibilityUpdate();\
            }\
            // Alice patch end 0033' "$path16"

# 全屏必须优先于 offsetOverridden；否则 controls 动画留下的 overridden 状态
# 会让 Android 工具栏在全屏中仍然被判为可见。
sed -i '/^        if (offsetOverridden()) return true;$/i\
        // Alice patch start 0033\
        if (getFullscreenManager() != null\
                \&\& getFullscreenManager().getPersistentFullscreenMode()) {\
            return false;\
        }\
        // Alice patch end 0033\
' "$path16"

sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsVisibilityManager;$/a\
// Alice patch start 0033\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0033\
' "$path18"

sed -i '/^    private void updateVisibility() {$/a\
        // Alice patch start 0033\
        if (mBrowserControlsVisibilityManager.getControlsPosition()\
                        == ControlsPosition.BOTTOM\
                || !AddressBarPreference.isToolbarConfiguredToShowOnTop()) {\
            mModel.set(TopToolbarOverlayProperties.VISIBLE, false);\
            return;\
        }\
        // Alice patch end 0033\
' "$path18"

sed -i '/^    boolean shouldBeAttachedToTree() {$/a\
        // Alice patch start 0033\
        if (mBrowserControlsVisibilityManager.getControlsPosition()\
                == ControlsPosition.BOTTOM) {\
            return false;\
        }\
        // Alice patch end 0033\
' "$path18"

sed -i '/^import org\.chromium\.chrome\.browser\.toolbar\.ToolbarProgressBar;$/a\
// Alice patch start 0033\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0033\
' "$path19"

# 底置工具栏首次创建时直接以隐藏状态初始化 compositor 工具栏，
# 避免它先以默认 true 绘制一帧后才被 mediator 改回 false。
sed -i '/^                        \.with(TopToolbarOverlayProperties\.VISIBLE, true)$/c\
                        // Alice patch start 0033\
                        .with(TopToolbarOverlayProperties.VISIBLE, false)\
                        // Alice patch end 0033' "$path19"

sed -i '/^    public boolean isSceneOverlayTreeShowing() {$/a\
        // Alice patch start 0033\
        if (!AddressBarPreference.isToolbarConfiguredToShowOnTop()) {\
            return false;\
        }\
        // Alice patch end 0033\
' "$path19"

sed -i '/^                mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow || mIsUrlBarFocusedForSceneLayer);$/c\
                mIsXrFsm\
                        || mIsVerticalTabsHiddenDueToNarrow\
                        // Alice patch start 0033\
                        || (mIsUrlBarFocusedForSceneLayer\
                                \&\& !isAliceDefaultNtpBottomOmniboxFocused())\
                        || mFullscreenManager.getPersistentFullscreenMode()\
                        || mInTabSwitcherTransition\
                        || (mLayoutStateProvider != null\
                                \&\& mLayoutStateProvider.getActiveLayoutType()\
                                        == LayoutType.HUB));\
                        // Alice patch end 0033' "$path2"

sed -i '/^                        mToolbar\.onTransitionEnd();$/a\
                        // Alice patch start 0033\
                        updateToolbarSceneLayerSuppression();\
                        if (mToolbarPositionController != null) {\
                            mToolbarPositionController.requestSearchToolbarSnapshotCapture();\
                        }\
                        // Alice patch end 0033' "$path2"

sed -i '/^        mToolbar\.setContentAttached(layoutType == LayoutType\.BROWSING);$/a\
        // Alice patch start 0033\
        updateToolbarSceneLayerSuppression();\
        if (mToolbarPositionController != null) {\
            mToolbarPositionController.requestSearchToolbarSnapshotCapture();\
        }\
        // Alice patch end 0033' "$path2"

# 进入全屏后立即刷新场景层抑制状态。
sed -i '/^                                        false, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0033\
                        FullscreenManager.FullscreenTransitionState\
                                .setExitingFullscreen(false);\
                        updateToolbarSceneLayerSuppression();\
                        // Alice patch end 0033' "$path2"

# 退出全屏后等 controls 动画结束，再应用最新 inset 并恢复工具栏场景层。
sed -i '/^                                        true, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0033\
                        FullscreenManager.FullscreenTransitionState\
                                .setExitingFullscreen(true);\
                        refreshToolbarAfterFullscreen();\
                        // Alice patch end 0033' "$path2"

sed -i '/^    private void updateToolbarSceneLayerSuppression() {$/i\
    // Alice patch start 0033\
    private void refreshToolbarAfterFullscreen() {\
        View aliceControlContainer = mControlContainer.getView();\
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
    }\
    // Alice patch end 0033\
' "$path2"

sed -i '/^    private void updateContentViewChildrenDimension() {$/i\
    // Alice patch start 0033\
    public void finishAliceFullscreenExit() {\
        onViewportChanged();\
        tryUpdateControlsAndWebContentsSizing();\
        updateWebContentsSize(getCurrentTab());\
        FullscreenManager.FullscreenTransitionState.setExitingFullscreen(false);\
        requestRender();\
        View aliceContentView = getContentView();\
        if (aliceContentView != null) {\
            aliceContentView.postInvalidateOnAnimation();\
        }\
    }\
    // Alice patch end 0033\
\
' "$path14"

sed -i '/^            applyMarginToFullscreenChildViews(view, topViewsTranslation, bottomMargin);$/{
n
c\
            // Alice patch start 0033\
            if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
                onViewportChanged();\
                requestRender();\
            } else {\
                tryUpdateControlsAndWebContentsSizing();\
            }\
            // Alice patch end 0033
}' "$path14"
