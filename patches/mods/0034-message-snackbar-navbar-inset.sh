#!/bin/bash
# 底部消息 UI：Snackbar、翻译气泡和 Hub Snackbar 容器的位置、层级与导航栏避让。

set -e

# 目标文件路径
path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ui/RootUiCoordinator.java"
path4="ui/android/java/src/org/chromium/ui/insets/InsetObserver.java"
path5="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerImpl.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path8="chrome/android/java/res_app/layout/main.xml"
path9="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"
path10="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"

# 检测是否已应用
if grep -q 'Alice patch start 0034' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

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
\
    private int getAliceBottomToolbarHeight() {\
        if (mAliceBottomToolbarHeight >= 0) {\
            return mAliceBottomToolbarHeight;\
        }\
        if (mAliceToolbarControlContainer == null) {\
            mAliceToolbarControlContainer =\
                    findAliceToolbarControlContainer(mRootContentView);\
        }\
        if (mAliceToolbarControlContainer != null\
                \&\& mAliceToolbarControlContainer.getVisibility() == View.VISIBLE\
                \&\& mAliceToolbarControlContainer.getHeight() > 0) {\
            mAliceBottomToolbarHeight = mAliceToolbarControlContainer.getHeight();\
            return mAliceBottomToolbarHeight;\
        }\
        android.content.res.Resources resources = mRootContentView.getResources();\
        String[] packages = {\
            mRootContentView.getContext().getPackageName(), "org.chromium.chrome"\
        };\
        for (String resourcePackage : packages) {\
            int toolbarHeightId =\
                    resources.getIdentifier(\
                            "toolbar_height_no_shadow", "dimen", resourcePackage);\
            if (toolbarHeightId != 0) {\
                mAliceBottomToolbarHeight =\
                        resources.getDimensionPixelSize(toolbarHeightId);\
                return mAliceBottomToolbarHeight;\
            }\
        }\
        for (String resourcePackage : packages) {\
            int controlContainerId =\
                    resources.getIdentifier(\
                            "control_container", "id", resourcePackage);\
            if (controlContainerId == 0) continue;\
            View controlContainer =\
                    mRootContentView.findViewById(controlContainerId);\
            if (controlContainer != null \&\& controlContainer.getHeight() > 0) {\
                mAliceBottomToolbarHeight = controlContainer.getHeight();\
                return mAliceBottomToolbarHeight;\
            }\
        }\
        return 0;\
    }\
\
    private static @Nullable View findAliceToolbarControlContainer(View view) {\
        if (view.getClass().getName().endsWith(".ToolbarControlContainer")) {\
            return view;\
        }\
        if (!(view instanceof ViewGroup)) return null;\
        ViewGroup group = (ViewGroup) view;\
        for (int i = 0; i < group.getChildCount(); i++) {\
            View result = findAliceToolbarControlContainer(group.getChildAt(i));\
            if (result != null) return result;\
        }\
        return null;\
    }\
\
    private boolean isAliceUndoSnackbar() {\
        int identifier = mSnackbar.getIdentifier();\
        return identifier == Snackbar.UMA_TAB_CLOSE_UNDO\
                || identifier == Snackbar.UMA_TAB_CLOSE_ALL_UNDO\
                || identifier == Snackbar.UMA_TAB_CLOSE_MULTIPLE_UNDO\
                || identifier == Snackbar.UMA_TAB_GROUP_DELETE_UNDO\
                || identifier == Snackbar.UMA_SINGLE_TAB_GROUP_DELETE_UNDO\
                || identifier == Snackbar.UMA_TAB_GROUP_MANUAL_CREATION_UNDO;\
    }\
\
    private ViewGroup getAliceSnackbarParent(ViewGroup parent) {\
        if (isAliceUndoSnackbar()\
                \&\& parent == mOriginalParent\
                \&\& mRootContentView instanceof ViewGroup) {\
            return (ViewGroup) mRootContentView;\
        }\
        return parent;\
    }\
\
    private void updateAliceSearchPageVisibility() {\
        if (!isAliceUndoSnackbar()) {\
            mContainerView.setTag(null);\
            return;\
        }\
        mContainerView.setTag("alice_undo_snackbar");\
        boolean aliceSearchPage =\
                Boolean.TRUE.equals(mRootContentView.getTag());\
        mContainerView.setVisibility(\
                aliceSearchPage ? View.INVISIBLE : View.VISIBLE);\
    }\
