#!/bin/bash
# 同步 IME visual viewport、焦点输入框与底部气泡/导航栏位置

set -e

# 目标文件路径
path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ui/RootUiCoordinator.java"
path4="ui/android/java/src/org/chromium/ui/insets/InsetObserver.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedNavigationBarColorController.java"
path6="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerImpl.java"
path7="ui/edge_to_edge/android/java/src/org/chromium/ui/edge_to_edge/EdgeToEdgeSystemBarColorHelper.java"
path9="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"
path10="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path11="chrome/android/java/res_app/layout/main.xml"
path12="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"
path13="cc/trees/proxy.h"
path14="cc/trees/layer_tree_host.h"
path15="cc/trees/layer_tree_host.cc"
path16="cc/trees/proxy_main.h"
path17="cc/trees/proxy_main.cc"
path18="cc/trees/proxy_impl.h"
path19="cc/trees/proxy_impl.cc"
path20="cc/trees/single_thread_proxy.h"
path21="content/public/android/java/src/org/chromium/content/browser/webcontents/WebContentsImpl.java"
path22="cc/trees/single_thread_proxy.cc"
path23="cc/test/fake_proxy.h"
path24="third_party/blink/public/mojom/input/input_handler.mojom"
path25="third_party/blink/renderer/platform/widget/input/frame_widget_input_handler_impl.h"
path26="third_party/blink/renderer/platform/widget/input/frame_widget_input_handler_impl.cc"
path27="third_party/blink/renderer/core/frame/web_frame_widget_impl.h"
path28="third_party/blink/renderer/core/frame/web_frame_widget_impl.cc"
path29="content/browser/web_contents/web_contents_android.h"
path30="content/browser/web_contents/web_contents_android.cc"
path31="content/public/android/java/src/org/chromium/content_public/browser/WebContents.java"
path32="cc/trees/layer_tree_host_impl.h"
path33="cc/trees/layer_tree_host_impl.cc"
path34="ui/android/delegated_frame_host_android.h"
path35="content/browser/renderer_host/render_widget_host_view_android.h"
path36="content/browser/renderer_host/render_widget_host_view_android.cc"
path37="third_party/blink/renderer/core/exported/web_view_impl.cc"
path38="third_party/blink/renderer/core/frame/visual_viewport.h"
path39="third_party/blink/renderer/core/frame/visual_viewport.cc"
path40="cc/layers/viewport.h"
path41="cc/layers/viewport.cc"
path42="content/public/android/java/src/org/chromium/content_public/browser/ImeAdapter.java"
path43="content/public/android/java/src/org/chromium/content/browser/input/ImeAdapterImpl.java"

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
    private @Nullable View findAliceToolbarControlContainer(View view) {\
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

# 6) 底置工具栏使用工具栏主色绘制系统导航栏，包括 IME 弹出期间。IME
#    动画开始和结束时重新应用颜色，避免导航栏停留在页面底色。
sed -i '/^import androidx\.annotation\.VisibleForTesting;$/a\
// Alice patch start 0034\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0034' "$path5"

sed -i '/^import org\.chromium\.ui\.util\.ColorUtils;$/a\
// Alice patch start 0034\
import java.util.List;\
// Alice patch end 0034' "$path5"

sed -i '/^    private @Nullable Supplier<Integer> mToolbarColorSupplier;$/a\
    // Alice patch start 0034\
    private @Nullable InsetObserver mAliceInsetObserver;\
    private final InsetObserver.WindowInsetsAnimationListener mAliceImeAnimationListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) != 0) {\
                        updateNavigationBarColor(\
                                /* forceShowDivider= */ false,\
                                /* disableAnimation= */ true);\
                        mEdgeToEdgeSystemBarColorHelper\
                                .refreshNavigationBarColorForIme();\
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
                        List<WindowInsetsAnimationCompat> runningAnimations) {\
                    updateNavigationBarColor(\
                            /* forceShowDivider= */ false,\
                            /* disableAnimation= */ true);\
                    mEdgeToEdgeSystemBarColorHelper\
                            .refreshNavigationBarColorForIme();\
                }\
\
                @Override\
                public void onEnd(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) != 0) {\
                        mEdgeToEdgeSystemBarColorHelper\
                                .refreshNavigationBarColorForIme();\
                        if (mContext instanceof Activity) {\
                            android.view.View aliceContent =\
                                    ((Activity) mContext)\
                                            .findViewById(android.R.id.content);\
                            if (aliceContent != null) {\
                                aliceContent.postOnAnimation(\
                                        () ->\
                                                updateNavigationBarColor(\
                                                        /* forceShowDivider= */ false,\
                                                        /* disableAnimation= */ true));\
                                return;\
                            }\
                        }\
                        updateNavigationBarColor(\
                                /* forceShowDivider= */ false,\
                                /* disableAnimation= */ true);\
                    }\
                }\
            };\
    // Alice patch end 0034' "$path5"

sed -i '/^        mBrowserControlsStateProvider\.addObserver(this);$/a\
        // Alice patch start 0034\
        mAliceInsetObserver = insetObserver;\
        if (mAliceInsetObserver != null) {\
            mAliceInsetObserver.addWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
        }\
        // Alice patch end 0034' "$path5"

sed -i '/^            mBrowserControlsStateProvider\.removeObserver(this);$/a\
        // Alice patch start 0034\
        if (mAliceInsetObserver != null) {\
            mAliceInsetObserver.removeWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
            mAliceInsetObserver = null;\
        }\
        // Alice patch end 0034' "$path5"
sed -i '/^import androidx\.annotation\.ColorInt;$/a\
// Alice patch start 0034\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0034' "$path7"

sed -i '/^    private void updateNavBarColors() {$/i\
    // Alice patch start 0034\
    private boolean isAliceImeVisible() {\
        @Nullable WindowInsetsCompat aliceInsets =\
                ViewCompat.getRootWindowInsets(mWindow.getDecorView());\
        return aliceInsets != null\
                \&\& aliceInsets.isVisible(WindowInsetsCompat.Type.ime())\
                \&\& aliceInsets.getInsets(WindowInsetsCompat.Type.ime()).bottom > 0;\
    }\
\
    public void refreshNavigationBarColorForIme() {\
        updateNavBarColors();\
    }\
    // Alice patch end 0034\
' "$path7"

sed -i '/^        int windowNavColor = mIsActivityEdgeToEdge ? Color\.TRANSPARENT : mNavBarColor;$/c\
        // Alice patch start 0034\
        boolean aliceImeVisible = isAliceImeVisible();\
        int windowNavColor =\
                aliceImeVisible ? mNavBarColor : Color.TRANSPARENT;\
        // Alice patch end 0034' "$path7"
