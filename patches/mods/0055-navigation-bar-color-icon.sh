#!/bin/bash
# 底部导航栏颜色和图标：工具栏颜色同步、透明系统栏、TaskDescription 导航栏色。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedNavigationBarColorController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedSystemUiCoordinator.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedRootUiCoordinator.java"
path4="ui/edge_to_edge/android/java/src/org/chromium/ui/edge_to_edge/EdgeToEdgeSystemBarColorHelper.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarControlContainer.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/ChromeBaseAppCompatActivity.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/ui/system/StatusBarColorController.java"
path8="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/BottomAttachedUiObserver.java"

# 检测是否已应用
if grep -q 'Alice patch start 0055' "$path1"; then
    exit 100
fi

# 导航栏颜色控制器增加工具栏位置观察和临时工具栏颜色来源。
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsStateProvider;$/a\
// Alice patch start 0055\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
// Alice patch end 0055' "$path1"
sed -i '/^import org\.chromium\.ui\.util\.ColorUtils;$/a\
// Alice patch start 0055\
import java.util.function.Supplier;\
// Alice patch end 0055' "$path1"
sed -i '/^        implements BottomAttachedUiObserver\.Observer, NavigationBarColorProvider {$/c\
        // Alice patch start 0055\
        implements BottomAttachedUiObserver.Observer, NavigationBarColorProvider,\
                BrowserControlsStateProvider.Observer {\
        // Alice patch end 0055' "$path1"
sed -i '/^    private final BottomAttachedUiObserver mBottomAttachedUiObserver;$/a\
    // Alice patch start 0055\
    private @Nullable BrowserControlsStateProvider mBrowserControlsStateProvider;\
    private @Nullable Supplier<Integer> mToolbarColorSupplier;\
    private @Nullable @ColorInt Integer mAliceToolbarColorOverride;\
    // Alice patch end 0055' "$path1"

# 底置工具栏颜色可能在 BottomAttachedUiObserver 计算 mUseBottomControlsColor
# 之前到达；此时仍应优先使用工具栏颜色，避免导航栏先读取页面背景色。
sed -i '/^        if (mUseBottomControlsColor) {$/,/^        }$/c\
        // Alice patch start 0055\
        if (mUseBottomControlsColor\
                || (mBottomControlsColor != null\
                        \&\& mBrowserControlsStateProvider.getControlsPosition()\
                                == ControlsPosition.BOTTOM)) {\
            return mBottomControlsColor;\
        }\
        // Alice patch end 0055' "$path8"

sed -i '/^    private @Nullable @ColorInt Integer calculateBottomAttachedColor() {$/i\
    // Alice patch start 0055\
    boolean isBottomToolbarAttached() {\
        return mBrowserControlsStateProvider.getControlsPosition()\
                        == ControlsPosition.BOTTOM\
                \&\& !mOmniboxSuggestionsVisible\
                \&\& !mKeyboardAccessoryVisible\
                \&\& !mAccessorySheetVisible\
                \&\& !mOverlayPanelVisible\
                \&\& !mBottomSheetVisible;\
    }\
    // Alice patch end 0055\
' "$path8"

sed -i '/^[[:space:]]*insetObserver));$/a\
        // Alice patch start 0055\
        mBrowserControlsStateProvider = browserControlsStateProvider;\
        mBrowserControlsStateProvider.addObserver(this);\
        updateNavigationBarColor();\
        // Alice patch end 0055' "$path1"