\
    public static void captureAliceNormalLayoutForHub(View rootView) {\
        View rootContent = rootView.getRootView().findViewById(android.R.id.content);\
        if (rootContent == null) rootContent = rootView;\
        android.content.res.Resources resources = rootContent.getResources();\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(rootContent);\
        int navigationBarHeight = 0;\
        if (insets != null) {\
            navigationBarHeight =\
                    Math.max(\
                            insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom,\
                            Math.max(\
                                    insets.getInsets(\
                                                    WindowInsetsCompat.Type\
                                                            .mandatorySystemGestures())\
                                            .bottom,\
                                    insets.getInsets(\
                                                    WindowInsetsCompat.Type.tappableElement())\
                                            .bottom));\
        }\
        int toolbarHeight = 0;\
        View toolbarControlContainer = findAliceToolbarControlContainer(rootContent);\
        if (toolbarControlContainer != null\
                \&\& toolbarControlContainer.getVisibility() == View.VISIBLE\
                \&\& toolbarControlContainer.getHeight() > 0) {\
            toolbarHeight = toolbarControlContainer.getHeight();\
        }\
        String[] packages = {\
            rootContent.getContext().getPackageName(), "org.chromium.chrome"\
        };\
        if (toolbarHeight == 0) {\
            for (String packageName : packages) {\
                int toolbarHeightId =\
                        resources.getIdentifier(\
                                "toolbar_height_no_shadow", "dimen", packageName);\
                if (toolbarHeightId != 0) {\
                    toolbarHeight = resources.getDimensionPixelSize(toolbarHeightId);\
                    break;\
                }\
            }\
        }\
        int hairlineHeight = 0;\
        for (String packageName : packages) {\
            int hairlineId =\
                    resources.getIdentifier(\
                            "toolbar_hairline_height", "dimen", packageName);\
            if (hairlineId != 0) {\
                hairlineHeight = resources.getDimensionPixelSize(hairlineId);\
                break;\
            }\
        }\
        int spacing = Math.round(15f * resources.getDisplayMetrics().density);\
        sAliceNormalScreenBottomOffsetPx =\
                toolbarHeight + hairlineHeight + navigationBarHeight + spacing;\
    }\
\
    private int getAliceNormalScreenBottomOffsetPx() {\
        if (sAliceNormalScreenBottomOffsetPx >= 0) {\
            return sAliceNormalScreenBottomOffsetPx;\
        }\
        int hairlineHeight = 0;\
        android.content.res.Resources resources = mRootContentView.getResources();\
        int hairlineId =\
                resources.getIdentifier(\
                        "toolbar_hairline_height", "dimen", mRootContentView.getContext().getPackageName());\
        if (hairlineId != 0) {\
            hairlineHeight = resources.getDimensionPixelSize(hairlineId);\
        }\
        int spacing = Math.round(15f * resources.getDisplayMetrics().density);\
        return getAliceBottomToolbarHeight()\
                + hairlineHeight\
                + getAliceNavigationBarHeight()\
                + spacing;\
    }\
\
    private boolean isAliceInHubContext() {\
        return "alice_hub_overlay_snackbar".equals(mParent.getTag())\
                || mRootContentView.findViewWithTag("alice_hub_overlay_snackbar") != null;\
    }\