sed -i '/^        int windowNavDividerColor = mIsActivityEdgeToEdge ? Color\.TRANSPARENT : mNavBarDividerColor;$/c\
        // Alice patch start 0034\
        int windowNavDividerColor =\
                aliceImeVisible ? mNavBarDividerColor : Color.TRANSPARENT;\
        // Alice patch end 0034' "$path7"

sed -i 's|^        mWindowColorHelper\.setNavigationBarContrastEnforced(!mIsActivityEdgeToEdge);$|        // Alice patch start 0034\n        mWindowColorHelper.setNavigationBarContrastEnforced(false);\n        // Alice patch end 0034|' "$path7"

sed -i '/^        mWindowColorHelper.setNavigationBarContrastEnforced(false);$/a\
        // Alice patch start 0034\
        if (aliceImeVisible) {\
            mWindow.clearFlags(\
                    android.view.WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);\
            mWindow.addFlags(\
                    android.view.WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);\
            mWindow.setNavigationBarColor(windowNavColor);\
            mWindow.setNavigationBarDividerColor(windowNavDividerColor);\
            mWindow.setNavigationBarContrastEnforced(false);\
        }\
        // Alice patch end 0034' "$path7"

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
    private final int[] mAliceRootPosition = new int[2];\
    private final int[] mAliceParentPosition = new int[2];\
    private @Nullable View mAliceToolbarControlContainer;\
    private int mAliceBottomToolbarHeight = -1;\
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
sed -i '/^        boolean aliceImeShowing = mAliceImeAnimationInProgress ||$/a\
                (mAliceInsetObserver != null\
                                && mAliceInsetObserver.getCurrentImeAnimationHeight() > 0)\
                        ||' "$path2"

# 12) 气泡首次显示前先完成定位，避免旧布局位置先绘制一帧。
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
        int aliceBottomMargin =\
                aliceHubOverlay \&\& !aliceImeShowing\
                        ? aliceNavigationBarHeight + aliceNormalSpacingAdjustment\
                        : Math.max(\
                                0,\
                                aliceScreenBottomTarget - getAliceParentBottomInset());' "$path1"

# 14) ChromeTabbedActivity 已经使用 SOFT_INPUT_ADJUST_RESIZE。Edge-to-Edge
#     不能再把 keyboard height 加到 content padding，否则会产生二次位移。
sed -i '/^        if (isKeyboardInsetTallerThanNavBar()) {$/,/^        }$/c\
        // Alice patch start 0034\
        // ADJUST_RESIZE already accounts for the keyboard. Do not add its height\
        // to content padding a second time.\
        // Alice patch end 0034' "$path6"

# 15) visual viewport 的高度已经基于工具栏上方的 View 高度计算，IME inset
#     因此重复扣除了工具栏高度。键盘可见时补偿回工具栏高度。
sed -i '/^import org\.chromium\.build\.annotations\.Nullable;$/a\
// Alice patch start 0034\
import org.chromium.chrome.R;\
// Alice patch end 0034' "$path9"

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
        // Alice patch end 0034' "$path9"

# 16) 底部工具栏在 IME 动画期间会从 minibar 切回完整工具栏。
#     WebContents 如果读取动态控件高度，会跟着 minibar 重新布局并短暂绘制到底部。
#     地址栏位于底部时固定预留 toolbar_height_no_shadow + toolbar_hairline_height，
#     导航栏仍由后续 inset 单独叠加；地址栏位于顶部时也预留系统导航栏高度，
#     让网页绘制区域不伸到系统导航栏下面。
sed -i '/^        int aliceTopControlsInset = 0;$/,/^        }$/c\
        // Alice patch start 0034\
        int aliceTopControlsInset = 0;\
        int aliceBottomControlsInset = 0;\
        if (!aliceInFullscreen && mBrowserControlsManager != null) {\
            aliceTopControlsInset =\
                    mControlsResizeView\
                            ? mBrowserControlsManager.getTopControlsHeight()\
                            : mBrowserControlsManager.getTopControlsMinHeight();\
            boolean aliceBottomToolbar =\
                    mBrowserControlsManager.getControlsPosition()\
                            == BrowserControlsStateProvider.ControlsPosition.BOTTOM;\
            if (aliceBottomToolbar) {\
                int aliceToolbarHeight =\
                        getResources()\
                                .getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
                int aliceToolbarHairlineHeight =\
                        getResources()\
                                .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
                aliceBottomControlsInset = aliceToolbarHeight + aliceToolbarHairlineHeight;\
            } else {\
                if (!mBrowserControlsManager.hasHidingTokens()) {\
                    aliceBottomControlsInset =\
                            mControlsResizeView\
                                    ? mBrowserControlsManager.getBottomControlsHeight()\
                                    : mBrowserControlsManager.getBottomControlsMinHeight();\
                }\
                if (mBrowserControlsManager.getControlsPosition()\
                        == BrowserControlsStateProvider.ControlsPosition.TOP) {\
                    aliceBottomControlsInset += mAliceNavigationBarInset;\
                }\
            }\
        }\
        // Alice patch end 0034\
' "$path10"

# 17) Hub 标签页预览（缩略图/展开动画）在 bottom_container 之后绘制，
#     会盖住撤销气泡。把 bottom_container 移到 tab_switcher_view_holder_stub
#     之后，让气泡位于 Hub 预览动画之上。forked 布局已经是这个顺序，无需处理。
sed -i '/^        <org.chromium.chrome.browser.ui.BottomContainer$/{:a;N;/android:layout_gravity="start[|]bottom" \/>$/{N;d};ba}' "$path11"

sed -i '/^            android.layout="@layout\/tab_switcher_view_holder" \/>$/a\
\
        <org.chromium.chrome.browser.ui.BottomContainer\
            android:id="@+id/bottom_container"\
            android:layout_width="match_parent"\
            android:layout_height="wrap_content"\
            android:layout_gravity="start|bottom" />' "$path11"

sed -i '/^    private @Nullable EdgeToEdgePadAdjuster mEdgeToEdgePadAdjuster;$/a\
    // Alice patch start 0034\
    private @Nullable ViewGroup mAliceSnackbarRootContent;\
    private @Nullable View mAliceSnackbarContainer;\
    // Alice patch end 0034' "$path12"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0034\
        if (mAliceSnackbarRootContent != null \&\& mAliceSnackbarContainer != null) {\
            mAliceSnackbarRootContent.removeView(mAliceSnackbarContainer);\
            mAliceSnackbarRootContent = null;\
            mAliceSnackbarContainer = null;\
        }\
        // Alice patch end 0034' "$path12"

