#!/bin/bash
# IME 导航栏配色：输入法动画期间让系统导航栏颜色跟随底置工具栏。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedNavigationBarColorController.java"
path2="ui/edge_to_edge/android/java/src/org/chromium/ui/edge_to_edge/EdgeToEdgeSystemBarColorHelper.java"

# 检测是否已应用
if grep -q 'Alice patch start 0061' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 导航栏颜色控制器监听 IME 动画。
sed -i '/^import androidx\.annotation\.VisibleForTesting;$/a\
// Alice patch start 0061\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0061' "$path1"
sed -i '/^import org\.chromium\.ui\.util\.ColorUtils;$/a\
// Alice patch start 0061\
import java.util.List;\
// Alice patch end 0061' "$path1"
sed -i '/^    private @Nullable Supplier<Integer> mToolbarColorSupplier;$/a\
    // Alice patch start 0061\
    private @Nullable InsetObserver mAliceInsetObserver;\
    private final InsetObserver.WindowInsetsAnimationListener mAliceImeAnimationListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if ((animation.getTypeMask() \& WindowInsetsCompat.Type.ime()) != 0) {\
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
                    if ((animation.getTypeMask() \& WindowInsetsCompat.Type.ime()) != 0) {\
                        mEdgeToEdgeSystemBarColorHelper\
                                .refreshNavigationBarColorForIme();\
                        updateNavigationBarColor(\
                                /* forceShowDivider= */ false,\
                                /* disableAnimation= */ true);\
                    }\
                }\
            };\
    // Alice patch end 0061' "$path1"

# 注册和注销 IME 动画监听器。
sed -i '/^        mBrowserControlsStateProvider\.addObserver(this);$/a\
        // Alice patch start 0061\
        mAliceInsetObserver = insetObserver;\
        if (mAliceInsetObserver != null) {\
            mAliceInsetObserver.addWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
        }\
        // Alice patch end 0061' "$path1"
sed -i '/^            mBrowserControlsStateProvider\.removeObserver(this);$/a\
        // Alice patch start 0061\
        if (mAliceInsetObserver != null) {\
            mAliceInsetObserver.removeWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
            mAliceInsetObserver = null;\
        }\
        // Alice patch end 0061' "$path1"

# edge-to-edge helper 在 IME 可见时恢复实色导航栏。
sed -i '/^import androidx\.annotation\.ColorInt;$/a\
// Alice patch start 0061\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0061' "$path2"
sed -i '/^    private void updateNavBarColors() {$/i\
    // Alice patch start 0061\
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
    // Alice patch end 0061\
' "$path2"
sed -i '/^        int windowNavColor = mIsActivityEdgeToEdge ? Color\.TRANSPARENT : mNavBarColor;$/c\
        // Alice patch start 0061\
        boolean aliceImeVisible = isAliceImeVisible();\
        int windowNavColor =\
                aliceImeVisible ? mNavBarColor : Color.TRANSPARENT;\
        // Alice patch end 0061' "$path2"
sed -i '/^        int windowNavDividerColor = mIsActivityEdgeToEdge ? Color\.TRANSPARENT : mNavBarDividerColor;$/c\
        // Alice patch start 0061\
        int windowNavDividerColor =\
                aliceImeVisible ? mNavBarDividerColor : Color.TRANSPARENT;\
        // Alice patch end 0061' "$path2"
sed -i 's|^        mWindowColorHelper\.setNavigationBarContrastEnforced(!mIsActivityEdgeToEdge);$|        // Alice patch start 0061\n        mWindowColorHelper.setNavigationBarContrastEnforced(false);\n        // Alice patch end 0061|' "$path2"
sed -i '/^        mWindowColorHelper.setNavigationBarContrastEnforced(false);$/a\
        // Alice patch start 0061\
        if (aliceImeVisible) {\
            mWindow.clearFlags(\
                    android.view.WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);\
            mWindow.addFlags(\
                    android.view.WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);\
            mWindow.setNavigationBarColor(windowNavColor);\
            mWindow.setNavigationBarDividerColor(windowNavDividerColor);\
            mWindow.setNavigationBarContrastEnforced(false);\
        }\
        // Alice patch end 0061' "$path2"
