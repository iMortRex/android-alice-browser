#!/bin/bash
# 底置工具栏 IME 动画：用逐帧 inset 驱动搜索框和工具栏，处理导航栏背景、
# 聚焦遮罩和底置工具栏位置。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarCoordinator.java"
path5="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path6="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdownEmbedder.java"
path7="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/OmniboxSuggestionsDropdownEmbedderImpl.java"
path8="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path9="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start 0033' "$path1"; then
    exit 100
fi

# 1) 从根 InsetObserver 接收 IME 动画帧。
sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/i\
// Alice patch start 0033\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path6"

# 接口方法只依赖上游已有声明，避免与 0049 的 getAnchorView 修改交叉。
sed -i '/^    boolean isWideWindow();$/a\
    // Alice patch start 0033\
    default @Nullable InsetObserver getInsetObserver() {\
        return null;\
    }\
\
    default int getWindowHeight() {\
        return 0;\
    }\
    // Alice patch end 0033' "$path6"

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.ui\.base\.ViewUtils;$/a\
// Alice patch start 0033\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path7"

# 实现方法插在上游 isPhoneStyleWindow() 后，不替换 0049 的 getAnchorView。
sed -i '/^    public boolean isPhoneStyleWindow() {$/,/^    }$/ { /^    }$/a\
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
    // Alice patch end 0033
; }' "$path7"

# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.content\.SharedPreferences\.OnSharedPreferenceChangeListener;$/a\
// Alice patch start 0033\
import android.graphics.Bitmap;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.view\.ViewGroup;$/a\
// Alice patch start 0033\
import android.widget.ImageView;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.view\.View;$/i\
// Alice patch start 0033\
import android.view.MotionEvent;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.components\.embedder_support\.util\.UrlUtilities;$/i\
// Alice patch start 0033\
import org.chromium.components.browser_ui.widget.TouchEventObserver;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import androidx\.core\.view\.WindowInsetsCompat;$/a\
// Alice patch start 0033\
import androidx.core.view.WindowInsetsAnimationCompat;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import java\.util\.function\.Supplier;$/i\
// Alice patch start 0033\
import java.util.List;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.view\.ViewGroup;$/a\
// Alice patch start 0033\
import android.view.ViewTreeObserver;\
// Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private final boolean mIsNtpCustomizationV2Enabled;$/a\
    // Alice patch start 0033\
    private @Nullable View mNavigationBarBackground;\
    private @Nullable ViewGroup mNavigationBarBackgroundContainer;\
    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;\
    private static final long ALICE_NAVIGATION_BAR_RETRY_TIMEOUT_MS = 3000;\
    private ViewTreeObserver.@Nullable OnPreDrawListener\
            mAliceNavigationBarRetryListener;\
    private long mAliceNavigationBarRetryDeadline;\
    private float mAliceTabSwitcherBackgroundAlpha = -1f;\
    private @Nullable ImageView mSearchToolbarSnapshot;\
    private @Nullable Bitmap mSearchToolbarSnapshotBitmap;\
    private int mSearchToolbarSnapshotWidth;\
    private int mSearchToolbarSnapshotHeight;\
    private int mSearchToolbarSnapshotNavigationBarHeight;\
    private int mSearchToolbarSnapshotColor;\
    private boolean mAliceFullscreenExitMarginHandoffPending;\
    private final View.OnLayoutChangeListener mAliceFullscreenExitLayoutHandoffListener =\
            new View.OnLayoutChangeListener() {\
                @Override\
                public void onLayoutChange(\
                        View view,\
                        int left,\
                        int top,\
                        int right,\
                        int bottom,\
                        int oldLeft,\
                        int oldTop,\
                        int oldRight,\
                        int oldBottom) {\
                    if (!mAliceFullscreenExitMarginHandoffPending) {\
                        view.removeOnLayoutChangeListener(this);\
                        return;\
                    }\
                    CoordinatorLayout.LayoutParams layoutParams =\
                            (CoordinatorLayout.LayoutParams) view.getLayoutParams();\
                    if (layoutParams.bottomMargin != 0) return;\
                    mAliceFullscreenExitMarginHandoffPending = false;\
                    view.removeOnLayoutChangeListener(this);\
                    mBottomControlsStacker.requestLayerUpdate(false);\
                }\
            };\
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