# 18) Hub 的 Snackbar 容器挂到 Activity 根层，避免进入 Hub 时被隐藏层覆盖或瞬隐。
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
        // Alice patch end 0034' "$path12"

# 19) 撤销气泡的消失动画只移动到父容器底边。父容器 bottom_container 会被浏览器
#     控件向上平移，所以动画停在导航栏上方。补上父容器到窗口底部的距离，并关闭
#     父容器裁剪，让气泡一直滑出屏幕底部。
sed -i '/^    protected int getYPositionForMoveAnimation() {$/,/^    }$/c\
    protected int getYPositionForMoveAnimation() {\
        // Alice patch start 0034\
        if ("alice_hub_overlay_snackbar".equals(mParent.getTag())) {\
            mRootContentView.getLocationInWindow(mAliceRootPosition);\
            mContainerView.getLocationInWindow(mAliceParentPosition);\
            int rootBottom =\
                    mAliceRootPosition[1] + mRootContentView.getHeight();\
            return Math.max(0, rootBottom - mAliceParentPosition[1]);\
        }\
        return mContainerView.getHeight()\
                + getLayoutParams().bottomMargin\
                + getAliceParentBottomInset();\
        // Alice patch end 0034\
    }' "$path1"

sed -i '/^    private void addToParent() {$/,/^    }$/c\
    private void addToParent() {\
        // Alice patch start 0034\
        // Allow the snackbar to slide past the parent bottom while dismissing.\
        mParent.setClipChildren(false);\
        // Alice patch end 0034\
        mParent.addView(mContainerView);\
        mParent.addOnLayoutChangeListener(mLayoutListener);\
        // Alice patch start 0034\
        // Window insets can settle after the Hub overlay is first attached. Recalculate\
        // once on the next frame so the initial and returned positions share the same base.\
        if ("alice_hub_overlay_snackbar".equals(mParent.getTag())) {\
            mParent.postOnAnimation(this::adjustViewPosition);\
        }\
        // Alice patch end 0034\
    }' "$path1"

# 21) IME 动画逐帧更新 Blink inner visual viewport。抬升量从 IME 高度中扣除
#     底部工具栏和导航栏，并以物理像素原样传给 Blink。
#     同一个动画源驱动 Blink 内部视口，不再平移整个网页 View。
if ! grep -q 'mAliceImeAnimationListener' "$path9"; then
sed -i '/^import org\.chromium\.ui\.dragdrop\.DragStateTracker;$/a\
// Alice patch start 0034\
import java.util.List;\
// Alice patch end 0034' "$path9"

sed -i '/^import org\.chromium\.base\.Callback;$/i\
// Alice patch start 0034\
import org.chromium.base.supplier.MonotonicObservableSupplier;\
// Alice patch end 0034' "$path9"

sed -i '/^import android\.util\.SparseArray;$/i\
// Alice patch start 0034\
import android.app.Activity;\
// Alice patch end 0034' "$path9"

sed -i '/^import android\.view\.autofill\.AutofillValue;$/a\
// Alice patch start 0034\
import android.view.WindowManager;\
// Alice patch end 0034' "$path9"

sed -i '/^import android\.util\.SparseArray;$/a\
// Alice patch start 0034\
import android.view.View;\
// Alice patch end 0034' "$path9"

sed -i '/^import org\.chromium\.base\.Callback;$/i\
// Alice patch start 0034\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0034' "$path9"

sed -i '/^import org\.chromium\.content_public\.browser\.ContentFeatureMap;$/a\
// Alice patch start 0034\
import org.chromium.content_public.browser.ImeAdapter;\
import org.chromium.content_public.browser.WebContents;\
import org.chromium.content_public.browser.WebContentsObserver;\
// Alice patch end 0034' "$path9"

sed -i '/^import org\.chromium\.chrome\.R;$/a\
// Alice patch start 0034\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinator;\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinatorSupplier;\
// Alice patch end 0034' "$path9"

if ! grep -q 'Register the WebContents focus gate' "$path9"; then
sed -i '/^        mTab = (TabImpl) tab;$/a\
        // Alice patch start 0034\
        // Register the WebContents focus gate.\
        attachAliceWebContentsObserver();\
        // Alice patch end 0034' "$path9"
fi

sed -i '/^import org\.chromium\.ui\.dragdrop\.DragStateTracker;$/a\
// Alice patch start 0034\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0034' "$path9"

sed -i '/^    private final Callback<ViewportInsets> mInsetObserver = _ -> updateVisualViewportBottomInset();$/a\
    // Alice patch start 0034\
    private @Nullable InsetObserver mAliceImeInsetObserver;\
    private @Nullable WindowAndroid mAliceImeWindowAndroid;\
    private boolean mAliceImeAnimationActive;\
    private boolean mAliceLiftForFocusedInput;\
    private int mAliceLastImeHeightPx;\
    private final int[] mAliceTmpLocation = new int[2];\
    private @Nullable WebContentsObserver mAliceWebContentsObserver;\
    private final WindowAndroid.ActivityStateObserver mAliceActivityStateObserver =\
            new WindowAndroid.ActivityStateObserver() {\
                @Override\
                public void onActivityPaused() {\
                    resetAliceImeViewportTranslation();\
                }\
\
                @Override\
                public void onActivityTopResumedChanged(boolean isTopResumedActivity) {\
                    if (!isTopResumedActivity) resetAliceImeViewportTranslation();\
                }\
            };\
    private final InsetObserver.WindowInsetsAnimationListener\
            mAliceImeAnimationListener =\
                    new InsetObserver.WindowInsetsAnimationListener() {\
                        @Override\
                        public void onPrepare(WindowInsetsAnimationCompat animation) {\
                            if ((animation.getTypeMask() \& WindowInsetsCompat.Type.ime())\
                                    != 0) {\
                                mAliceImeAnimationActive =\
                                        shouldManageImeInVisualViewport();\
                                WindowInsetsCompat insets =\
                                        ViewCompat.getRootWindowInsets(getContentView());\
                                if (mAliceImeAnimationActive\
                                        \&\& (insets == null\
                                                || !insets.isVisible(\
                                                        WindowInsetsCompat.Type.ime()))) {\
                                    mAliceLiftForFocusedInput = false;\
                                }\
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
                                List<WindowInsetsAnimationCompat> runningAnimations) {\
                            if (!mAliceImeAnimationActive) return;\
                            mAliceLastImeHeightPx = getAliceKeyboardHeight(insets);\
                            int focusedNodeBottomPx = getAliceFocusedNodeBottomPx();\
                            int imeTopPx =\
                                    getAliceRootBottomPx() - mAliceLastImeHeightPx;\
                            if (focusedNodeBottomPx > imeTopPx) {\
                                mAliceLiftForFocusedInput = true;\
                            }\
                            updateImeViewportTranslation(mAliceLastImeHeightPx);\
                        }\
