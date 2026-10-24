#!/bin/bash
# 撤销 Snackbar 与翻译气泡避让系统导航栏

set -e

# 目标文件路径
path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ui/RootUiCoordinator.java"
path4="ui/android/java/src/org/chromium/ui/insets/InsetObserver.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedNavigationBarColorController.java"
path6="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerImpl.java"
path7="content/public/android/java/src/org/chromium/content/browser/input/ImeAdapterImpl.java"
path10="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"

# 检测是否已应用
if grep -q 'Alice patch start 0034' "$path1"; then
    exit 100
fi

# 1) SnackbarView 已经使用 ViewCompat，补充 WindowInsetsCompat 类型
sed -i '/^import androidx\.core\.view\.ViewCompat;$/a\
// Alice patch start 0034\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0034' "$path1"

# 2) Snackbar 的底部边距同时考虑键盘和导航栏。
#    键盘可见时取两者较大值，避免重复叠加导航栏高度。
sed -i '/^    void adjustViewPosition() {$/i\
    // Alice patch start 0034\
    private int getAliceNavigationBarHeight() {\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(mRootContentView);\
        if (insets == null) return 0;\
        int navigationBarHeight =\
                insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom;\
        int mandatoryGestureHeight =\
                insets.getInsets(WindowInsetsCompat.Type.mandatorySystemGestures()).bottom;\
        int tappableElementHeight =\
                insets.getInsets(WindowInsetsCompat.Type.tappableElement()).bottom;\
        return Math.max(\
                navigationBarHeight, Math.max(mandatoryGestureHeight, tappableElementHeight));\
    }\
    // Alice patch end 0034\
' "$path1"

sed -i '/^        int targetBottomMargin =$/,/^                mDefaultBottomMargin + mAdditionalBottomMarginPxSupplier\.get() + keyboardHeight;$/c\
        // Alice patch start 0034\
        int aliceBottomMargin = mDefaultBottomMargin;\
        boolean aliceImeShowing =\
                KeyboardVisibilityDelegate.getInstance()\
                                .isKeyboardShowing(mContainerView)\
                        || KeyboardVisibilityDelegate.getInstance()\
                                        .calculateTotalKeyboardHeight(mRootContentView)\
                                > 0;\
        int aliceNavigationBarHeight = getAliceNavigationBarHeight();\
        if (aliceImeShowing) {\
            int aliceImeHeight = keyboardHeight;\
            if (aliceImeHeight == 0) {\
                aliceImeHeight =\
                        KeyboardVisibilityDelegate.getInstance()\
                                .calculateTotalKeyboardHeight(mRootContentView);\
            }\
            aliceBottomMargin +=\
                    Math.max(aliceImeHeight, aliceNavigationBarHeight);\
        } else {\
            aliceBottomMargin +=\
                    mAdditionalBottomMarginPxSupplier.get()\
                            + aliceNavigationBarHeight;\
        }\
        int targetBottomMargin = aliceBottomMargin;\
        // Alice patch end 0034' "$path1"

# 3) 翻译气泡的 MessageContainerCoordinator 补充 imports
sed -i '/^import android\.content\.res\.Resources;$/a\
// Alice patch start 0034\
import android.app.Activity;\
// Alice patch end 0034' "$path2"

sed -i '/^import android\.view\.ViewGroup;$/a\
\
// Alice patch start 0034\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0034' "$path2"

sed -i '/^import org\.chromium\.components\.messages\.MessageContainer;$/a\
// Alice patch start 0034\
import org.chromium.ui.KeyboardVisibilityDelegate;\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0034' "$path2"

sed -i '/^import org\.chromium\.chrome\.browser\.fullscreen\.BrowserControlsManager;$/a\
// Alice patch start 0034\
import org.chromium.chrome.browser.init.AsyncInitializationActivity;\
// Alice patch end 0034' "$path2"