# 修改对应源码以完成本补丁功能。
sed -i '/^    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;$/a\
\
    // Alice patch start 0033\
    public void setNavigationBarBackgroundColor(int color) {\
        mNavigationBarBackgroundColor = color;\
        if (mNavigationBarBackground != null) {\
            mNavigationBarBackground.setBackgroundColor(color);\
        } else {\
            updateNavigationBarBackground();\
        }\
    }\
\
    public void setAliceTabSwitcherBackgroundAlpha(float alpha) {\
        mAliceTabSwitcherBackgroundAlpha = Math.max(0f, Math.min(1f, alpha));\
        if (mNavigationBarBackground == null) {\
            updateNavigationBarBackground();\
        }\
        View aliceBackground = mNavigationBarBackground;\
        if (aliceBackground == null) return;\
        aliceBackground.setAlpha(mAliceTabSwitcherBackgroundAlpha);\
        aliceBackground.setVisibility(\
                mAliceTabSwitcherBackgroundAlpha > 0f ? View.VISIBLE : View.INVISIBLE);\
    }\
\
    void refreshAliceNavigationBarBackground() {\
        if (!FullscreenManager.FullscreenTransitionState.isPersistentFullscreen()\
                \&\& FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
            mAliceTabSwitcherBackgroundAlpha = 1f;\
        }\
        updateNavigationBarBackground();\
    }\
\
    void setAliceFullscreenExitLayout(boolean exiting) {\
        int aliceNavigationBarHeight = 0;\
        if (exiting \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM) {\
            aliceNavigationBarHeight = mAliceFullscreenCapturedNavigationBarHeight;\
            if (aliceNavigationBarHeight <= 0) {\
                aliceNavigationBarHeight = getNavigationBarHeight();\
            }\
        }\
        View aliceControlContainer = mControlContainer.getView();\
        if (exiting) {\
            mAliceFullscreenExitMarginHandoffPending = false;\
            aliceControlContainer.removeOnLayoutChangeListener(\
                    mAliceFullscreenExitLayoutHandoffListener);\
        }\
        CoordinatorLayout.LayoutParams aliceLayoutParams = mControlContainer.mutateLayoutParams();\
        boolean aliceBottomMarginChanged =\
                aliceLayoutParams.bottomMargin != aliceNavigationBarHeight;\
        if (aliceBottomMarginChanged) {\
            aliceLayoutParams.bottomMargin = aliceNavigationBarHeight;\
            aliceControlContainer.setTranslationY(0);\
            aliceControlContainer.requestLayout();\
        }\
        if (!exiting \&\& aliceBottomMarginChanged) {\
            mAliceFullscreenExitMarginHandoffPending = true;\
            aliceControlContainer.removeOnLayoutChangeListener(\
                    mAliceFullscreenExitLayoutHandoffListener);\
            aliceControlContainer.addOnLayoutChangeListener(\
                    mAliceFullscreenExitLayoutHandoffListener);\
            return;\
        }\
        if (exiting) {\
            aliceControlContainer.setVisibility(View.VISIBLE);\
        }\
        mBottomControlsStacker.requestLayerUpdate(false);\
    }\
    // Alice patch end 0033\
' "$path1"

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
sed -i '/^        mIsTabSwitcherFinishedShowingObserver = (showing) -> updateCurrentPosition();$/c\
        // Alice patch start 0033\
        mIsTabSwitcherFinishedShowingObserver =\
                (showing) -> {\
                    updateCurrentPosition();\
                    updateNavigationBarBackground();\
                };\
        // Alice patch end 0033' "$path1"

# 动画期间缓存每一帧的当前键盘高度，并在 onEnd 后保留最后一帧。root inset
# 可能晚于动画完成才包含系统导航栏，立即切换会让工具栏再上跳一次。
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
                        // Keep the final animation frame until the next IME animation.\
                        // Root insets can include an extra system-bar inset at this point.\
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

# 修改对应源码以完成本补丁功能。
sed -i 's|^        mToolbar\.setToolbarColorObserver(statusBarColorController);$|        // Alice patch start 0033\
        mToolbar.setToolbarColorObserver(\
                new TopToolbarCoordinator.ToolbarColorObserver() {\
                    @Override\
                    public void onToolbarColorChanged(int color) {\
                        mAliceLastToolbarBackgroundColor = color;\
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

# Toolbar 颜色回调可能早于 ToolbarPositionController 创建。保存最近一次实际
# 工具栏背景色，并在控制器创建后补发，避免启动时模拟导航栏停留在旧色。
sed -i '/^    private @Nullable Tab mLastTab;$/a\
    // Alice patch start 0033\
    private int mAliceLastToolbarBackgroundColor = Integer.MIN_VALUE;\
    // Alice patch end 0033' "$path2"