\
                        @Override\
                        public void onEnd(WindowInsetsAnimationCompat animation) {\
                            if ((animation.getTypeMask() \& WindowInsetsCompat.Type.ime())\
                                    == 0) {\
                                return;\
                            }\
                            if (!mAliceImeAnimationActive) return;\
                            mAliceImeAnimationActive = false;\
                            updateImeViewportTranslation(mAliceLastImeHeightPx);\
                            if (mAliceLastImeHeightPx == 0) {\
                                mAliceLiftForFocusedInput = false;\
                            }\
                            setVisualViewportBottomInset(0);\
                        }\
                    };\
    // Alice patch end 0034\
' "$path9"

sed -i '/^            mCurrentInsetSupplier\.addSyncObserverAndPostIfNonNull(mInsetObserver);$/a\
            // Alice patch start 0034\
            attachAliceImeAnimationListener(window);\
            // Alice patch end 0034' "$path9"

sed -i '/^                            mCurrentInsetSupplier\.removeObserver(mInsetObserver);$/a\
                            // Alice patch start 0034\
                            detachAliceImeAnimationListener();\
                            // Alice patch end 0034' "$path9"

sed -i '/^                        if (window != null) {$/a\
                            // Alice patch start 0034\
                            attachAliceImeAnimationListener(window);\
                            // Alice patch end 0034' "$path9"

sed -i '/^                    public void onShown(Tab tab, int type) {$/a\
                        // Alice patch start 0034\
                        WindowAndroid window = mTab.getWindowAndroid();\
                        if (window != null) attachAliceImeAnimationListener(window);\
                        attachAliceWebContentsObserver();\
                        // Alice patch end 0034' "$path9"

sed -i '/^    private void updateVisualViewportBottomInset() {$/a\
        // Alice patch start 0034\
        if (mAliceImeAnimationActive) return;\
        // Alice patch end 0034\
' "$path9"

sed -i '/^        if (inset == mVisualViewportInsetBottomPx) return;$/,/^        mTab\.getWebContents()\.getRenderWidgetHostView()\.onViewportInsetBottomChanged();$/c\
        // Alice patch start 0034\
        if (shouldManageImeInVisualViewport()) {\
            WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(getContentView());\
            int imeHeight =\
                    insets == null ? 0 : getAliceKeyboardHeight(insets);\
            if (imeHeight == 0\
                    \&\& insets != null\
                    \&\& insets.isVisible(WindowInsetsCompat.Type.ime())) {\
                imeHeight = mAliceLastImeHeightPx;\
            }\
            updateImeViewportTranslation(imeHeight);\
            setVisualViewportBottomInset(0);\
        } else {\
            setVisualViewportBottomInset(inset);\
        }\
        // Alice patch end 0034' "$path9"

sed -i '/^    \/\*\* Sets the Visual Viewport bottom inset\. \*\/$/i\
    // Alice patch start 0034\
    private void attachAliceImeAnimationListener(WindowAndroid window) {\
        if (isDestroyed()) return;\
        InsetObserver observer = window.getInsetObserver();\
        if (observer == null || observer == mAliceImeInsetObserver) return;\
        detachAliceImeAnimationListener();\
        mAliceImeInsetObserver = observer;\
        mAliceImeInsetObserver.addWindowInsetsAnimationListener(\
                mAliceImeAnimationListener);\
        if (mAliceImeWindowAndroid != window) {\
            if (mAliceImeWindowAndroid != null) {\
                mAliceImeWindowAndroid.removeActivityStateObserver(\
                        mAliceActivityStateObserver);\
            }\
            mAliceImeWindowAndroid = window;\
            mAliceImeWindowAndroid.addActivityStateObserver(\
                    mAliceActivityStateObserver);\
        }\
    }\
\
    private boolean shouldManageImeInVisualViewport() {\
        if (mTab.isHidden()) return false;\
        if (!getContentView().isAttachedToWindow()) return false;\
        WindowAndroid window = mTab.getWindowAndroid();\
        if (window == null) return false;\
        @Nullable MonotonicObservableSupplier<EphemeralTabCoordinator> previewSupplier =\
                EphemeralTabCoordinatorSupplier.from(window);\
        @Nullable EphemeralTabCoordinator preview =\
                previewSupplier == null ? null : previewSupplier.get();\
        if (preview != null \&\& preview.isOpened()) return false;\
        Activity activity = window.getActivity().get();\
        if (activity == null || !window.isTopResumedActivity()) return false;\
        int adjustMode =\
                activity.getWindow().getAttributes().softInputMode\
                        \& WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST;\
        return adjustMode == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING;\
    }\
\
    private void detachAliceImeAnimationListener() {\
        if (mAliceImeInsetObserver != null) {\
            mAliceImeInsetObserver.removeWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
            mAliceImeInsetObserver = null;\
        }\
        if (mAliceImeWindowAndroid != null) {\
            mAliceImeWindowAndroid.removeActivityStateObserver(\
                    mAliceActivityStateObserver);\
            mAliceImeWindowAndroid = null;\
        }\
        mAliceImeAnimationActive = false;\
        resetAliceImeViewportTranslation();\
    }\
\
    private int getAliceKeyboardHeight(WindowInsetsCompat insets) {\
        return insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;\
    }\
\
    private void attachAliceWebContentsObserver() {\
        @Nullable WebContents webContents = mTab.getWebContents();\
        if (webContents == null\
                || (mAliceWebContentsObserver != null\
                        \&\& mAliceWebContentsObserver.getWebContents() == webContents)) {\
            return;\
        }\
        if (mAliceWebContentsObserver != null) mAliceWebContentsObserver.observe(null);\
        mAliceWebContentsObserver =\
                new WebContentsObserver(webContents) {\
                    @Override\
                    public void onWebContentsLostFocus() {\
                        mAliceLiftForFocusedInput = false;\
                        if (!isDestroyed()) {\
                            updateImeViewportTranslation(mAliceLastImeHeightPx);\
                        }\
                    }\
\
                    @Override\
                    public void onWebContentsFocused() {\
                        if (!isDestroyed()) updateVisualViewportBottomInset();\
                    }\
                };\
    }\