\
    private int getAliceParentBottomInset() {\
        mRootContentView.getLocationInWindow(mAliceRootPosition);\
        mParent.getLocationInWindow(mAliceParentPosition);\
        int rootBottom =\
                mAliceRootPosition[1] + mRootContentView.getHeight();\
        int parentBottom =\
                mAliceParentPosition[1] + mParent.getHeight();\
        return Math.max(0, rootBottom - parentBottom);\
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

# 4) 在 0014 的工具栏底部留白之上叠加导航栏高度；键盘可见时取静止底部
#    边距和动画 IME 高度的较大值，避免重复叠加。
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

sed -i '/^    @EnsuresNonNull("mToolbarManager")$/i\
    // Alice patch start 0034\
    private void updateAliceSnackbarZOrder(boolean aliceSearchPage) {\
        View aliceRootContent =\
                mActivity.findViewById(android.R.id.content);\
        if (aliceRootContent == null) return;\
        aliceRootContent.setTag(aliceSearchPage);\
        View aliceHubSnackbar =\
                aliceRootContent.findViewWithTag("alice_hub_overlay_snackbar");\
        if (aliceHubSnackbar != null) {\
            aliceHubSnackbar.setZ(aliceSearchPage ? -1f : 2000f);\
            if (!aliceSearchPage \&\& aliceRootContent instanceof ViewGroup) {\
                ((ViewGroup) aliceRootContent)\
                        .bringChildToFront(aliceHubSnackbar);\
            }\
        }\
        View aliceBottomContainer =\
                mActivity.findViewById(R.id.bottom_container);\
        if (aliceBottomContainer != null) {\
            aliceBottomContainer.setZ(aliceSearchPage ? -1f : 0f);\
        }\
        View aliceUndoSnackbar =\
                aliceRootContent.findViewWithTag("alice_undo_snackbar");\
        if (aliceUndoSnackbar != null) {\
            aliceUndoSnackbar.setVisibility(\
                    aliceSearchPage ? View.INVISIBLE : View.VISIBLE);\
        }\
    }\
    // Alice patch end 0034\
' "$path3"

# 搜索页打开时把撤销 Snackbar 放到它下层，退出搜索页后恢复原层级。
sed -i '/^                    hasFocus -> {$/a\
                        // Alice patch start 0034\
                        updateAliceSnackbarZOrder(hasFocus);\
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

# 5) Snackbar 直接监听 InsetObserver 的 IME 动画，逐帧更新位置。
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
    private final int[] mAliceRootPosition = new int[2];\
    private final int[] mAliceParentPosition = new int[2];\
    private @Nullable View mAliceToolbarControlContainer;\
    private int mAliceBottomToolbarHeight = -1;\
    private static int sAliceNormalScreenBottomOffsetPx = -1;\
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
        // Restore the normal layer while dismissing so the bottom toolbar does not\
        // clip the exit animation before it reaches the screen bottom.\
        if (mParent != mRootContentView) {\
            if ("alice_hub_overlay_snackbar".equals(mParent.getTag())) {\
                mParent.setZ(2000f);\
                if (mParent.getParent() instanceof ViewGroup) {\
                    ((ViewGroup) mParent.getParent()).bringChildToFront(mParent);\
                }\
            } else {\
                mParent.setZ(0f);\
            }\
        }\
        // Alice patch end 0034' "$path1"

sed -i 's@^        boolean aliceImeShowing =$@        boolean aliceImeShowing = mAliceImeAnimationHeight >= 0 ||@' "$path1"
sed -i '/^            int aliceImeHeight = keyboardHeight;$/c\
            int aliceImeHeight =\
                    mAliceImeAnimationHeight >= 0\
                            ? mAliceImeAnimationHeight\
                            : keyboardHeight;' "$path1"

# 6) 翻译气泡直接监听同一个 InsetObserver 动画源。

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

# 7) 动画准备阶段先停在上一帧高度，避免在 onProgress 前闪到最终位置；
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
# 8) 把 IME 动画状态保存在 InsetObserver，供动画开始后才创建的
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
        if (mAliceInsetObserver != null\
                && mAliceInsetObserver.isImeAnimationInProgress()) {\
            mAliceImeAnimationInProgress = true;\
            int aliceGlobalImeAnimationHeight =\
                    mAliceInsetObserver.getCurrentImeAnimationHeight();\
            if (aliceGlobalImeAnimationHeight >= 0) {\
                mAliceImeAnimationHeight = aliceGlobalImeAnimationHeight;\
            }\
        }' "$path1"

sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/i\
        if (mAliceInsetObserver != null\
                && mAliceInsetObserver.isImeAnimationInProgress()) {\
            mAliceImeAnimationInProgress = true;\
            int aliceGlobalImeAnimationHeight =\
                    mAliceInsetObserver.getCurrentImeAnimationHeight();\
            if (aliceGlobalImeAnimationHeight >= 0) {\
                mAliceImeAnimationHeight = aliceGlobalImeAnimationHeight;\
            }\
        }' "$path2"
# 9) 非动画帧也使用 InsetObserver 保存的稳定 IME 高度，绝不直接读
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
sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/a\
                (mAliceInsetObserver != null\
                                && mAliceInsetObserver.getCurrentImeAnimationHeight() > 0)\
                        ||' "$path2"

# 10) 气泡首次显示前先完成定位，避免旧布局位置先绘制一帧。
sed -i '/^        if (mContainer\.getVisibility() != View\.VISIBLE) {$/c\
        // Alice patch start 0034\
        if (mContainer.getVisibility() == View.GONE) {\
        // Alice patch end 0034' "$path2"
sed -i '/^        WindowInsetsCompat aliceInsets = ViewCompat\.getRootWindowInsets(mContainer);$/c\
        // Alice patch start 0034\
        WindowInsetsCompat aliceInsets = ViewCompat.getRootWindowInsets(mContainer);\
        if (aliceInsets == null && mAliceInsetObserver != null) {\
            aliceInsets = mAliceInsetObserver.getLastRawWindowInsets();\
        }\
        // Alice patch end 0034' "$path2"
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
                        updateAliceSearchPageVisibility();\
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
# 11) 所有气泡高度分支统一读取稳定 IME 高度，禁止回退到最终 raw inset。
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

# 撤销 Snackbar 与翻译气泡共用同一个静止底部基准；IME 可见时继续共用
# InsetObserver 的动画高度，避免两者相对键盘的间隔不同。
sed -i '/^        int aliceRestingBottomMargin =$/,/^                        + aliceNavigationBarHeight;$/c\
        int aliceRestingBottomMargin =\
                getAliceBottomToolbarHeight() + aliceNavigationBarHeight;' "$path1"

sed -i '/^        int aliceBottomMargin =$/,/^                        : aliceRestingBottomMargin;$/c\
        int aliceNormalSpacingAdjustment =\
                Math.round(\
                        15f\
                                * mRootContentView\
                                        .getResources()\
                                        .getDisplayMetrics()\
                                        .density);\
        int aliceImeSpacingAdjustment =\
                Math.round(\
                        16f\
                                * mRootContentView\
                                        .getResources()\
                                        .getDisplayMetrics()\
                                        .density);\
        int aliceRestingScreenBottomTarget =\
                aliceRestingBottomMargin + aliceNormalSpacingAdjustment;\
        int aliceImeScreenBottomTarget =\
                aliceImeHeight + aliceImeSpacingAdjustment;\
        int aliceScreenBottomTarget =\
                aliceImeShowing\
                        ? Math.max(\
                                aliceRestingScreenBottomTarget,\
                                aliceImeScreenBottomTarget)\
                        : aliceRestingScreenBottomTarget;\
        boolean aliceHubOverlay =\
                "alice_hub_overlay_snackbar".equals(mParent.getTag());\
        if (aliceHubOverlay) {\
            mContainerView.setElevation(2000f);\
            mContainerView.setTranslationZ(2000f);\
        }\
        int aliceBottomMargin;\
        int parentBottomInset = getAliceParentBottomInset();\
        boolean aliceInHub = isAliceInHubContext();\
        if ((aliceInHub || aliceHubOverlay) \&\& !aliceImeShowing) {\
            int parentBottomOffset = parentBottomInset;\
            if (aliceHubOverlay) {\
                parentBottomOffset += mParent.getPaddingBottom();\
            }\
            aliceBottomMargin =\
                    Math.max(\
                            0,\
                            getAliceNormalScreenBottomOffsetPx()\
                                    - parentBottomOffset);\
        } else {\
            aliceBottomMargin =\
                    Math.max(\
                            0,\
                            aliceScreenBottomTarget - parentBottomInset);\
            if (!aliceHubOverlay \&\& !aliceImeShowing) {\
                sAliceNormalScreenBottomOffsetPx =\
                        aliceBottomMargin + parentBottomInset;\
            }\
        }' "$path1"

# 12) ChromeTabbedActivity 已经使用 SOFT_INPUT_ADJUST_RESIZE。Edge-to-Edge
#     不能再把 keyboard height 加到 content padding，否则会产生二次位移。
sed -i '/^        if (isKeyboardInsetTallerThanNavBar()) {$/,/^        }$/c\
        // Alice patch start 0034\
        // ADJUST_RESIZE already accounts for the keyboard. Do not add its height\
        // to content padding a second time.\
        // Alice patch end 0034' "$path5"

# 13) visual viewport 的高度已经基于工具栏上方的 View 高度计算，IME inset
#     因此重复扣除了工具栏高度。键盘可见时补偿回工具栏高度。
sed -i '/^import org\.chromium\.build\.annotations\.Nullable;$/a\
// Alice patch start 0034\
import org.chromium.chrome.R;\
// Alice patch end 0034' "$path6"

sed -i '/^                        : mCurrentInsetSupplier\.get()\.visualViewportBottomInset;$/a\
        // Alice patch start 0034\
        if (inset > 0) {\
            int aliceToolbarHeight =\
                    getContentView()\
                            .getResources()\
                            .getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
            int aliceToolbarHairlineHeight =\
                    getContentView()\
                            .getResources()\
                            .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
            int aliceToolbarInset = aliceToolbarHeight + aliceToolbarHairlineHeight;\
            inset = Math.max(0, inset - Math.min(inset, aliceToolbarInset));\
        }\
        // Alice patch end 0034' "$path6"