sed -i '/^    \/\*\* Destroy this {@link TabbedNavigationBarColorController} instance\. \*\/$/i\
    // Alice patch start 0055\
    void setToolbarColorSupplier(Supplier<Integer> toolbarColorSupplier) {\
        mToolbarColorSupplier = toolbarColorSupplier;\
        int toolbarColor = mToolbarColorSupplier.get();\
        if (toolbarColor != 0) {\
            mAliceToolbarColorOverride = toolbarColor;\
        }\
        updateNavigationBarColor();\
    }\
\
    void onToolbarColorChanged(int color) {\
        if (mAliceToolbarColorOverride != null && mAliceToolbarColorOverride == color) {\
            return;\
        }\
        mAliceToolbarColorOverride = color;\
        if (isBottomToolbar() \&\& isDrawingToEdge()) {\
            updateNavigationBarColor(\
                    /* forceShowDivider= */ false,\
                    /* disableAnimation= */ true);\
        }\
    }\
    // Alice patch end 0055\
' "$path1"
sed -i '/^        if (mTabModelSelector != null) {$/i\
        // Alice patch start 0055\
        if (mBrowserControlsStateProvider != null) {\
            mBrowserControlsStateProvider.removeObserver(this);\
            mBrowserControlsStateProvider = null;\
        }\
        // Alice patch end 0055\
' "$path1"
sed -i '/^        return ColorUtils\.overlayColor(color, mCurrentScrimColor);$/{
n
a\
\
    // Alice patch start 0055\
    @Override\
    public void onControlsPositionChanged(@ControlsPosition int controlsPosition) {\
        if (controlsPosition != ControlsPosition.BOTTOM) {\
            mAliceToolbarColorOverride = null;\
        }\
        updateNavigationBarColor();\
    }\
    // Alice patch end 0055
}' "$path1"
sed -i '/^                applyCurrentScrimToColor(getNavigationBarColor(mForceDarkNavigationBarColor));$/a\
        // Alice patch start 0055\
        mEdgeToEdgeSystemBarColorHelper.setNavigationBarIconColor(\
                applyCurrentScrimToColor(getNavigationBarIconColor()));\
        // Alice patch end 0055' "$path1"
sed -i '/^    private @ColorInt int getNavigationBarColor(boolean forceDarkNavigationBar) {$/i\
    // Alice patch start 0055\
    private boolean isDrawingToEdge() {\
        return mEdgeToEdgeController != null && mEdgeToEdgeController.isDrawingToEdge();\
    }\
\
    private boolean isBottomToolbar() {\
        return mBrowserControlsStateProvider != null\
                && mBrowserControlsStateProvider.getControlsPosition() == ControlsPosition.BOTTOM;\
    }\
\
    private boolean shouldUseAliceToolbarColorForBottomChin() {\
        return isDrawingToEdge()\
                \&\& isBottomToolbar()\
                \&\& mAliceToolbarColorOverride != null\
                \&\& mBottomAttachedUiObserver.isBottomToolbarAttached();\
    }\
\
    private @ColorInt int getNavigationBarIconColor() {\
        if (mOverviewMode) {\
            Integer overviewColor = mOverviewColorSupplier.get();\
            return overviewColor != null\
                    ? overviewColor\
                    : SemanticColorUtils.getColorSurface(mContext);\
        }\
        if (!isDrawingToEdge()) return getNavigationBarColor(mForceDarkNavigationBarColor);\
        if (isBottomToolbar() && mToolbarColorSupplier != null) {\
            int toolbarColor = mToolbarColorSupplier.get();\
            if (toolbarColor != 0) return toolbarColor;\
        }\
        if (mActiveTab != null) return mActiveTab.getBackgroundColor();\
        return SemanticColorUtils.getColorSurface(mContext);\
    }\
    // Alice patch end 0055\
' "$path1"

# 底置工具栏时，底部 chin 使用工具栏最终渲染色，而不是页面背景色。
sed -i 's|^        } else if (useBottomAttachedUiColor()) {$|        } else if (useBottomAttachedUiColor()\
                \&\& !shouldUseAliceToolbarColorForBottomChin()) {|' "$path1"
sed -i 's|^        } else if (!forceShowDivider && useBottomAttachedUiColor()) {$|        } else if (!forceShowDivider\
                \&\& useBottomAttachedUiColor()\
                \&\& !shouldUseAliceToolbarColorForBottomChin()) {|' "$path1"
sed -i 's|^        } else if (useActiveTabColor()) {$|        } else if (isDrawingToEdge()\
                \&\& isBottomToolbar()\
                \&\& mAliceToolbarColorOverride != null\
                \&\& mBottomAttachedUiObserver.isBottomToolbarAttached()) {\
            return mAliceToolbarColorOverride;\
        } else if (useActiveTabColor()) {|' "$path1"
sed -i 's|^        } else if (!forceShowDivider && useActiveTabColor()) {$|        } else if (!forceShowDivider\
                \&\& isDrawingToEdge()\
                \&\& isBottomToolbar()\
                \&\& mAliceToolbarColorOverride != null\
                \&\& mBottomAttachedUiObserver.isBottomToolbarAttached()) {\
            return mAliceToolbarColorOverride;\
        } else if (!forceShowDivider \&\& useActiveTabColor()) {|' "$path1"