\
    private int getAliceFocusedNodeBottomPx() {\
        if (mTab.getWebContents() == null) return 0;\
        @Nullable ImeAdapter imeAdapter = ImeAdapter.fromWebContents(mTab.getWebContents());\
        return imeAdapter == null ? 0 : imeAdapter.getFocusedNodeBottomPx();\
    }\
\
    private int getAliceRootBottomPx() {\
        View rootView = getContentView().getRootView();\
        rootView.getLocationOnScreen(mAliceTmpLocation);\
        return mAliceTmpLocation[1] + rootView.getHeight();\
    }\
\
    private int getAliceBottomChromeHeightPx() {\
        View contentView = getContentView();\
        View rootView = contentView.getRootView();\
        View bottomControls = rootView.findViewById(R.id.control_container);\
        if (bottomControls != null) {\
            int rootBottom = getAliceRootBottomPx();\
            bottomControls.getLocationOnScreen(mAliceTmpLocation);\
            return Math.max(0, rootBottom - mAliceTmpLocation[1]);\
        }\
\
        int toolbarHeight =\
                contentView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
        int hairlineHeight =\
                contentView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(contentView);\
        int navigationBarHeight =\
                insets == null\
                        ? 0\
                        : insets.getInsets(\
                                        WindowInsetsCompat.Type.navigationBars())\
                                .bottom;\
        return toolbarHeight + hairlineHeight + navigationBarHeight;\
    }\
\
    private void updateImeViewportTranslation(int imeHeightPx) {\
        if (isDestroyed()) return;\
        int viewportInsetPx =\
                mAliceLiftForFocusedInput\
                        ? Math.max(\
                                0, imeHeightPx - getAliceBottomChromeHeightPx())\
                        : 0;\
        if (mTab.getWebContents() == null) return;\
        mTab.getWebContents().setImeViewportTranslation(viewportInsetPx);\
    }\
\
    private void resetAliceImeViewportTranslation() {\
        mAliceImeAnimationActive = false;\
        mAliceLiftForFocusedInput = false;\
        mAliceLastImeHeightPx = 0;\
        if (mTab.getWebContents() != null) {\
            mTab.getWebContents().setImeViewportTranslation(0);\
        }\
        setVisualViewportBottomInset(0);\
    }\
\
    private void setVisualViewportBottomInset(int inset) {\
        if (inset == mVisualViewportInsetBottomPx) return;\
        mVisualViewportInsetBottomPx = inset;\
        if (mTab.getWebContents() == null\
                || mTab.getWebContents().getRenderWidgetHostView() == null) {\
            return;\
        }\
        mTab.getWebContents().getRenderWidgetHostView().onViewportInsetBottomChanged();\
    }\
    // Alice patch end 0034\
\
' "$path9"

sed -i '/^            mCurrentInsetSupplier\.removeObserver(mInsetObserver);$/a\
            // Alice patch start 0034\
            detachAliceImeAnimationListener();\
            // Alice patch end 0034' "$path9"

if ! grep -q 'Unregister the WebContents focus gate' "$path9"; then
sed -i '/^            mTabObserver = null;$/a\
        // Alice patch start 0034\
        // Unregister the WebContents focus gate.\
        if (mAliceWebContentsObserver != null) {\
            mAliceWebContentsObserver.observe(null);\
            mAliceWebContentsObserver = null;\
        }\
        // Alice patch end 0034' "$path9"
fi
fi

# 22) 拦截原有焦点滚动。实际 IME 跟随由 compositor visual viewport pan 完成。
if ! grep -q 'if (adjustMode == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING) {' "$path21"; then
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0034\
import android.app.Activity;\
// Alice patch end 0034' "$path21"

sed -i '/^import android\.view\.ViewStructure;$/a\
// Alice patch start 0034\
import android.view.WindowManager;\
// Alice patch end 0034' "$path21"

sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/a\
        // Alice patch start 0034\
        WindowAndroid window = getTopLevelNativeWindow();\
        Activity activity = window == null ? null : window.getActivity().get();\
        if (activity != null) {\
            int adjustMode =\
                    activity.getWindow().getAttributes().softInputMode\
                            \& WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST;\
            if (adjustMode == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING) {\
                return;\
            }\
        }\
        // Alice patch end 0034\
' "$path21"
fi

# 23) 将 IME 逐帧位移投递到 compositor 线程，只 pan visual viewport。
#     不进入 Blink scroll/layout，也不平移 Android ContentView。
if ! grep -q 'SetImeViewportTranslation(float translation_y)' "$path13"; then
sed -i '/^#include "services\/metrics\/public\/cpp\/ukm_source_id.h"$/a\
// Alice patch start 0034\
#include "ui/gfx/geometry/vector2d_f.h"\
// Alice patch end 0034' "$path13"
sed -i '/^  virtual void SetNeedsRedraw(const gfx::Rect& damage_rect) = 0;$/a\
  // Alice patch start 0034\
  virtual void SetImeViewportTranslation(float translation_y) = 0;\
  // Alice patch end 0034' "$path13"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y);' "$path14"; then
sed -i '/^#include "ui\/gfx\/geometry\/rect.h"$/a\
// Alice patch start 0034\
#include "ui/gfx/geometry/vector2d_f.h"\
// Alice patch end 0034' "$path14"
sed -i '/^  bool HasPendingPageScaleAnimation() const;$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0034' "$path14"
fi

if ! grep -q 'void LayerTreeHost::SetImeViewportTranslation' "$path15"; then
sed -i '/^bool LayerTreeHost::HasPendingPageScaleAnimation() const {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void LayerTreeHost::SetImeViewportTranslation(float translation_y) {\
  DCHECK(IsMainThread());\
  proxy()->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0034
;}' "$path15"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y) override;' "$path16"; then
sed -i '/^  void SetNeedsRedraw(const gfx::Rect& damage_rect) override;$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y) override;\
  // Alice patch end 0034' "$path16"
fi

if ! grep -q 'void ProxyMain::SetImeViewportTranslation' "$path17"; then
sed -i '/^void ProxyMain::SetNeedsRedraw(const gfx::Rect& damage_rect) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void ProxyMain::SetImeViewportTranslation(float translation_y) {\
  DCHECK(IsMainThread());\
  ImplThreadTaskRunner()->PostTask(\
      FROM_HERE,\
      base::BindOnce(\&ProxyImpl::SetImeViewportTranslationOnImpl,\
                     base::Unretained(proxy_impl_.get()), translation_y));\
}\
// Alice patch end 0034
;}' "$path17"
fi