# 15) Hub 标签页预览（缩略图/展开动画）在 bottom_container 之后绘制，
#     会盖住撤销气泡。把 bottom_container 移到 tab_switcher_view_holder_stub
#     之后，让气泡位于 Hub 预览动画之上。forked 布局已经是这个顺序，无需处理。
sed -i '/^        <org.chromium.chrome.browser.ui.BottomContainer$/{:a;N;/android:layout_gravity="start[|]bottom" \/>$/{N;d};ba}' "$path8"

sed -i '/^            android.layout="@layout\/tab_switcher_view_holder" \/>$/a\
\
        <org.chromium.chrome.browser.ui.BottomContainer\
            android:id="@+id/bottom_container"\
            android:layout_width="match_parent"\
            android:layout_height="wrap_content"\
            android:layout_gravity="start|bottom" />' "$path8"

sed -i '/^    private @Nullable EdgeToEdgePadAdjuster mEdgeToEdgePadAdjuster;$/a\
    // Alice patch start 0034\
    private @Nullable ViewGroup mAliceSnackbarRootContent;\
    private @Nullable View mAliceSnackbarContainer;\
    // Alice patch end 0034' "$path9"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0034\
        if (mAliceSnackbarRootContent != null \&\& mAliceSnackbarContainer != null) {\
            mAliceSnackbarRootContent.removeView(mAliceSnackbarContainer);\
            mAliceSnackbarRootContent = null;\
            mAliceSnackbarContainer = null;\
        }\
        // Alice patch end 0034' "$path9"