sed -i '/^import org\.chromium\.ui\.base\.ViewUtils;$/c\
// Alice patch start 0034\
import java.util.List;\
// Alice patch end 0034\
// Alice patch start 0034\
// Removed unused ViewUtils import.\
// Alice patch end 0034' "$path2"

sed -i '/^public class MessageContainerCoordinator implements BrowserControlsStateProvider\.Observer {$/a\
    // Alice patch start 0034\
    private final KeyboardVisibilityDelegate.KeyboardVisibilityListener\
            mAliceKeyboardVisibilityListener;\
    // Alice patch end 0034\
' "$path2"

sed -i '/^        mContainer = container;$/a\
        // Alice patch start 0034\
        mAliceKeyboardVisibilityListener =\
                (isShowing) -> {\
                    if (mContainer != null) updateMargins();\
                };\
        KeyboardVisibilityDelegate.getInstance()\
                .addKeyboardVisibilityListener(mAliceKeyboardVisibilityListener);\
        // Alice patch end 0034\
' "$path2"

sed -i '/^        mControlsManager\.removeObserver(this);$/a\
        // Alice patch start 0034\
        KeyboardVisibilityDelegate.getInstance()\
                .removeKeyboardVisibilityListener(mAliceKeyboardVisibilityListener);\
        // Alice patch end 0034\
' "$path2"

sed -i '/^    public void onAnimationStart() {$/,/^    }$/c\
    public void onAnimationStart() {\
        // Alice patch start 0034\
        // Snackbar animation is updated from the IME animation listener.\
        // Alice patch end 0034\
    }' "$path2"

sed -i '/^    public void onAnimationEnd() {$/,/^    }$/c\
    public void onAnimationEnd() {\
        // Alice patch start 0034\
        // Snackbar animation is updated from the IME animation listener.\
        // Alice patch end 0034\
    }' "$path2"

# 4) 在 0014 已有的工具栏底部留白之上，再增加导航栏高度。
#    优先使用 edge_to_edge_bottom_chin 的实际高度，因为 edge-to-edge 会消费
#    navigationBars inset。键盘可见时父容器已经缩到键盘上方，不再叠加
#    toolbar/nav 高度，避免气泡离输入法太远。
sed -i '/^        params\.bottomMargin =$/,/^                        res\.getDimensionPixelOffset(R\.dimen\.toolbar_height_no_shadow));$/c\
        // Alice patch start 0034\
        int aliceNavigationBarHeight = 0;\
        if (mContainer.getContext() instanceof Activity) {\
            View chin =\
                    ((Activity) mContainer.getContext())\
                            .findViewById(R.id.edge_to_edge_bottom_chin);\
            if (chin != null) aliceNavigationBarHeight = chin.getHeight();\
        }\
        WindowInsetsCompat aliceInsets = ViewCompat.getRootWindowInsets(mContainer);\
        if (aliceNavigationBarHeight == 0 && aliceInsets != null) {\
            aliceNavigationBarHeight =\
                    aliceInsets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom;\
        }\
        int aliceBottomMargin =\
                Math.max(\
                        getContainerTopOffset(),\
                        res.getDimensionPixelOffset(R.dimen.toolbar_height_no_shadow));\
        boolean aliceImeShowing =\
                aliceInsets != null\
                        && aliceInsets.isVisible(WindowInsetsCompat.Type.ime());\
        if (!aliceImeShowing) {\
            KeyboardVisibilityDelegate keyboardDelegate =\
                    KeyboardVisibilityDelegate.getInstance();\
            aliceImeShowing =\
                    keyboardDelegate.isKeyboardShowing(mContainer)\
                            || keyboardDelegate.calculateTotalKeyboardHeight(mContainer) > 0;\
        }\
        if (aliceImeShowing) {\
            int aliceImeHeight =\
                    aliceInsets != null\
                            ? aliceInsets.getInsets(WindowInsetsCompat.Type.ime()).bottom\
                            : 0;\
            if (aliceImeHeight == 0) {\
                aliceImeHeight =\
                        KeyboardVisibilityDelegate.getInstance()\
                                .calculateTotalKeyboardHeight(mContainer);\
            }\
            aliceBottomMargin =\
                    Math.max(\
                            Math.round(2f * res.getDisplayMetrics().density),\
                            aliceImeHeight);\
        } else {\
            aliceBottomMargin += aliceNavigationBarHeight;\
        }\
        params.bottomMargin = aliceBottomMargin;\
        // Alice patch end 0034' "$path2"