# 修改对应源码以完成本补丁功能。
sed -i '/^                        mWindowAndroid);$/a\
        // Alice patch start 0033\
        // Toolbar color callbacks can arrive before ToolbarPositionController is created.\
        if (mAliceLastToolbarBackgroundColor != Integer.MIN_VALUE\
                \&\& mToolbarPositionController != null) {\
            mToolbarPositionController.setNavigationBarBackgroundColor(\
                    mAliceLastToolbarBackgroundColor);\
        }\
        // Alice patch end 0033' "$path2"

# 修改对应源码以完成本补丁功能。
sed -i '/^        mSharedPreferences\.registerOnSharedPreferenceChangeListener(this);$/a\
        // Alice patch start 0033\
        mControlContainer.addTouchEventObserver(mToolbarTouchObserver);\
        // Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
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
        removeAliceNavigationBarBackgroundRetry();\
        if (mNavigationBarBackground != null\
                \&\& mNavigationBarBackgroundContainer != null\
                \&\& mNavigationBarBackgroundContainer.getParent() instanceof ViewGroup) {\
            ((ViewGroup) mNavigationBarBackgroundContainer.getParent())\
                    .removeView(mNavigationBarBackgroundContainer);\
        } else if (mNavigationBarBackground != null\
                \&\& mNavigationBarBackground.getParent() instanceof ViewGroup) {\
            ((ViewGroup) mNavigationBarBackground.getParent())\
                    .removeView(mNavigationBarBackground);\
        }\
        mNavigationBarBackgroundContainer = null;\
        mNavigationBarBackground = null;\
        if (mSearchToolbarSnapshot != null\
                \&\& mSearchToolbarSnapshot.getParent() instanceof ViewGroup) {\
            ((ViewGroup) mSearchToolbarSnapshot.getParent())\
                    .removeView(mSearchToolbarSnapshot);\
        }\
        mSearchToolbarSnapshot = null;\
        releaseSearchToolbarSnapshot();\
        // Alice patch end 0033' "$path1"

# 3) 当前帧优先使用动画 inset；结束后继续使用动画最后一帧，直到下一次 IME
#    动画开始才重新读取 root inset。
sed -i '/^            int keyboardHeight = windowInsetsCompat\.getInsets(WindowInsetsCompat\.Type\.ime())\.bottom;$/c\
            // Alice patch start 0033\
            int keyboardHeight =\
                    mCurrentImeAnimationHeight >= 0\
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

# 网页表单输入时窗口不能 resize，否则工具栏会被整个窗口一起推到 IME 上方。
sed -i '/^                        WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN$/,/^                                | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);$/c\
                        // Alice patch start 0033\
                        WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN\
                                | (org.chromium.chrome.browser.toolbar.settings.AddressBarPreference\
                                                .isToolbarConfiguredToShowOnTop()\
                                        ? WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE\
                                        : WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING));\
                        // Alice patch end 0033' "$path9"

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

# 修改对应源码以完成本补丁功能。
sed -i '/^            int maxTranslation = -(windowHeight - layer\.getHeight() - statusBarHeight);$/c\
            // Alice patch start 0033\
            // Use the current IME frame as the minimum absolute bottom offset.\
            // Alice patch end 0033' "$path1"

# 修改对应源码以完成本补丁功能。
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
        // Alice patch end 0033' "$path8"

# 只在视觉状态真的变化时刷新工具栏颜色，避免布局帧反复把滑动混合色刷回旧色。
sed -i 's|^        if (mTabSwitcherState != EXITING_TAB_SWITCHER) {$|        // Alice patch start 0033\
        if (visualStateChanged\
                \&\& mTabSwitcherState != EXITING_TAB_SWITCHER) {\
        // Alice patch end 0033|' "$path8"

# 修改对应源码以完成本补丁功能。
sed -i 's|^                updateToolbarBackgroundFromState(VisualState.BRAND_COLOR);$|                // Alice patch start 0033\
                // Toolbar color changes are event-driven; do not refresh it on every layout.\
                // Alice patch end 0033|' "$path8"