# 16) Hub 显示前记录正常网页布局基准。
sed -i '/^import org\.chromium\.chrome\.browser\.ui\.messages\.snackbar\.SnackbarManager;$/a\
// Alice patch start 0034\
import org.chromium.chrome.browser.ui.messages.snackbar.SnackbarView;\
// Alice patch end 0034' "$path10"

sed -i '/^    public void onHubLayoutShow() {$/a\
        // Alice patch start 0034\
        SnackbarView.captureAliceNormalLayoutForHub(\
                mActivity.getWindow().getDecorView());\
        // Alice patch end 0034' "$path10"

# 16.1) Hub 的 Snackbar 容器挂到 Activity 根层，避免进入 Hub 时被隐藏层覆盖或瞬隐。
sed -i '/^        HubPaneHostView hubPaneHostView = mContainerView.findViewById(R.id.hub_pane_host);$/a\
        // Alice patch start 0034\
        // Host the Hub snackbar above the Hub layer so it stays visible during layout changes.\
        {\
            View alicePinnedSnackbarContainer =\
                    hubPaneHostView.findViewById(R.id.pane_host_view_snackbar_container);\
            if (alicePinnedSnackbarContainer != null\
                    \&\& alicePinnedSnackbarContainer.getParent() instanceof ViewGroup) {\
                ((ViewGroup) alicePinnedSnackbarContainer.getParent())\
                        .removeView(alicePinnedSnackbarContainer);\
                View rootView = activity.findViewById(android.R.id.content);\
                if (rootView instanceof ViewGroup) {\
                    ViewGroup rootContent = (ViewGroup) rootView;\
                    View toolbarActionContainer =\
                            hubToolbarView.findViewById(R.id.toolbar_action_container);\
                    int toolbarHeight = 0;\
                    if (toolbarActionContainer != null) {\
                        ViewGroup.LayoutParams toolbarParams =\
                                toolbarActionContainer.getLayoutParams();\
                        if (toolbarParams != null \&\& toolbarParams.height > 0) {\
                            toolbarHeight = toolbarParams.height;\
                        }\
                    }\
                    if (toolbarHeight == 0) {\
                        toolbarHeight = hubToolbarView.getMinimumHeight();\
                    }\
                    int toolbarHairlineHeight =\
                            Math.round(\
                                    context.getResources()\
                                            .getDisplayMetrics()\
                                            .density);\
                    FrameLayout.LayoutParams params =\
                            new FrameLayout.LayoutParams(\
                                    ViewGroup.LayoutParams.MATCH_PARENT,\
                                    ViewGroup.LayoutParams.MATCH_PARENT);\
                    params.gravity = android.view.Gravity.BOTTOM;\
                    // The normal bottom_container includes the 1dp toolbar hairline in its\
                    // measured height. Match that baseline so the Hub overlay and tab page\
                    // place the snackbar at the same vertical position.\
                    alicePinnedSnackbarContainer.setPadding(\
                            alicePinnedSnackbarContainer.getPaddingLeft(),\
                            alicePinnedSnackbarContainer.getPaddingTop(),\
                            alicePinnedSnackbarContainer.getPaddingRight(),\
                            toolbarHeight + toolbarHairlineHeight);\
                    if (alicePinnedSnackbarContainer instanceof ViewGroup) {\
                        ((ViewGroup) alicePinnedSnackbarContainer)\
                                .setClipToPadding(false);\
                    }\
                    alicePinnedSnackbarContainer.setElevation(2000f);\
                    alicePinnedSnackbarContainer.setTranslationZ(2000f);\
                    alicePinnedSnackbarContainer.setTag("alice_hub_overlay_snackbar");\
                    rootContent.addView(alicePinnedSnackbarContainer, params);\
                    rootContent.bringChildToFront(alicePinnedSnackbarContainer);\
                    mAliceSnackbarRootContent = rootContent;\
                    mAliceSnackbarContainer = alicePinnedSnackbarContainer;\
                }\
            }\
        }\
        // Alice patch end 0034' "$path9"