sed -i '/^import org\.chromium\.components\.messages\.MessageContainer;$/a\
// Alice patch start 0034\
import org.chromium.ui.KeyboardVisibilityDelegate;\
// Alice patch end 0034' "$path3"

sed -i '/^                        mWindowAndroid::startAnimationOverContent,$/c\
                        // Alice patch start 0034\
                        animator -> {\
                            KeyboardVisibilityDelegate keyboardDelegate =\
                                    KeyboardVisibilityDelegate.getInstance();\
                            if (keyboardDelegate.isKeyboardShowing(container)\
                                    || keyboardDelegate.calculateTotalKeyboardHeight(container)\
                                            > 0) {\
                                animator.start();\
                            } else {\
                                mWindowAndroid.startAnimationOverContent(animator);\
                            }\
                        },\
                        // Alice patch end 0034' "$path3"

# 6) 底置工具栏本来就在导航栏区域绘制相同背景。把系统导航栏也固定成
#    该颜色，避免 IME 动画第一帧早于 inset 回调时露出系统黑色默认底。
sed -i '/^    private @ColorInt int getNavigationBarIconColor() {$/i\
    // Alice patch start 0034\
    private @ColorInt int getAliceEdgeNavigationBarColor() {\
        if (mToolbarColorSupplier != null) {\
            int toolbarColor = mToolbarColorSupplier.get();\
            if (toolbarColor != 0) return toolbarColor;\
        }\
        if (mBottomAttachedUiColor != null) return mBottomAttachedUiColor;\
        if (mActiveTab != null) return mActiveTab.getBackgroundColor();\
        return SemanticColorUtils.getColorSurface(mContext);\
    }\
    // Alice patch end 0034\
' "$path5"

sed -i '/^    private @ColorInt int getNavigationBarColor(boolean forceDarkNavigationBar) {$/a\
        // Alice patch start 0034\
        if (isDrawingToEdge() && isBottomToolbar()) {\
            return getAliceEdgeNavigationBarColor();\
        }\
        // Alice patch end 0034' "$path5"
sed -i '/^    int getNavigationBarDividerColor(boolean forceDarkNavigationBar, boolean forceShowDivider) {$/a\
        // Alice patch start 0034\
        if (isDrawingToEdge() && isBottomToolbar()) {\
            return getAliceEdgeNavigationBarColor();\
        }\
        // Alice patch end 0034' "$path5"

# 7) Snackbar 直接监听 InsetObserver 的 IME 动画，逐帧更新位置。
#    根 View 的动画派发模式是 DISPATCH_MODE_STOP，子 View 回调收不到。
sed -i '/^import org\.chromium\.ui\.util\.MotionEventUtils;$/a\
\
// Alice patch start 0034\
import java.util.List;\
// Alice patch end 0034' "$path1"

sed -i '/^    private boolean mIsAnimating;$/a\
    // Alice patch start 0034\
    private @Nullable InsetObserver mAliceInsetObserver;\
    private int mAliceImeAnimationHeight = -1;\
    private boolean mAliceImeAnimationInProgress;\
    private final InsetObserver.WindowInsetsAnimationListener mAliceImeAnimationListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {}\
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
                    if (mSnackbar == null) return;\
                    mAliceImeAnimationInProgress = true;\
                    mAliceImeAnimationHeight =\
                            insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;\
                    adjustViewPosition();\
                }\