# 5) 搜索页位于底部时，无论 normal 或 overlay 键盘模式都由上面的 inset
#    驱动，避免 resize mode 功能开关把键盘高度清零后产生跳位。
sed -i '/^                    public void onConfigurationChanged(Configuration configuration) {$/a\
                        // Alice patch start 0033\
                        // Theme mode changes are configuration events; refresh once here.\
                        mToolbar.onPrimaryColorChanged(/* shouldAnimate= */ false);\
                        // Alice patch end 0033' "$path2"

# 修改对应源码以完成本补丁功能。
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
                \&\& mIsOmniboxFocusedSupplier.get()\
                \&\& !mIsImeAnimationRunning\
                \&\& !mKeyboardVisibilityDelegate.isKeyboardShowing(\
                        mControlContainer.getView())) {\
            layerYOffset = Math.min(layerYOffset, -getNavigationBarHeight());\
        }\
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                \&\& mKeyboardVisibilityDelegate.isKeyboardShowing(\
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
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM) {\
            if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()\
                    || mAliceFullscreenExitMarginHandoffPending) {\
                layerYOffset = 0;\
            } else if (FullscreenManager.FullscreenTransitionState\
                    .isPersistentFullscreen()) {\
                layerYOffset = 0;\
            }\
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
        View aliceChinView =\
                aliceRoot.findViewById(R.id.edge_to_edge_bottom_chin);\
        if (aliceChinView != null \&\& aliceChinView.getHeight() > 0) {\
            return aliceChinView.getHeight();\
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
    private void scheduleAliceNavigationBarBackgroundRetry() {\
        if (mAliceNavigationBarRetryListener != null) return;\
        View aliceToolbarView = mControlContainer.getView();\
        long aliceNow = android.os.SystemClock.uptimeMillis();\
        if (mAliceNavigationBarRetryDeadline == 0) {\
            mAliceNavigationBarRetryDeadline =\
                    aliceNow + ALICE_NAVIGATION_BAR_RETRY_TIMEOUT_MS;\
        }\
        if (!aliceToolbarView.isAttachedToWindow()) {\
            if (aliceNow < mAliceNavigationBarRetryDeadline) {\
                aliceToolbarView.postOnAnimation(\
                        ToolbarPositionController.this::\
                                scheduleAliceNavigationBarBackgroundRetry);\
            } else {\
                mAliceNavigationBarRetryDeadline = 0;\
            }\
            return;\
        }\
        mAliceNavigationBarRetryListener =\
                () -> {\
                    if (getNavigationBarHeight() > 0\
                            \&\& aliceToolbarView.isAttachedToWindow()\
                            \&\& mLayerVisibility != LayerVisibility.HIDDEN) {\
                        if (mNavigationBarBackground != null\
                                \&\& mNavigationBarBackground.getVisibility()\
                                        == View.VISIBLE) {\
                            removeAliceNavigationBarBackgroundRetry();\
                        } else {\
                            aliceToolbarView.postOnAnimation(\
                                    ToolbarPositionController.this::\
                                            updateNavigationBarBackground);\
                        }\
                    } else if (android.os.SystemClock.uptimeMillis()\
                            >= mAliceNavigationBarRetryDeadline) {\
                        removeAliceNavigationBarBackgroundRetry();\
                    }\
                    return true;\
                };\
        ViewTreeObserver aliceObserver = aliceToolbarView.getViewTreeObserver();\
        if (aliceObserver.isAlive()) {\
            aliceObserver.addOnPreDrawListener(mAliceNavigationBarRetryListener);\
        }\
    }\
\
    private void removeAliceNavigationBarBackgroundRetry() {\
        if (mAliceNavigationBarRetryListener == null) return;\
        View aliceToolbarView = mControlContainer.getView();\
        ViewTreeObserver aliceObserver = aliceToolbarView.getViewTreeObserver();\
        if (aliceObserver.isAlive()) {\
            aliceObserver.removeOnPreDrawListener(mAliceNavigationBarRetryListener);\
        }\
        mAliceNavigationBarRetryListener = null;\
        mAliceNavigationBarRetryDeadline = 0;\
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
        if (mNavigationBarBackground == null \&\& aliceNavigationBarHeight <= 0) {\
            scheduleAliceNavigationBarBackgroundRetry();\
            return;\
        }\
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
            ViewGroup aliceOverlayParent = aliceParent;\
            android.widget.FrameLayout aliceBackgroundContainer =\
                    new android.widget.FrameLayout(aliceOverlayParent.getContext());\
            aliceBackgroundContainer.setClickable(false);\
            aliceBackgroundContainer.setFocusable(false);\
            aliceBackgroundContainer.setImportantForAccessibility(\
                    View.IMPORTANT_FOR_ACCESSIBILITY_NO);\
            aliceBackgroundContainer.setTranslationZ(\
                    aliceControlContainer.getTranslationZ());\
            CoordinatorLayout.LayoutParams aliceParams =\
                    new CoordinatorLayout.LayoutParams(\
                            ViewGroup.LayoutParams.MATCH_PARENT,\
                            aliceNavigationBarHeight);\
            aliceParams.gravity = Gravity.BOTTOM;\
            aliceBackgroundContainer.addView(\
                    aliceBackground,\
                    new android.widget.FrameLayout.LayoutParams(\
                            ViewGroup.LayoutParams.MATCH_PARENT,\
                            ViewGroup.LayoutParams.MATCH_PARENT));\
            int aliceIndex = aliceOverlayParent.indexOfChild(aliceControlContainer);\
            if (aliceIndex < 0) {\
                aliceIndex = aliceOverlayParent.getChildCount();\
            } else {\
                aliceIndex++;\
            }\
            aliceOverlayParent.addView(aliceBackgroundContainer, aliceIndex, aliceParams);\
            aliceOverlayParent.setClipChildren(false);\
            aliceOverlayParent.setClipToPadding(false);\
            mNavigationBarBackgroundContainer = aliceBackgroundContainer;\
            mNavigationBarBackground = aliceBackground;\
        }\
\
        View aliceBackground = mNavigationBarBackground;\
        assert aliceBackground != null;\
        ViewGroup aliceBackgroundContainer = mNavigationBarBackgroundContainer;\
        if (aliceBackgroundContainer != null) {\
            ViewGroup.LayoutParams aliceContainerParams =\
                    aliceBackgroundContainer.getLayoutParams();\
            if (aliceContainerParams != null\
                    \&\& aliceContainerParams.height != aliceNavigationBarHeight) {\
                aliceContainerParams.height = aliceNavigationBarHeight;\
                aliceBackgroundContainer.setLayoutParams(aliceContainerParams);\
            }\
            aliceBackgroundContainer.setTranslationZ(\
                    aliceControlContainer.getTranslationZ());\
        }\
        ViewGroup.LayoutParams aliceParams = aliceBackground.getLayoutParams();\
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
        aliceBackground.setAlpha(mAliceTabSwitcherBackgroundAlpha);\
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

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BottomControlsStacker;$/i\
// Alice patch start 0033\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider;\
// Alice patch end 0033' "$path3"

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.ui\.base\.DeviceFormFactor;$/i\
// Alice patch start 0033\
import org.chromium.ui.KeyboardVisibilityDelegate;\
// Alice patch end 0033' "$path3"

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.ui\.base\.DeviceFormFactor;$/a\
// Alice patch start 0033\
import org.chromium.ui.base.WindowAndroid;\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0033' "$path3"

# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0033\
import android.view.ViewGroup;\
import android.view.ViewTreeObserver;\
// Alice patch end 0033' "$path3"

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.components\.browser_ui\.widget\.scrim\.ScrimProperties;$/a\
// Alice patch start 0033\
import org.chromium.components.browser_ui.widget.scrim.ScrimView;\
// Alice patch end 0033' "$path3"

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
sed -i '/^                    mScrimModel\.set(ScrimProperties\.TOP_MARGIN, newHeight);$/c\
                    // Alice patch start 0033\
                    mScrimModel.set(\
                            ScrimProperties.TOP_MARGIN,\
                            isBottomToolbarActive() ? 0 : newHeight);\
                    // Alice patch end 0033' "$path3"

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
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
\
    // Alice patch start 0033\
    private boolean isBottomToolbarActive() {\
        return mBrowserControlsStateProvider != null\
                \&\& mBrowserControlsStateProvider.getControlsPosition()\
                        == BrowserControlsStateProvider.ControlsPosition.BOTTOM;\
    }\
    // Alice patch end 0033\
' "$path3"

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
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

# 修改对应源码以完成本补丁功能。
sed -i '/^        mOmniboxAlignment = omniboxAlignment;$/a\
        // Alice patch start 0033\
        if (mEmbedder != null \&\& mEmbedder.isToolbarOnBottom()) {\
            adjustHorizontalPosition();\
            if (!isWidthDifference) return;\
        }\
        // Alice patch end 0033' "$path5"
