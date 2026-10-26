#!/bin/bash
# 触摸工具栏时预先保存工具栏和导航栏区域，聚焦后再固定显示；弹出输入法
# 时用 IME 动画每一帧的当前 inset 驱动搜索框，并让建议列表止于搜索框
# 上沿。顶部地址栏的搜索页背景和遮罩保持全屏，不随输入法缩短。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarCoordinator.java"
path5="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path6="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListViewBinder.java"

# 检测是否已应用
if grep -q 'Alice patch start 0033' "$path1"; then
    exit 100
fi

# 1) 从根 InsetObserver 接收 IME 动画帧。
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

sed -i '/^        mIsOmniboxFocusedObserver = (focused) -> updateCurrentPosition();$/c\
        // Alice patch start 0033\
        mIsOmniboxFocusedObserver =\
                (focused) -> {\
                    updateCurrentPosition();\
                    updateSearchToolbarSnapshot();\
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
            int aliceNavigationBarHeight =\
                    Math.max(\
                            windowInsetsCompat\
                                    .getInsets(WindowInsetsCompat.Type.navigationBars())\
                                    .bottom,\
                            windowInsetsCompat\
                                    .getInsets(\
                                            WindowInsetsCompat.Type.mandatorySystemGestures())\
                                    .bottom);\
            int aliceBottomInset = Math.max(keyboardHeight, aliceNavigationBarHeight);\
            int maxHeight = windowHeight - aliceBottomInset - statusBarHeight;\
            // Alice patch end 0033' "$path1"

sed -i '/^            int maxTranslation = -(windowHeight - layer\.getHeight() - statusBarHeight);$/c\
            // Alice patch start 0033\
            // Use the animation frame inset as an absolute bottom position.\
            // Alice patch end 0033' "$path1"

sed -i '/^            layerYOffset = Math\.max(layerYOffset - keyboardHeight, maxTranslation);$/c\
            // Alice patch start 0033\
            layerYOffset = -aliceBottomInset;\
            // Alice patch end 0033' "$path1"

# 5) 搜索页位于底部时，无论 normal 或 overlay 键盘模式都由上面的 inset
#    驱动，避免 resize mode 功能开关把键盘高度清零后产生跳位。
sed -i '/^    private boolean shouldIgnoreKeyboardHeightInResizeMode() {$/,/^    }$/c\
    private boolean shouldIgnoreKeyboardHeightInResizeMode() {\
        // Alice patch start 0033\
        return false;\
        // Alice patch end 0033\
    }' "$path1"

# 6) 底置工具栏底部不越过系统导航栏 inset。
sed -i '/^        viewForLayer\.setTranslationY(layerYOffset);$/i\
        // Alice patch start 0033\
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM) {\
            android.view.WindowInsets aliceInsets =\
                    mControlContainer.getView().getRootWindowInsets();\
            if (aliceInsets != null) {\
                WindowInsetsCompat aliceCompatInsets =\
                        WindowInsetsCompat.toWindowInsetsCompat(\
                                aliceInsets,\
                                mControlContainer.getView().getRootView());\
                int aliceNavigationHeight =\
                        Math.max(\
                                aliceCompatInsets\
                                        .getInsets(\
                                                WindowInsetsCompat.Type.navigationBars())\
                                        .bottom,\
                                aliceCompatInsets\
                                        .getInsets(\
                                                WindowInsetsCompat.Type\
                                                        .mandatorySystemGestures())\
                                        .bottom);\
                layerYOffset = Math.min(layerYOffset, -aliceNavigationHeight);\
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
        android.view.WindowInsets aliceInsets = aliceRoot.getRootWindowInsets();\
        if (aliceInsets == null) return 0;\
        WindowInsetsCompat aliceCompatInsets =\
                WindowInsetsCompat.toWindowInsetsCompat(aliceInsets, aliceRoot);\
        return Math.max(\
                aliceCompatInsets\
                        .getInsets(WindowInsetsCompat.Type.navigationBars())\
                        .bottom,\
                aliceCompatInsets\
                        .getInsets(WindowInsetsCompat.Type.mandatorySystemGestures())\
                        .bottom);\
    }\