if ! grep -q 'void SetImeViewportTranslationOnImpl' "$path18"; then
sed -i '/^#include "cc\/trees\/layer_tree_host_impl_delegate.h"$/a\
// Alice patch start 0034\
#include "ui/gfx/geometry/vector2d_f.h"\
// Alice patch end 0034' "$path18"
sed -i '/^  void SetNeedsRedrawOnImpl(const gfx::Rect& damage_rect);$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslationOnImpl(float translation_y);\
  // Alice patch end 0034' "$path18"
fi

if ! grep -q '#include "cc/layers/viewport.h"' "$path19"; then
sed -i '/^#include "cc\/input\/browser_controls_offset_tag_modifications.h"$/a\
// Alice patch start 0034\
#include "cc/layers/viewport.h"\
// Alice patch end 0034' "$path19"
fi

if ! grep -q 'void ProxyImpl::SetImeViewportTranslationOnImpl' "$path19"; then
sed -i '/^void ProxyImpl::SetNeedsRedrawOnImpl(const gfx::Rect& damage_rect) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void ProxyImpl::SetImeViewportTranslationOnImpl(float translation_y) {\
  DCHECK(IsImplThread());\
  host_impl_->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0034
;}' "$path19"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y) override;' "$path20"; then
sed -i '/^  void SetNeedsRedraw(const gfx::Rect& damage_rect) override;$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y) override;\
  // Alice patch end 0034' "$path20"
fi

if ! grep -q '#include "cc/layers/viewport.h"' "$path22"; then
sed -i '/^#include "cc\/input\/browser_controls_offset_tag_modifications.h"$/a\
// Alice patch start 0034\
#include "cc/layers/viewport.h"\
// Alice patch end 0034' "$path22"
fi

if ! grep -q 'void SingleThreadProxy::SetImeViewportTranslation' "$path22"; then
sed -i '/^void SingleThreadProxy::SetNeedsRedraw(const gfx::Rect& damage_rect) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void SingleThreadProxy::SetImeViewportTranslation(float translation_y) {\
  DCHECK(task_runner_provider_->IsMainThread());\
  if (!host_impl_)\
    return;\
  DebugScopedSetImplThread impl(task_runner_provider_);\
  host_impl_->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0034
;}' "$path22"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y) override {}' "$path23"; then
sed -i '/^  void SetNeedsRedraw(const gfx::Rect& damage_rect) override {}$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y) override {}\
  // Alice patch end 0034' "$path23"
fi

if ! grep -q 'SetImeViewportTranslation(float translation_y);' "$path24"; then
sed -i '/^  ScrollFocusedEditableNodeIntoView();$/a\
\
  // Alice patch start 0034\
  // Sets a compositor-only IME viewport translation in physical pixels.\
  SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0034' "$path24"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y) override;' "$path25"; then
sed -i '/^  void ScrollFocusedEditableNodeIntoView() override;$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y) override;\
  // Alice patch end 0034' "$path25"
fi

if ! grep -q 'void FrameWidgetInputHandlerImpl::SetImeViewportTranslation' "$path26"; then
sed -i '/^void FrameWidgetInputHandlerImpl::ScrollFocusedEditableNodeIntoView() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void FrameWidgetInputHandlerImpl::SetImeViewportTranslation(\
    float translation_y) {\
  RunOnMainThread(base::BindOnce(\
      [](base::WeakPtr<mojom::blink::FrameWidgetInputHandler> handler,\
         float translation) {\
        if (handler)\
          handler->SetImeViewportTranslation(translation);\
      },\
      main_thread_frame_widget_input_handler_, translation_y));\
}\
// Alice patch end 0034
;}' "$path26"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y) override;' "$path27"; then
sed -i '/^  void ScrollFocusedEditableNodeIntoView() override;$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y) override;\
  // Alice patch end 0034' "$path27"
fi

if ! grep -q 'void WebFrameWidgetImpl::SetImeViewportTranslation' "$path28"; then
sed -i '/^void WebFrameWidgetImpl::ScrollFocusedEditableNodeIntoView() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void WebFrameWidgetImpl::SetImeViewportTranslation(float translation_y) {\
  if (!ForMainFrame())\
    return;\
  LayerTreeHost()->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0034
;}' "$path28"
fi

if ! grep -q 'default void setImeViewportTranslation(' "$path31"; then
sed -i '/^    void scrollFocusedEditableNodeIntoView();$/a\
    // Alice patch start 0034\
    /** Sets the Blink visual viewport IME translation in device-independent pixels. */\
    default void setImeViewportTranslation(float translationY) {}\
    // Alice patch end 0034' "$path31"
fi

if ! grep -q '^    public void setImeViewportTranslation(' "$path21"; then
sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/,/^    }$/{/^    }$/a\
\
    // Alice patch start 0034\
    @Override\
    public void setImeViewportTranslation(float translationY) {\
        checkNotDestroyed();\
        WebContentsImplJni.get()\
                .setImeViewportTranslation(\
                        mNativeWebContentsAndroid, translationY);\
    }\
    // Alice patch end 0034
;}' "$path21"
fi

if ! grep -q '^        void setImeViewportTranslation(' "$path21"; then
sed -i '/^        void scrollFocusedEditableNodeIntoView(long nativeWebContentsAndroid);$/a\
\
        // Alice patch start 0034\
        void setImeViewportTranslation(\
                long nativeWebContentsAndroid, float translationY);\
        // Alice patch end 0034' "$path21"
fi

if ! grep -q '^  void SetImeViewportTranslation(JNIEnv\* env,' "$path29"; then
sed -i '/^  void ScrollFocusedEditableNodeIntoView(JNIEnv\* env);$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(JNIEnv* env, jfloat translation_y);\
  // Alice patch end 0034' "$path29"
fi

if ! grep -q 'void WebContentsAndroid::SetImeViewportTranslation' "$path30"; then
sed -i '/^void WebContentsAndroid::ScrollFocusedEditableNodeIntoView(JNIEnv\* env) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void WebContentsAndroid::SetImeViewportTranslation(JNIEnv* env,\
                                                   jfloat translation_y) {\
  auto* input_handler = web_contents_->GetFocusedFrameWidgetInputHandler();\
  if (input_handler)\
    input_handler->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0034
;}' "$path30"
fi