\
                @Override\
                public void onEnd(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                        return;\
                    }\
                    mAliceImeAnimationInProgress = false;\
                    mAliceImeAnimationHeight = -1;\
                    if (mSnackbar != null) adjustViewPosition();\
                }\
            };\
    // Alice patch end 0034' "$path1"

sed -i '/^        mRootContentView = activity\.findViewById(android\.R\.id\.content);$/a\
        // Alice patch start 0034\
        if (mWindowAndroid != null) {\
            mAliceInsetObserver = mWindowAndroid.getInsetObserver();\
            if (mAliceInsetObserver != null) {\
                mAliceInsetObserver.addWindowInsetsAnimationListener(\
                        mAliceImeAnimationListener);\
            }\
        }\
        // Alice patch end 0034' "$path1"

sed -i '/^    public void dismiss() {$/a\
        // Alice patch start 0034\
        if (mAliceInsetObserver != null) {\
            mAliceInsetObserver.removeWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
            mAliceInsetObserver = null;\
        }\
        // Alice patch end 0034' "$path1"

sed -i 's@^        boolean aliceImeShowing =$@        boolean aliceImeShowing = mAliceImeAnimationHeight >= 0 ||@' "$path1"
sed -i '/^            int aliceImeHeight = keyboardHeight;$/c\
            int aliceImeHeight =\
                    mAliceImeAnimationHeight >= 0\
                            ? mAliceImeAnimationHeight\
                            : keyboardHeight;' "$path1"

# 8) 翻译气泡直接监听同一个 InsetObserver 动画源。

sed -i '/^    private @Nullable MessageContainer mContainer;$/a\
    // Alice patch start 0034\
    private @Nullable InsetObserver mAliceInsetObserver;\
    private int mAliceImeAnimationHeight = -1;\
    private boolean mAliceImeAnimationInProgress;\
    private final InsetObserver.WindowInsetsAnimationListener mAliceImeAnimationListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {}\
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
                    mAliceImeAnimationInProgress = true;\
                    mAliceImeAnimationHeight =\
                            insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;\
                    if (mContainer != null) updateMargins();\
                }\
\
                @Override\
                public void onEnd(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                        return;\
                    }\
                    mAliceImeAnimationInProgress = false;\
                    mAliceImeAnimationHeight = -1;\
                    if (mContainer != null) updateMargins();\
                }\
            };\
    // Alice patch end 0034' "$path2"

sed -i '/^        mContainer = container;$/a\
        // Alice patch start 0034\
        if (mContainer.getContext() instanceof AsyncInitializationActivity) {\
            AsyncInitializationActivity activity =\
                    (AsyncInitializationActivity) mContainer.getContext();\
            if (activity.getWindowAndroid() != null) {\
                mAliceInsetObserver = activity.getWindowAndroid().getInsetObserver();\
                if (mAliceInsetObserver != null) {\
                    mAliceInsetObserver.addWindowInsetsAnimationListener(\
                            mAliceImeAnimationListener);\
                }\
            }\
        }\
        // Alice patch end 0034' "$path2"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0034\
        if (mAliceInsetObserver != null) {\
            mAliceInsetObserver.removeWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
            mAliceInsetObserver = null;\
        }\
        // Alice patch end 0034' "$path2"

sed -i 's@^        boolean aliceImeShowing =$@        boolean aliceImeShowing = mAliceImeAnimationHeight >= 0 ||@' "$path2"
sed -i '/^            if (aliceImeHeight == 0) {$/i\
            if (mAliceImeAnimationHeight >= 0) {\
                aliceImeHeight = mAliceImeAnimationHeight;\
            }' "$path2"

# 9) 动画准备阶段先停在上一帧高度，避免在 onProgress 前闪到最终位置；
#    同时把动画中的底部边距钳制到键盘收起后的稳定高度。
sed -i '/^                public void onPrepare(WindowInsetsAnimationCompat animation) {}$/c\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                        return;\
                    }\
                    mAliceImeAnimationInProgress = true;\
                    mAliceImeAnimationHeight = -1;\
                }' "$path1"