\
    private void updateNavigationBarBackground() {\
        View aliceControlContainer = mControlContainer.getView();\
        if (!(aliceControlContainer instanceof ViewGroup)) return;\
        ViewGroup aliceContainer = (ViewGroup) aliceControlContainer;\
        CoordinatorLayout.LayoutParams aliceToolbarParams =\
                mControlContainer.mutateToolbarLayoutParams();\
        int aliceToolbarTopMargin = 0;\
        if (mCurrentPosition.get() == ControlsPosition.BOTTOM\
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
            android.widget.FrameLayout.LayoutParams aliceParams =\
                    new android.widget.FrameLayout.LayoutParams(\
                            ViewGroup.LayoutParams.MATCH_PARENT,\
                            aliceNavigationBarHeight);\
            aliceParams.gravity = Gravity.BOTTOM;\
            aliceContainer.addView(aliceBackground, 0, aliceParams);\
            aliceContainer.setClipChildren(false);\
            aliceContainer.setClipToPadding(false);\
            mNavigationBarBackground = aliceBackground;\
        }\
\
        View aliceBackground = mNavigationBarBackground;\
        assert aliceBackground != null;\
        android.widget.FrameLayout.LayoutParams aliceParams =\
                (android.widget.FrameLayout.LayoutParams) aliceBackground.getLayoutParams();\
        if (aliceParams.height != aliceNavigationBarHeight) {\
            aliceParams.height = aliceNavigationBarHeight;\
            aliceBackground.setLayoutParams(aliceParams);\
        }\
        aliceBackground.setTranslationY(aliceNavigationBarHeight);\
        aliceBackground.setBackgroundColor(mControlContainer.getToolbarBackgroundColor());\
        boolean aliceSearchImeActive =\
                mIsOmniboxFocusedSupplier.get()\
                        \&\& (mIsImeAnimationRunning\
                                || mKeyboardVisibilityDelegate.isKeyboardShowing(\
                                        aliceControlContainer));\
        boolean aliceVisible =\
                mCurrentPosition.get() == ControlsPosition.BOTTOM\
                        \&\& mLayerVisibility != LayerVisibility.HIDDEN\
                        \&\& !aliceSearchImeActive\
                        \&\& aliceNavigationBarHeight > 0;\
        aliceBackground.setVisibility(aliceVisible ? View.VISIBLE : View.INVISIBLE);\
        updateSearchToolbarSnapshot();\
    }\
\
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
        aliceSnapshot.setVisibility(\
                mIsOmniboxFocusedSupplier.get() ? View.VISIBLE : View.INVISIBLE);\
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
        if (mSearchToolbarSnapshot != null) {\
            mSearchToolbarSnapshot.setTranslationY(0);\
            moveSearchToolbarSnapshotBelowScrim();\
            mSearchToolbarSnapshot.setVisibility(View.VISIBLE);\
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
        ViewGroup.LayoutParams aliceParams = aliceSnapshot.getLayoutParams();\
        aliceParent.removeView(aliceSnapshot);\
        aliceParent.addView(aliceSnapshot, aliceScrimIndex, aliceParams);\
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

# 10) 底置工具栏时，建议列表的实际测量高度止于搜索框上沿。保留原有
#     动画位移，只在测量阶段限制边界。
sed -i '/^import android\.content\.Context;$/a\
// Alice patch start 0033\
import android.graphics.Rect;\
// Alice patch end 0033' "$path5"

sed -i '/^    private final int\[\] mStickPosition = new int\[2\];$/a\
    // Alice patch start 0033\
    private final Rect mSearchClipBounds = new Rect();\
    private int mLastSearchDropdownHeight = -1;\
    private int mLastSearchClipBottom = -1;\
    private int mLastSearchTranslationY;\
    // Alice patch end 0033' "$path5"

sed -i '/^    private boolean stickToAnchor() {$/,/^    }$/c\
    // Alice patch start 0033\
    private boolean stickToAnchor() {\
        if (mDropdown == null) return true;\
        setTranslationY(0);\
        if (mEmbedder == null || !mEmbedder.isToolbarOnBottom()) {\
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
            mLastSearchClipBottom = -1;\
            mLastSearchTranslationY = 0;\
            mDropdown.setTranslationY(0);\
            return true;\
        }\
        ViewGroup.LayoutParams aliceDropdownParams = mDropdown.getLayoutParams();\
        if (aliceDropdownParams.height != ViewGroup.LayoutParams.WRAP_CONTENT) {\
            aliceDropdownParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;\
            mDropdown.setLayoutParams(aliceDropdownParams);\
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
        int aliceClipBottom = Math.max(0, aliceTargetTop - aliceContainerTop);\
        mSearchClipBounds.set(\
                0,\
                0,\
                getWidth(),\
                aliceClipBottom);\
        setClipBounds(mSearchClipBounds);\
        int aliceDropdownHeight = mDropdown.getHeight();\
        if (aliceDropdownHeight > 0) {\
            mLastSearchDropdownHeight = aliceDropdownHeight;\
        }\
        int aliceTranslationY =\
                mLastSearchDropdownHeight > 0\
                        ? Math.max(\
                                0,\
                                aliceClipBottom - mLastSearchDropdownHeight)\
                        : mLastSearchTranslationY;\
        if (mLastSearchClipBottom >= 0) {\
            if (aliceClipBottom > mLastSearchClipBottom) {\
                aliceTranslationY =\
                        Math.max(aliceTranslationY, mLastSearchTranslationY);\
            } else if (aliceClipBottom < mLastSearchClipBottom) {\
                aliceTranslationY =\
                        Math.min(aliceTranslationY, mLastSearchTranslationY);\
            } else {\
                aliceTranslationY =\
                        Math.max(aliceTranslationY, mLastSearchTranslationY);\
            }\
        }\
        mLastSearchClipBottom = aliceClipBottom;\
        mLastSearchTranslationY = aliceTranslationY;\
        mDropdown.setTranslationY(aliceTranslationY);\
        return true;\
    }\
    // Alice patch end 0033' "$path5"