if ! grep -q '#include "content/browser/renderer_host/render_widget_host_impl.h"' "$path30"; then
sed -i '/^#include "content\/browser\/renderer_host\/render_view_host_impl.h"$/a\
// Alice patch start 0034\
#include "content/browser/renderer_host/render_widget_host_impl.h"\
// Alice patch end 0034' "$path30"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y);' "$path32"; then
sed -i '/^  const gfx::Transform& DrawTransform() const;$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0034' "$path32"
sed -i '/^  gfx::Rect viewport_rect_for_tile_priority_;$/a\
  // Alice patch start 0034\
  float ime_viewport_translation_ = 0.f;\
  // Alice patch end 0034' "$path32"
fi

if ! grep -q 'void LayerTreeHostImpl::SetImeViewportTranslation' "$path33"; then
sed -i '/^const gfx::Transform& LayerTreeHostImpl::DrawTransform() const {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void LayerTreeHostImpl::SetImeViewportTranslation(float translation_y) {\
  ime_viewport_translation_ = translation_y;\
  viewport().SetInnerViewportOffsetUnclamped(translation_y);\
  SetFullViewportDamage();\
  SetNeedsRedraw(/*animation_only=*/false,\
                 /*skip_if_inside_draw=*/false);\
  SetNeedsOneBeginImplFrame();\
}\
// Alice patch end 0034
;}' "$path33"
fi

if ! grep -q 'Reapply the IME viewport offset after tree activation' "$path33"; then
sed -i '/^  active_tree_->DidBecomeActive();$/i\
  // Alice patch start 0034\
  // Reapply the IME viewport offset after tree activation.\
  if (ime_viewport_translation_ != 0.f) {\
    viewport().SetInnerViewportOffsetUnclamped(ime_viewport_translation_);\
  }\
  // Alice patch end 0034' "$path33"
fi

if ! grep -q 'Reapply the compositor-only IME offset before draw-property updates' "$path33"; then
sed -i '/^  mutator_host_->TickWorkletAnimations();$/a\
\
  // Alice patch start 0034\
  // Reapply the compositor-only IME offset before draw-property updates.\
  if (ime_viewport_translation_ != 0.f) {\
    viewport().SetInnerViewportOffsetUnclamped(ime_viewport_translation_);\
    SetFullViewportDamage();\
  }\
  // Alice patch end 0034' "$path33"
fi

if ! grep -q 'cc::slim::SurfaceLayer\* content_layer()' "$path34"; then
sed -i '/^  const cc::slim::SurfaceLayer\* content_layer() const {$/,/^  }$/ {\
    /^  }$/a\
  // Alice patch start 0034\
  cc::slim::SurfaceLayer* content_layer() { return content_layer_.get(); }\
  // Alice patch end 0034
;}' "$path34"
fi

if ! grep -q 'void SetImeViewportTranslation(float translation_y);' "$path35"; then
sed -i '/^  void SetNeedsBeginFrameForFlingProgress();$/a\
  // Alice patch start 0034\
  void SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0034' "$path35"
fi

if ! grep -q 'float ime_viewport_translation_y_' "$path35"; then
sed -i '/^  float page_scale_;$/a\
  // Alice patch start 0034\
  float ime_viewport_translation_y_ = 0.f;\
  // Alice patch end 0034' "$path35"
fi

if ! grep -q 'getFocusedNodeBottomPx' "$path42"; then
sed -i '/^    boolean focusedNodeEditable();$/a\
\
    // Alice patch start 0034\
    /** Returns the focused editable node bottom edge in screen pixels, or 0 if unfocused. */\
    int getFocusedNodeBottomPx();\
    // Alice patch end 0034' "$path42"
fi

if ! grep -q 'mFocusedNodeBottomPx' "$path43"; then
sed -i '/^    private boolean mNodePassword;$/a\
    // Alice patch start 0034\
    private boolean mFocusedNodeEditable;\
    private int mFocusedNodeBottomPx;\
    // Alice patch end 0034' "$path43"

sed -i '/^        if (DEBUG_LOGS) Log.i(TAG, "focusedNodeChanged: isEditable \[%b\]", isEditable);$/a\
        // Alice patch start 0034\
        mFocusedNodeEditable = isEditable;\
        mFocusedNodeBottomPx =\
                isEditable\
                        ? Math.round(\
                                nodeBottomDip\
                                        * mWebContents\
                                                .getRenderCoordinates()\
                                                .getDeviceScaleFactor())\
                        : 0;\
        // Alice patch end 0034' "$path43"

sed -i '/^    \/\*package\*\/ void focusedNodeChanged($/,/^    }$/{\
    /^    }$/a\
\
    // Alice patch start 0034\
    @Override\
    public int getFocusedNodeBottomPx() {\
        return mFocusedNodeEditable ? mFocusedNodeBottomPx : 0;\
    }\
    // Alice patch end 0034\
}' "$path43"
fi

if ! grep -q 'void RenderWidgetHostViewAndroid::SetImeViewportTranslation' "$path36"; then
sed -i '/^void RenderWidgetHostViewAndroid::SetNeedsBeginFrameForFlingProgress() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void RenderWidgetHostViewAndroid::SetImeViewportTranslation(\
    float translation_y) {\
  SetImeViewportTouchTranslation(translation_y);\
  if (!delegated_frame_host_)\
    return;\
  auto* layer = delegated_frame_host_->content_layer();\
  if (layer) {\
    layer->SetTransform(gfx::Transform::MakeTranslation(0, -translation_y));\
    SetNeedsAnimate();\
  }\
}\
// Alice patch end 0034
;}' "$path36"
fi

if ! grep -q 'void SetImeViewportTouchTranslation(float translation_y);' "$path35"; then
sed -i '/^  void SetImeViewportTranslation(float translation_y);$/a\
  // Alice patch start 0034\
  void SetImeViewportTouchTranslation(float translation_y);\
  // Alice patch end 0034' "$path35"
fi

if ! grep -q 'void RenderWidgetHostViewAndroid::SetImeViewportTouchTranslation' "$path36"; then
sed -i '/^void RenderWidgetHostViewAndroid::SetImeViewportTranslation($/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void RenderWidgetHostViewAndroid::SetImeViewportTouchTranslation(\
    float translation_y) {\
  const float scale = GetDeviceScaleFactor();\
  ime_viewport_translation_y_ =\
      scale > 0.f ? translation_y / scale : translation_y;\
}\
// Alice patch end 0034
;}' "$path36"
fi