sed -i '/^                public void onPrepare(WindowInsetsAnimationCompat animation) {}$/c\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                        return;\
                    }\
                    mAliceImeAnimationInProgress = true;\
                    mAliceImeAnimationHeight = -1;\
                }' "$path2"

sed -i '/^        int aliceBottomMargin = mDefaultBottomMargin;$/,/^        int targetBottomMargin = aliceBottomMargin;$/c\
        // Alice patch start 0034\
        boolean aliceImeShowing = mAliceImeAnimationInProgress ||\
                KeyboardVisibilityDelegate.getInstance()\
                                .isKeyboardShowing(mContainerView)\
                        || KeyboardVisibilityDelegate.getInstance()\
                                        .calculateTotalKeyboardHeight(mRootContentView)\
                                > 0;\
        int aliceNavigationBarHeight = getAliceNavigationBarHeight();\
        int aliceImeHeight = mAliceImeAnimationInProgress\
                ? Math.max(0, mAliceImeAnimationHeight)\
                : KeyboardVisibilityDelegate.getInstance()\
                        .calculateTotalKeyboardHeight(mRootContentView);\
        int aliceRestingBottomMargin =\
                mDefaultBottomMargin\
                        + mAdditionalBottomMarginPxSupplier.get()\
                        + aliceNavigationBarHeight;\
        int aliceBottomMargin =\
                aliceImeShowing\
                        ? Math.max(aliceRestingBottomMargin, aliceImeHeight)\
                        : aliceRestingBottomMargin;\
        int targetBottomMargin = aliceBottomMargin;\
        // Alice patch end 0034' "$path1"

sed -i '/^        int aliceNavigationBarHeight = 0;$/,/^        params.bottomMargin = aliceBottomMargin;$/c\
        // Alice patch start 0034\
        int aliceNavigationBarHeight = 0;\
        if (mContainer.getContext() instanceof Activity) {\
            View chin =\
                    ((Activity) mContainer.getContext())\
                            .findViewById(R.id.edge_to_edge_bottom_chin);\
            if (chin != null) aliceNavigationBarHeight = chin.getHeight();\
        }\
        WindowInsetsCompat aliceInsets = ViewCompat.getRootWindowInsets(mContainer);\
        if (aliceNavigationBarHeight == 0 && aliceInsets != null) {\
            aliceNavigationBarHeight =\
                    aliceInsets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom;\
        }\
        int aliceToolbarBottomMargin =\
                Math.max(\
                        getContainerTopOffset(),\
                        res.getDimensionPixelOffset(R.dimen.toolbar_height_no_shadow));\
        int aliceRestingBottomMargin = aliceToolbarBottomMargin + aliceNavigationBarHeight;\
        boolean aliceImeShowing = mAliceImeAnimationInProgress ||\
                (aliceInsets != null\
                        && aliceInsets.isVisible(WindowInsetsCompat.Type.ime()))\
                || KeyboardVisibilityDelegate.getInstance().isKeyboardShowing(mContainer)\
                || KeyboardVisibilityDelegate.getInstance()\
                                .calculateTotalKeyboardHeight(mContainer)\
                        > 0;\
        int aliceImeHeight = mAliceImeAnimationInProgress\
                ? Math.max(0, mAliceImeAnimationHeight)\
                : (aliceInsets != null\
                        ? aliceInsets.getInsets(WindowInsetsCompat.Type.ime()).bottom\
                        : 0);\
        if (aliceImeShowing && aliceImeHeight == 0) {\
            aliceImeHeight =\
                    KeyboardVisibilityDelegate.getInstance()\
                            .calculateTotalKeyboardHeight(mContainer);\
        }\
        int aliceBottomMargin =\
                aliceImeShowing\
                        ? Math.max(aliceRestingBottomMargin, aliceImeHeight)\
                        : aliceRestingBottomMargin;\
        params.bottomMargin = aliceBottomMargin;\
        // Alice patch end 0034' "$path2"