# 17) 撤销气泡的消失动画只移动到父容器底边。父容器 bottom_container 会被浏览器
#     控件向上平移，所以动画停在导航栏上方。普通网页的撤销气泡改挂到 Activity
#     根层，与标签管理页使用同一套无裁剪绘制边界，并让动画一直滑出屏幕底部。
sed -i '/^    protected int getYPositionForMoveAnimation() {$/,/^    }$/c\
    protected int getYPositionForMoveAnimation() {\
        // Alice patch start 0034\
        View aliceRootView = mRootContentView.getRootView();\
        aliceRootView.getLocationInWindow(mAliceRootPosition);\
        mContainerView.getLocationInWindow(mAliceParentPosition);\
        int aliceRootBottom =\
                mAliceRootPosition[1] + aliceRootView.getHeight();\
        return Math.max(0, aliceRootBottom - mAliceParentPosition[1]);\
        // Alice patch end 0034\
    }' "$path1"

sed -i '/^    private void addToParent() {$/,/^    }$/c\
    private void addToParent() {\
        // Alice patch start 0034\
        // Host the normal-tab undo bar on the activity root so ancestor clipping\
        // cannot stop its dismissal before it reaches the screen bottom.\
        ViewGroup aliceSnackbarParent = getAliceSnackbarParent(mParent);\
        mParent = aliceSnackbarParent;\
        // Snackbars created while the search page is focused start below it too.\
        if (Boolean.TRUE.equals(\
                    mRootContentView.getTag())\
                \&\& mParent != mRootContentView) {\
            mParent.setZ(-1f);\
        }\
        // Alice patch end 0034\
        mParent.addView(mContainerView);\
        // Alice patch start 0034\
        if (mParent == mRootContentView) {\
            mParent.bringChildToFront(mContainerView);\
        }\
        updateAliceSearchPageVisibility();\
        // Alice patch end 0034\
        mParent.addOnLayoutChangeListener(mLayoutListener);\
    }' "$path1"

sed -i '/^    private void updateBottomMargin(int additionalBottomMarginPx) {$/a\
        // Alice patch start 0034\
        if (isAliceInHubContext()) {\
            adjustViewPosition();\
            return;\
        }\
        // Alice patch end 0034\
' "$path1"