# 系统栏协调器接收工具栏颜色来源并设置图标颜色。
sed -i '/^import org\.chromium\.ui\.insets\.InsetObserver;$/a\
// Alice patch start 0055\
import java.util.function.Supplier;\
// Alice patch end 0055' "$path2"
sed -i 's|^            InsetObserver insetObserver,$|            InsetObserver insetObserver,\n            // Alice patch start 0055\n            Supplier<Integer> toolbarColorSupplier,\n            // Alice patch end 0055|' "$path2"
sed -i '/^                        edgeToEdgeSystemBarColorHelper);$/a\
        // Alice patch start 0055\
        mNavigationBarColorController.setToolbarColorSupplier(toolbarColorSupplier);\
        // Alice patch end 0055' "$path2"
sed -i 's|^                        mEdgeToEdgeManager\.getEdgeToEdgeSystemBarColorHelper());$|                        // Alice patch start 0055\n                        toolbarManager::getToolbarBackgroundColorForNavigationBar,\n                        // Alice patch end 0055\n                        mEdgeToEdgeManager.getEdgeToEdgeSystemBarColorHelper());\n        // Alice patch start 0055\n        TabbedNavigationBarColorController aliceNavigationBarColorController =\n                assumeNonNull(mSystemUiCoordinator).getNavigationBarColorController();\n        if (aliceNavigationBarColorController != null) {\n            mStatusBarColorController.setAliceToolbarColorCallback(\n                    aliceNavigationBarColorController::onToolbarColorChanged);\n        }\n        // Alice patch end 0055|' "$path3"

# 系统栏 helper 支持自定义导航栏图标颜色。
sed -i '/^import android\.view\.WindowManager;$/a\
\
// Alice patch start 0055\
import androidx.annotation.ColorInt;\
// Alice patch end 0055' "$path4"
sed -i '/^    private final boolean mCanSetTransparentStatusBarWithoutDelegate;$/a\
    // Alice patch start 0055\
    private @ColorInt int mNavigationBarIconColor;\
    private boolean mHasCustomNavigationBarIconColor;\
    // Alice patch end 0055' "$path4"
sed -i 's|^        updateNavigationBarIconColor(mWindow\.getDecorView(), mNavBarColor);$|        // Alice patch start 0055\n        updateNavigationBarIconColor(\n                mWindow.getDecorView(),\n                mHasCustomNavigationBarIconColor ? mNavigationBarIconColor : mNavBarColor);\n        // Alice patch end 0055|' "$path4"
sed -i '/^    @Nullable SystemBarColorHelper getEdgeToEdgeDelegateHelperForTesting() {$/i\
    // Alice patch start 0055\
    public void setNavigationBarIconColor(@ColorInt int color) {\
        if (mHasCustomNavigationBarIconColor && mNavigationBarIconColor == color) return;\
        mNavigationBarIconColor = color;\
        mHasCustomNavigationBarIconColor = true;\
        updateNavigationBarIconColor(mWindow.getDecorView(), color);\
    }\
    // Alice patch end 0055\
' "$path4"

# ToolbarControlContainer 在 IME 动画期间也保持导航栏背景跟随工具栏颜色。
sed -i '/^    private void updateBackgroundColor() {$/a\
        // Alice patch start 0055\
        if (mToolbarDataProvider != null) {\
            setBackgroundColor(mToolbarDataProvider.getPrimaryColor());\
        }\
        // Alice patch end 0055\
' "$path5"

# TabbedRootUiCoordinator 维护底部 chin 的透明导航栏和图标颜色。
sed -i '/^import android\.graphics\.Color;$/a\
// Alice patch start 0055\
import android.graphics.drawable.ColorDrawable;\
// Alice patch end 0055' "$path3"
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BottomOverscrollHandler;$/a\
// Alice patch start 0055\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
// Alice patch end 0055' "$path3"
sed -i '/^    private @Nullable TabbedSystemUiCoordinator mSystemUiCoordinator;$/a\
    // Alice patch start 0055\
    private int mAliceTaskDescriptionNavColor = Integer.MIN_VALUE;\
    // Alice patch end 0055' "$path3"