# 10) 把 IME 动画状态保存在 InsetObserver，供动画开始后才创建的
#     气泡读取，避免它们错过 onPrepare 后直接用最终 inset 定位。
sed -i '/^    private boolean mIsKeyboardInOverlayMode;$/a\
    // Alice patch start 0034\
    private boolean mIsImeAnimationInProgress;\
    private int mCurrentImeAnimationHeight = -1;\
    // Alice patch end 0034' "$path4"

sed -i '/^                    public void onPrepare(WindowInsetsAnimationCompat animation) {$/a\
                        // Alice patch start 0034\
                        if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) != 0) {\
                            mIsImeAnimationInProgress = true;\
                            mCurrentImeAnimationHeight = -1;\
                        }\
                        // Alice patch end 0034' "$path4"

sed -i '/^                    public WindowInsetsCompat onProgress($/,/^                        for (WindowInsetsAnimationListener listener :$/c\
                    public WindowInsetsCompat onProgress(\
                            WindowInsetsCompat windowInsetsCompat,\
                            List<WindowInsetsAnimationCompat> list) {\
                        // Alice patch start 0034\
                        if (mIsImeAnimationInProgress) {\
                            mCurrentImeAnimationHeight =\
                                    windowInsetsCompat.getInsets(ime()).bottom;\
                        }\
                        // Alice patch end 0034\
                        for (WindowInsetsAnimationListener listener :' "$path4"

sed -i '/^                    public void onEnd(WindowInsetsAnimationCompat animation) {$/a\
                        // Alice patch start 0034\
                        if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) != 0) {\
                            mIsImeAnimationInProgress = false;\
                            mCurrentImeAnimationHeight = -1;\
                        }\
                        // Alice patch end 0034' "$path4"

sed -i '/^    public boolean isKeyboardInOverlayMode() {$/i\
    // Alice patch start 0034\
    public boolean isImeAnimationInProgress() {\
        return mIsImeAnimationInProgress;\
    }\
\
    public int getCurrentImeAnimationHeight() {\
        return mCurrentImeAnimationHeight;\
    }\
    // Alice patch end 0034\
' "$path4"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/i\
        // Alice patch start 0034\
        if (mAliceInsetObserver != null\
                && mAliceInsetObserver.isImeAnimationInProgress()) {\
            mAliceImeAnimationInProgress = true;\
            int aliceGlobalImeAnimationHeight =\
                    mAliceInsetObserver.getCurrentImeAnimationHeight();\
            if (aliceGlobalImeAnimationHeight >= 0) {\
                mAliceImeAnimationHeight = aliceGlobalImeAnimationHeight;\
            }\
        }\
        // Alice patch end 0034' "$path1"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/i\
        // Alice patch start 0034\
        if (mAliceInsetObserver != null\
                && mAliceInsetObserver.isImeAnimationInProgress()) {\
            mAliceImeAnimationInProgress = true;\
            int aliceGlobalImeAnimationHeight =\
                    mAliceInsetObserver.getCurrentImeAnimationHeight();\
            if (aliceGlobalImeAnimationHeight >= 0) {\
                mAliceImeAnimationHeight = aliceGlobalImeAnimationHeight;\
            }\
        }\
        // Alice patch end 0034' "$path2"
# 11) 非动画帧也使用 InsetObserver 保存的稳定 IME 高度，绝不直接读
#     系统刚下发的最终 inset。动画结束后再把稳定高度更新为最终值。
sed -i '/^    private int mCurrentImeAnimationHeight = -1;$/c\
    private int mCurrentImeAnimationHeight;' "$path4"

sed -i '/^[[:space:]]*mCurrentImeAnimationHeight = -1;$/d' "$path4"

sed -i '/^[[:space:]]*mIsImeAnimationInProgress = false;$/c\
                        mIsImeAnimationInProgress = false;\
                        mCurrentImeAnimationHeight = mLastSeenRawWindowInset != null ? mLastSeenRawWindowInset.getInsets(ime()).bottom : -1;' "$path4"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/a\
                (mAliceInsetObserver != null\
                                && mAliceInsetObserver.getCurrentImeAnimationHeight() > 0)\
                        ||' "$path1"
