#!/bin/bash
# 撤销 Snackbar 与翻译气泡避让系统导航栏

set -e

# 目标文件路径
path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ui/RootUiCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0034' "$path1"; then
    exit 100
fi

# 1) SnackbarView 已经使用 ViewCompat，补充 WindowInsetsCompat 类型
sed -i '/^import androidx\.core\.view\.ViewCompat;$/a\
// Alice patch start 0034\
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
            if (isFullscreen) {\
                aliceBottomMargin +=\
                        Math.max(keyboardHeight, aliceNavigationBarHeight);\
            } else {\
                aliceBottomMargin = 0;\
            }\
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
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0034' "$path2"

sed -i '/^import org\.chromium\.components\.messages\.MessageContainer;$/a\
import org.chromium.ui.KeyboardVisibilityDelegate;' "$path2"

sed -i '/^import org\.chromium\.ui\.base\.ViewUtils;$/d' "$path2"

sed -i '/^public class MessageContainerCoordinator implements BrowserControlsStateProvider\.Observer {$/a\
    private final KeyboardVisibilityDelegate.KeyboardVisibilityListener\
            mAliceKeyboardVisibilityListener;\
' "$path2"

sed -i '/^        mContainer = container;$/a\
        mAliceKeyboardVisibilityListener =\
                (isShowing) -> {\
                    if (mContainer != null) updateMargins();\
                };\
        KeyboardVisibilityDelegate.getInstance()\
                .addKeyboardVisibilityListener(mAliceKeyboardVisibilityListener);\
' "$path2"

sed -i '/^        mControlsManager\.removeObserver(this);$/a\
        KeyboardVisibilityDelegate.getInstance()\
                .removeKeyboardVisibilityListener(mAliceKeyboardVisibilityListener);\
' "$path2"

sed -i '/^    public void onAnimationStart() {$/,/^    }$/c\
    public void onAnimationStart() {}' "$path2"

sed -i '/^    public void onAnimationEnd() {$/,/^    }$/c\
    public void onAnimationEnd() {}' "$path2"

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
            aliceBottomMargin = Math.round(2f * res.getDisplayMetrics().density);\
        } else {\
            aliceBottomMargin += aliceNavigationBarHeight;\
        }\
        params.bottomMargin = aliceBottomMargin;\
        // Alice patch end 0034' "$path2"

sed -i '/^import org\.chromium\.components\.messages\.MessageContainer;$/a\
import org.chromium.ui.KeyboardVisibilityDelegate;' "$path3"

sed -i '/^                        mWindowAndroid::startAnimationOverContent,$/c\
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
                        },' "$path3"