sed -i '/^            int availableViewportHeight = mOmniboxAlignment\.height;$/c\
            // Alice patch start 0033\
            int availableViewportHeight = mOmniboxAlignment.height;\
            if (mEmbedder != null) {\
                int aliceRootHeight = getRootView().getHeight();\
                int aliceTopMargin = Math.max(0, mOmniboxAlignment.top);\
                int aliceFullHeight = aliceRootHeight - aliceTopMargin;\
                if (aliceFullHeight > 0) {\
                    availableViewportHeight = aliceFullHeight;\
                }\
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

# 12) 全屏时隐藏 compositor 工具栏层，避免底置工具栏残留在视频画面上。
sed -i 's@^                mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow || mIsUrlBarFocusedForSceneLayer);$@                mIsXrFsm\n                        || mIsVerticalTabsHiddenDueToNarrow\n                        || mIsUrlBarFocusedForSceneLayer\n                        || mFullscreenManager.getPersistentFullscreenMode()\n                        || mInTabSwitcherTransition\n                        || (mLayoutStateProvider != null\n                                \&\& mLayoutStateProvider.getActiveLayoutType() == LayoutType.HUB));@' "$path2"

sed -i '/^                        mToolbar\.onTransitionEnd();$/a\
                        // Alice patch start 0033\
                        updateToolbarSceneLayerSuppression();\
                        // Alice patch end 0033' "$path2"

sed -i '/^        mToolbar\.setContentAttached(layoutType == LayoutType\.BROWSING);$/a\
        // Alice patch start 0033\
        updateToolbarSceneLayerSuppression();\
        // Alice patch end 0033' "$path2"

# 进入全屏后立即刷新场景层抑制状态。
sed -i '/^                                        false, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0033\
                        updateToolbarSceneLayerSuppression();\
                        // Alice patch end 0033' "$path2"

# 退出全屏后先应用最新系统栏 inset 并重排底部控件，再恢复工具栏场景层。
# 否则场景层会沿用全屏时的底部位置，直到旋转结束重新布局才避让导航栏。
sed -i '/^                                        true, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0033\
                        refreshToolbarAfterFullscreen();\
                        // Alice patch end 0033' "$path2"

sed -i '/^    private void updateToolbarSceneLayerSuppression() {$/i\
    // Alice patch start 0033\
    private void refreshToolbarAfterFullscreen() {\
        View aliceControlContainer = mControlContainer.getView();\
        aliceControlContainer.postOnAnimation(\
                () -> {\
                    aliceControlContainer.requestApplyInsets();\
                    aliceControlContainer.requestLayout();\
                    mBottomControlsStacker.requestLayerUpdate(false);\
                    aliceControlContainer.postOnAnimation(\
                            ToolbarManager.this::updateToolbarSceneLayerSuppression);\
                });\
    }\
    // Alice patch end 0033\
' "$path2"