sed -i '/^        int aliceImeHeight = aliceImeAnimating$/,/^        int aliceRestingBottomMargin =$/c\
        int aliceImeHeight =\
                aliceImeAnimating\
                        ? Math.max(0, aliceEffectiveImeAnimationHeight)\
                        : Math.max(\
                                0,\
                                mAliceInsetObserver != null\
                                        ? mAliceInsetObserver\
                                                .getCurrentImeAnimationHeight()\
                                        : 0);\
        int aliceRestingBottomMargin =' "$path1"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/a\
                (mAliceInsetObserver != null\
                                && mAliceInsetObserver.getCurrentImeAnimationHeight() > 0)\
                        ||' "$path2"
sed -i '/^        int aliceImeHeight = aliceImeAnimating$/,/^        int aliceRestingBottomMargin = aliceToolbarBottomMargin + aliceNavigationBarHeight;$/c\
        int aliceImeHeight =\
                aliceImeAnimating\
                        ? Math.max(0, aliceEffectiveImeAnimationHeight)\
                        : Math.max(\
                                0,\
                                mAliceInsetObserver != null\
                                        ? mAliceInsetObserver\
                                                .getCurrentImeAnimationHeight()\
                                        : 0);\
        int aliceRestingBottomMargin = aliceToolbarBottomMargin + aliceNavigationBarHeight;' "$path2"

# 12) 气泡首次显示前先完成定位，避免旧布局位置先绘制一帧。
sed -i '/^    public void show() {$/a\
        // Alice patch start 0034\
        mContainerView.setVisibility(View.INVISIBLE);\
        // Alice patch end 0034' "$path1"
sed -i '/^        addToParent();$/a\
        // Alice patch start 0034\
        adjustViewPosition();\
        // Alice patch end 0034' "$path1"
sed -i '/^                        mContainerView.removeOnLayoutChangeListener(this);$/a\
                        // Alice patch start 0034\
                        adjustViewPosition();\
                        mContainerView.setVisibility(View.VISIBLE);\
                        // Alice patch end 0034' "$path1"

sed -i '/^    protected void showMessageContainer() {$/,/^    }$/c\
    protected void showMessageContainer() {\
        // Alice patch start 0034\
        assert mContainer != null;\
        mContainer.setVisibility(View.INVISIBLE);\
        updateMargins();\
        mContainer.addOnLayoutChangeListener(\
                new View.OnLayoutChangeListener() {\
                    @Override\
                    public void onLayoutChange(\
                            View v,\
                            int left,\
                            int top,\
                            int right,\
                            int bottom,\
                            int oldLeft,\
                            int oldTop,\
                            int oldRight,\
                            int oldBottom) {\
                        if (mContainer == null) return;\
                        mContainer.removeOnLayoutChangeListener(this);\
\
                        Rect rect = new Rect();\
                        mContainer.getGlobalVisibleRect(rect);\
                        int viewId = mContainer.getId();\
                        for (MessageContainerObserver o : mObservers) {\
                            o.onShowMessageContainer(viewId, rect);\
                        }\
                    }\
                });\
        mContainer.post(\
                () -> {\
                    if (mContainer != null) mContainer.setVisibility(View.VISIBLE);\
                });\
        // Alice patch end 0034\
    }' "$path2"
# 13) 所有气泡高度分支统一读取稳定 IME 高度，禁止回退到最终 raw inset。
sed -i '/^        int aliceImeHeight = mAliceImeAnimationInProgress$/,/^        int aliceRestingBottomMargin =$/c\
        int aliceImeHeight =\
                mAliceImeAnimationInProgress\
                        ? Math.max(0, mAliceImeAnimationHeight)\
                        : Math.max(\
                                0,\
                                mAliceInsetObserver != null\
                                        ? mAliceInsetObserver\
                                                .getCurrentImeAnimationHeight()\
                                        : 0);\
        int aliceRestingBottomMargin =' "$path1"