sed -i '/^        mSystemBarColorHelperSupplier\.set(bottomChinColorHelper);$/a\
        // Alice patch start 0055\
        View aliceChinView = mActivity.findViewById(R.id.edge_to_edge_bottom_chin);\
        if (aliceChinView != null) {\
            mActivity.getWindow().setNavigationBarColor(Color.TRANSPARENT);\
            mAliceChinView = aliceChinView;\
            mAliceChinColorListener = () -> true;\
            aliceChinView\
                    .getViewTreeObserver()\
                    .addOnPreDrawListener(mAliceChinColorListener);\
        }\
        // Alice patch end 0055\
' "$path3"
sed -i '/^public class TabbedRootUiCoordinator extends RootUiCoordinator {$/a\
    // Alice patch start 0055\
    private @Nullable View mAliceChinView;\
    private android.view.ViewTreeObserver.@Nullable OnPreDrawListener mAliceChinColorListener;\
    // Alice patch end 0055' "$path3"
sed -i '/^    public void onDestroy() {$/a\
        // Alice patch start 0055\
        if (mAliceChinView != null \&\& mAliceChinColorListener != null) {\
            android.view.ViewTreeObserver aliceObserver =\
                    mAliceChinView.getViewTreeObserver();\
            if (aliceObserver.isAlive()) {\
                aliceObserver.removeOnPreDrawListener(mAliceChinColorListener);\
            }\
        }\
        mAliceChinView = null;\
        mAliceChinColorListener = null;\
        // Alice patch end 0055' "$path3"

# 状态栏已经接收工具栏最终颜色；同一回调栈直接把该颜色送到导航栏控制器。
sed -i '/^    private @ColorInt int mToolbarColor;$/a\
    // Alice patch start 0055\
    private @Nullable Callback<Integer> mAliceToolbarColorCallback;\
    // Alice patch end 0055' "$path7"
sed -i '/^    \/\/ TopToolbarCoordinator\.ToolbarColorObserver implementation\.$/i\
    // Alice patch start 0055\
    public void setAliceToolbarColorCallback(@Nullable Callback<Integer> callback) {\
        mAliceToolbarColorCallback = callback;\
    }\
    // Alice patch end 0055\
' "$path7"
sed -i '/^    public void onToolbarColorChanged(@ColorInt int color) {$/a\
        // Alice patch start 0055\
        if (mAliceToolbarColorCallback != null) {\
            mAliceToolbarColorCallback.onResult(color);\
        }\
        // Alice patch end 0055' "$path7"
sed -i '/^        mStatusBarColorTabObserver\.destroy();$/a\
        // Alice patch start 0055\
        mAliceToolbarColorCallback = null;\
        // Alice patch end 0055' "$path7"

# TaskDescription 显式携带透明导航栏色。
sed -i '/^    protected void setDefaultTaskDescription() {$/,/^    }$/c\
    protected void setDefaultTaskDescription() {\
        // Alice patch start 0055\
        int aliceDefaultTaskDescriptionColor =\
                getColor(R.color.default_task_description_color);\
        if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU) {\
            setTaskDescription(\
                    new TaskDescription.Builder()\
                            .setPrimaryColor(aliceDefaultTaskDescriptionColor)\
                            .setNavigationBarColor(android.graphics.Color.TRANSPARENT)\
                            .build());\
        } else {\
            setTaskDescription(\
                    new TaskDescription(null, null, aliceDefaultTaskDescriptionColor));\
        }\
        // Alice patch end 0055\
    }' "$path6"
sed -i 's|^        edgeToEdgeSystemBarColorHelper\.setNavigationBarColor(defaultNavigationBarColor);$|        // Alice patch start 0055\n        edgeToEdgeSystemBarColorHelper.setNavigationBarColor(android.graphics.Color.TRANSPARENT);\n        // Alice patch end 0055|' "$path6"
sed -i '/^                                \.setBackgroundColor(opaqueBgColor)$/a\
                                // Alice patch start 0055\
                                .setNavigationBarColor(android.graphics.Color.TRANSPARENT)\
                                // Alice patch end 0055' "$path7"
sed -i '/^                                \.setStatusBarColor(opaqueColor)$/a\
                                // Alice patch start 0055\
                                .setNavigationBarColor(android.graphics.Color.TRANSPARENT)\
                                // Alice patch end 0055' "$path7"