if ! grep -q 'rwhva->SetImeViewportTouchTranslation' "$path30"; then
sed -i '/^void WebContentsAndroid::SetImeViewportTranslation(JNIEnv\* env,$/,/^}$/{/^  auto\* input_handler = web_contents_->GetFocusedFrameWidgetInputHandler();$/i\
  // Alice patch start 0034\
  if (auto* rwhva = GetRenderWidgetHostViewAndroid())\
    rwhva->SetImeViewportTouchTranslation(translation_y);\
  // Alice patch end 0034
;}' "$path30"
fi

if ! grep -q 'adjusted_event' "$path36"; then
sed -i 's|^bool RenderWidgetHostViewAndroid::OnTouchEvent($|bool RenderWidgetHostViewAndroid::OnTouchEvent(\
    const ui::MotionEventAndroid\& original_event) {|' "$path36"
sed -i '/^    const ui::MotionEventAndroid\& event) {$/d' "$path36"
sed -i '/^    const ui::MotionEventAndroid\& original_event) {$/a\
  // Alice patch start 0034\
  std::unique_ptr<ui::MotionEventAndroid> adjusted_event;\
  if (ime_viewport_translation_y_ != 0.f) {\
    adjusted_event = original_event.CreateFor(\
        gfx::PointF(original_event.GetX(0),\
                    original_event.GetY(0) + ime_viewport_translation_y_));\
  }\
  const ui::MotionEventAndroid\& event =\
      adjusted_event ? *adjusted_event : original_event;\
  // Alice patch end 0034' "$path36"
fi

if ! grep -q '#include "ui/gfx/geometry/transform.h"' "$path36"; then
sed -i '/^#include "ui\/gfx\/geometry\/size_conversions.h"$/a\
// Alice patch start 0034\
#include "ui/gfx/geometry/transform.h"\
// Alice patch end 0034' "$path36"
fi

if ! grep -q 'scrollFocusedEditableNodeIntoViewForIme' "$path31"; then
sed -i '/^    void scrollFocusedEditableNodeIntoView();$/a\
    // Alice patch start 0034\
    /** Scrolls the focused editable node for an IME animation frame. */\
    default void scrollFocusedEditableNodeIntoViewForIme() {}\
    // Alice patch end 0034' "$path31"
fi

if ! grep -q '^    public void scrollFocusedEditableNodeIntoViewForIme()' "$path21"; then
sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/,/^    }$/{/^    }$/a\
\
    // Alice patch start 0034\
    @Override\
    public void scrollFocusedEditableNodeIntoViewForIme() {\
        checkNotDestroyed();\
        WebContentsImplJni.get().scrollFocusedEditableNodeIntoView(\
                mNativeWebContentsAndroid);\
    }\
    // Alice patch end 0034
;}' "$path21"
fi

if ! grep -q \
        'Focus scrolling is driven by Android IME visual viewport animation.' "$path37"; then
sed -i '/^static constexpr base::TimeDelta kScrollAndScaleAnimationDuration =$/,/^    base::Milliseconds(200);$/c\
// Alice patch start 0034\
// Focus scrolling is driven by Android IME visual viewport animation.\
// Alice patch end 0034' "$path37"
fi

if ! grep -q 'Android IME animation owns focused-editable positioning' "$path37"; then
sed -i '/^  if (need_animation) {$/,/^  }$/c\
  if (need_animation) {\
    // Alice patch start 0034\
    // Android IME animation owns focused-editable positioning.\
    // Alice patch end 0034\
  }' "$path37"
fi

if ! grep -q 'void SetImeScrollOffset(float offset_y);' "$path38"; then
sed -i '/^  void SetLocation($/,/^      mojom::blink::ScrollType = mojom::blink::ScrollType::kProgrammatic);$/ {\
    /^      mojom::blink::ScrollType = mojom::blink::ScrollType::kProgrammatic);$/a\
  // Alice patch start 0034\
  void SetImeScrollOffset(float offset_y);\
  // Alice patch end 0034
;}' "$path38"
fi

if ! grep -q 'void VisualViewport::SetImeScrollOffset' "$path39"; then
sed -i '/^void VisualViewport::SetLocation(const gfx::PointF\& new_location,$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void VisualViewport::SetImeScrollOffset(float offset_y) {\
  if (!IsActiveViewport() || !std::isfinite(offset_y)) {\
    return;\
  }\
\
  ScrollOffset new_offset(0, offset_y);\
  if (new_offset == offset_) {\
    return;\
  }\
\
  DCHECK(LocalMainFrame().View());\
  offset_ = new_offset;\
  GetScrollAnimator().SetCurrentOffset(offset_);\
  if (auto* coordinator = GetPage().GetScrollingCoordinator()) {\
    if (scroll_layer_)\
      coordinator->UpdateCompositorScrollOffset(LocalMainFrame(), *this);\
  }\
  EnqueueScrollEvent();\
  LocalMainFrame().View()->DidChangeScrollOffset(\
      mojom::blink::ScrollType::kProgrammatic);\
  NotifyRootFrameViewport();\
  LocalMainFrame().Loader().SaveScrollState();\
  needs_paint_property_update_ = true;\
  LocalMainFrame().View()->SetVisualViewportOrOverlayNeedsRepaint();\
  ScheduleAnimation();\
}\
// Alice patch end 0034
;}' "$path39"
fi

if ! grep -q 'void SetInnerViewportOffsetUnclamped(float offset_y);' "$path40"; then
sed -i '/^  void Pan(const gfx::Vector2dF\& delta);$/a\
\
  // Alice patch start 0034\
  // Sets the inner visual viewport Y offset without applying scroll limits.\
  void SetInnerViewportOffsetUnclamped(float offset_y);\
  // Alice patch end 0034' "$path40"
fi

if ! grep -q 'void Viewport::SetInnerViewportOffsetUnclamped' "$path41"; then
sed -i '/^void Viewport::Pan(const gfx::Vector2dF\& delta) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0034\
void Viewport::SetInnerViewportOffsetUnclamped(float offset_y) {\
  ScrollNode* scroll_node = InnerScrollNode();\
  if (!scroll_node)\
    return;\
\
  float page_scale =\
      host_impl_->active_tree()->current_page_scale_factor();\
  if (page_scale <= 0.f)\
    return;\
\
  ScrollTree\& tree = scroll_tree();\
  gfx::PointF new_offset(0.f, offset_y / page_scale);\
  if (tree.SetScrollOffset(scroll_node->element_id, new_offset)) {\
    host_impl_->active_tree()->DidUpdateScrollOffset(\
        scroll_node->element_id,\
        /*pushed_from_main_or_pending_tree=*/false);\
  }\
}\
// Alice patch end 0034
;}' "$path41"
fi