sed -i '/^        int aliceImeHeight = mAliceImeAnimationInProgress$/,/^        int aliceBottomMargin =$/c\
        int aliceImeHeight =\
                mAliceImeAnimationInProgress\
                        ? Math.max(0, mAliceImeAnimationHeight)\
                        : Math.max(\
                                0,\
                                mAliceInsetObserver != null\
                                        ? mAliceInsetObserver\
                                                .getCurrentImeAnimationHeight()\
                                        : 0);\
        int aliceBottomMargin =' "$path2"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/i\
        // Alice patch start 0034' "$path1"
sed -i '/^        int targetBottomMargin = aliceBottomMargin;$/a\
        // Alice patch end 0034' "$path1"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/i\
        // Alice patch start 0034' "$path2"
sed -i '/^        params.bottomMargin = aliceBottomMargin;$/a\
        // Alice patch end 0034' "$path2"

# 14) ChromeTabbedActivity 已经使用 SOFT_INPUT_ADJUST_RESIZE。Edge-to-Edge
#     不能再把 keyboard height 加到 content padding，否则会产生二次位移。
sed -i '/^        if (mKeyboardInsets != null && mKeyboardInsets\.bottom > bottomPadding) {$/,/^        }$/c\
        // Alice patch start 0034\
        // ADJUST_RESIZE already accounts for the keyboard. Do not add its height\
        // to content padding a second time.\
        // Alice patch end 0034' "$path6"

# 15) 软件键盘漏掉 onResizeScrollableViewport 时，焦点输入框不会滚入可视区。
#     RESULT_SHOWN 后再做一次延迟滚动，触摸导致失焦时会由现有清空逻辑取消。
sed -i '/^            containerView\.getWindowVisibleDisplayFrame(mFocusPreOSKViewportRect);$/a\
            // Alice patch start 0034\
            containerView.postDelayed(\
                    () -> {\
                        if (!isValid() || !ViewUtils.hasFocus(containerView)) return;\
                        mWebContents.scrollFocusedEditableNodeIntoView();\
                    },\
                    300);\
            // Alice patch end 0034' "$path7"

# 16) 键盘可见时底部工具栏已被 IME 覆盖，不再从 WebContents 高度中扣除
#     工具栏高度，否则 visual viewport 会在键盘上方提前结束一个工具栏高度。
sed -i '/^        int verticalViewportInsets =$/,/^                                + mAliceNavigationBarInset;$/c\
        // Alice patch start 0034\
        boolean aliceKeyboardShowing =\
                KeyboardVisibilityDelegate.getInstance().isKeyboardShowing(this);\
        int aliceBottomToolbarHeight =\
                aliceKeyboardShowing ? 0 : aliceToolbarHeight + aliceToolbarHairlineHeight;\
        int verticalViewportInsets =\
                aliceInFullscreen\
                        ? controlsInsets + webContentsHeightInset\
                        : aliceTopControlsInset\
                                + aliceBottomToolbarHeight\
                                + mAliceNavigationBarInset;\
        // Alice patch end 0034' "$path10"
sed -i '/^        \/\/ Notify the compositor layout that the size has changed\.  The layout does not drive$/i\
        // Alice patch start 0034\
        if (mApplicationBottomInsetSupplier != null\
                && mVirtualKeyboardMode == VirtualKeyboardMode.RESIZES_VISUAL) {\
            updateWebContentsSize(getCurrentTab());\
        }\
        // Alice patch end 0034' "$path10"
sed -i '/^            } else if (mLastStableOutsetModeWebContentsHeight != null) {$/c\
            // Alice patch start 0034\
            } else if (mLastStableOutsetModeWebContentsHeight != null\
                    && !aliceKeyboardShowing) {\
            // Alice patch end 0034' "$path10"
