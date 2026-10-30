#!/bin/bash
# 底部导航栏适配 + 标签管理页导航栏避让
#   1) 系统导航栏透明
#   2) 工具栏容器背景延伸
#   3) 设置页和标签管理页避让
#   4) Hub 布局保留底部 chin 高度
#   5) 标签管理页收缩/展开动画复用工具栏背景
#   6) 地址栏聚焦时隐藏错误的工具栏分割条
#   7) 地址栏聚焦遮罩仅覆盖搜索栏上方
#   8) 地址栏聚焦时抑制 compositor 工具栏残留层
#   9) 地址栏聚焦时搜索页背景逐帧吸附搜索框

set -e

# 目标文件路径
path1="chrome/browser/ui/android/edge_to_edge/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeUtils.java"
path2="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerImpl.java"
path3="chrome/browser/ui/android/edge_to_edge/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerCreator.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedNavigationBarColorController.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedSystemUiCoordinator.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedRootUiCoordinator.java"
path7="ui/edge_to_edge/android/java/src/org/chromium/ui/edge_to_edge/EdgeToEdgeSystemBarColorHelper.java"
path8="chrome/browser/browser_controls/android/java/src/org/chromium/chrome/browser/browser_controls/BottomControlsStacker.java"
path9="chrome/android/java/src/org/chromium/chrome/browser/settings/SettingsActivity.java"
path10="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneCoordinator.java"
path11="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeBottomChinMediator.java"
path12="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarControlContainer.java"
path13="chrome/android/java/src/org/chromium/chrome/browser/settings/MainSettings.java"
path14="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
path15="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path16="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path17="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"
path18="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path19="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path15="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path20="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"
path21="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
path22="chrome/android/java/src/org/chromium/chrome/browser/ChromeBaseAppCompatActivity.java"
path23="chrome/android/java/src/org/chromium/chrome/browser/ui/system/StatusBarColorController.java"
path24="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridDialogView.java"

# 检测是否已应用
if grep -q 'Alice patch start 0032' "$path1"; then
    exit 100
fi

# 1) 3 键导航也启用底部 edge-to-edge
sed -i '/^    public static boolean isEdgeToEdgeBottomChinEnabled(Activity activity) {$/,/^    }$/c\
    public static boolean isEdgeToEdgeBottomChinEnabled(Activity activity) {\
        // Alice patch start 0032\
        if (activity == null || activity.getWindow() == null) return false;\
        if (DeviceFormFactor.isNonMultiDisplayContextOnTablet(activity)\
                && (!isEdgeToEdgeTabletEnabled() || !isSupportedTablet(activity))) {\
            return false;\
        }\
        return !DeviceInfo.isAutomotive();\
        // Alice patch end 0032\
    }' "$path1"

sed -i '/^    static boolean isSupportedByConfiguration(/,/^    }$/c\
    static boolean isSupportedByConfiguration(Activity activity, InsetObserver insetObserver) {\
        // Alice patch start 0032\
        return EdgeToEdgeUtils.isEdgeToEdgeBottomChinEnabled(activity);\
        // Alice patch end 0032\
    }' "$path2"
sed -i '/^        \/\/ Exit early if there is a tappable navbar (3-button) as the controller should not function$/,/^        }$/d' "$path2"
sed -i '/^        boolean shouldDrawToEdge =$/,/^                        pageOptedIntoEdgeToEdge, currentLayoutType, mSystemInsets.bottom);$/c\
        // Alice patch start 0032\
        boolean shouldDrawToEdge =\
                !mActivity.isInMultiWindowMode()\
                        \&\& EdgeToEdgeUtils.shouldDrawToEdge(\
                                pageOptedIntoEdgeToEdge,\
                                currentLayoutType,\
                                mSystemInsets.bottom);\
        // Alice patch end 0032' "$path2"
sed -i '/^                && EdgeToEdgeUtils\.doAllInsetsIndicateGestureNavigation(insets)$/c\
// Alice patch start 0032\
// Removed the gesture-only configuration guard.\
// Alice patch end 0032' "$path3"

# 2) 导航栏透明 + 工具栏滑动透明 + 图标明暗
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsStateProvider;$/a\
// Alice patch start 0032\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
// Alice patch end 0032' "$path4"
sed -i '/^import org\.chromium\.ui\.util\.ColorUtils;$/a\
// Alice patch start 0032\
import java.util.function.Supplier;\
// Alice patch end 0032' "$path4"
sed -i '/^        implements BottomAttachedUiObserver\.Observer, NavigationBarColorProvider {$/c\
        // Alice patch start 0032\
        implements BottomAttachedUiObserver.Observer, NavigationBarColorProvider,\
                BrowserControlsStateProvider.Observer {\
        // Alice patch end 0032' "$path4"
sed -i '/^    private final BottomAttachedUiObserver mBottomAttachedUiObserver;$/a\
    // Alice patch start 0032\
    private @Nullable BrowserControlsStateProvider mBrowserControlsStateProvider;\
    private @Nullable Supplier<Integer> mToolbarColorSupplier;\
    // Alice patch end 0032' "$path4"
sed -i '/^[[:space:]]*insetObserver));$/a\
        // Alice patch start 0032\
        mBrowserControlsStateProvider = browserControlsStateProvider;\
        mBrowserControlsStateProvider.addObserver(this);\
        updateNavigationBarColor();\
        // Alice patch end 0032' "$path4"
sed -i '/^    \/\*\* Destroy this {@link TabbedNavigationBarColorController} instance\. \*\/$/i\
    // Alice patch start 0032\
    void setToolbarColorSupplier(Supplier<Integer> toolbarColorSupplier) {\
        mToolbarColorSupplier = toolbarColorSupplier;\
        updateNavigationBarColor();\
    }\
    // Alice patch end 0032\
' "$path4"
sed -i '/^        if (mTabModelSelector != null) {$/i\
        // Alice patch start 0032\
        if (mBrowserControlsStateProvider != null) {\
            mBrowserControlsStateProvider.removeObserver(this);\
            mBrowserControlsStateProvider = null;\
        }\
        // Alice patch end 0032\
' "$path4"
sed -i '/^        return ColorUtils\.overlayColor(color, mCurrentScrimColor);$/{
n
a\
\
    // Alice patch start 0032\
    @Override\
    public void onControlsPositionChanged(@ControlsPosition int controlsPosition) {\
        updateNavigationBarColor();\
    }\
    // Alice patch end 0032
}' "$path4"
sed -i '/^                applyCurrentScrimToColor(getNavigationBarColor(mForceDarkNavigationBarColor));$/a\
        // Alice patch start 0032\
        mEdgeToEdgeSystemBarColorHelper.setNavigationBarIconColor(\
                applyCurrentScrimToColor(getNavigationBarIconColor()));\
        // Alice patch end 0032' "$path4"
sed -i '/^    private @ColorInt int getNavigationBarColor(boolean forceDarkNavigationBar) {$/i\
    // Alice patch start 0032\
    private boolean isDrawingToEdge() {\
        return mEdgeToEdgeController != null && mEdgeToEdgeController.isDrawingToEdge();\
    }\
\
    private boolean isToolbarSwipe() {\
        return mLayoutManager != null\
                && mLayoutManager.getActiveLayoutType() == LayoutType.TOOLBAR_SWIPE;\
    }\
\
    private boolean isBottomToolbar() {\
        return mBrowserControlsStateProvider != null\
                && mBrowserControlsStateProvider.getControlsPosition() == ControlsPosition.BOTTOM;\
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
    // Alice patch end 0032\
' "$path4"
# 3) 系统栏 helper
sed -i '/^import org\.chromium\.ui\.insets\.InsetObserver;$/a\
// Alice patch start 0032\
import java.util.function.Supplier;\
// Alice patch end 0032' "$path5"
sed -i 's|^            InsetObserver insetObserver,$|            InsetObserver insetObserver,\n            // Alice patch start 0032\n            Supplier<Integer> toolbarColorSupplier,\n            // Alice patch end 0032|' "$path5"
sed -i '/^                        edgeToEdgeSystemBarColorHelper);$/a\
        // Alice patch start 0032\
        mNavigationBarColorController.setToolbarColorSupplier(toolbarColorSupplier);\
        // Alice patch end 0032' "$path5"
sed -i 's|^                        mEdgeToEdgeManager\.getEdgeToEdgeSystemBarColorHelper());$|                        // Alice patch start 0032\n                        toolbarManager::getToolbarBackgroundColorForNavigationBar,\n                        // Alice patch end 0032\n                        mEdgeToEdgeManager.getEdgeToEdgeSystemBarColorHelper());|' "$path6"
sed -i '/^import android\.view\.WindowManager;$/a\
\
// Alice patch start 0032\
import androidx.annotation.ColorInt;\
// Alice patch end 0032' "$path7"
sed -i '/^    private final boolean mCanSetTransparentStatusBarWithoutDelegate;$/a\
    // Alice patch start 0032\
    private @ColorInt int mNavigationBarIconColor;\
    private boolean mHasCustomNavigationBarIconColor;\
    // Alice patch end 0032' "$path7"
sed -i 's|^        updateNavigationBarIconColor(mWindow\.getDecorView(), mNavBarColor);$|        // Alice patch start 0032\n        updateNavigationBarIconColor(\n                mWindow.getDecorView(),\n                mHasCustomNavigationBarIconColor ? mNavigationBarIconColor : mNavBarColor);\n        // Alice patch end 0032|' "$path7"
sed -i '/^    @Nullable SystemBarColorHelper getEdgeToEdgeDelegateHelperForTesting() {$/i\
    // Alice patch start 0032\
    public void setNavigationBarIconColor(@ColorInt int color) {\
        if (mHasCustomNavigationBarIconColor && mNavigationBarIconColor == color) return;\
        mNavigationBarIconColor = color;\
        mHasCustomNavigationBarIconColor = true;\
        updateNavigationBarIconColor(mWindow.getDecorView(), color);\
    }\
    // Alice patch end 0032\
' "$path7"

# 4) chin 不计入 Blink 视口
sed -i '/^        mBrowserControlsSizer\.setBottomControlsHeight(mTotalHeight, mTotalMinHeight);$/c\
        // Alice patch start 0032\
        int aliceChinHeight = 0;\
        BottomControlsLayer aliceChin = mLayers.get(LayerType.BOTTOM_CHIN);\
        if (aliceChin != null && mLayerVisibilities.get(LayerType.BOTTOM_CHIN)) {\
            aliceChinHeight = aliceChin.getHeight();\
        }\
        mBrowserControlsSizer.setBottomControlsHeight(\
                Math.max(0, mTotalHeight - aliceChinHeight), mTotalMinHeight);\
        // Alice patch end 0032' "$path8"

# 首次启动时原生页面不会再次派发 controls offset，主动按 resting offset 重排一次
sed -i '/^        if (mBrowserControlsSizer\.offsetOverridden()) {$/,/^        }$/c\
        // Alice patch start 0032\
        if (mBrowserControlsSizer.offsetOverridden()) {\
            repositionLayers(\
                    mBrowserControlsSizer.getBottomControlOffset(),\
                    mBrowserControlsSizer.getBottomControlsMinHeightOffset(),\
                    animate,\
                    isVisibilityForced());\
        } else {\
            // Native pages do not send onControlsOffsetChanged after the initial layout.\
            // Reposition once at rest so a newly visible chin also moves the bottom toolbar\
            // above the system navigation bar on first launch.\
            repositionLayers(\
                    /* bottomOffset= */ 0,\
                    /* bottomControlsMinHeightOffset= */ 0,\
                    /* animated= */ false,\
                    isVisibilityForced());\
        }\
        // Alice patch end 0032' "$path8"
# 5) 设置页：导航栏彻底透明 + 内容避让
sed -i '/^        setContentView(R.layout.settings_activity);$/a\
        // Alice patch start 0032\
        getWindow().setNavigationBarColor(Color.TRANSPARENT);\
        getWindow().setNavigationBarDividerColor(Color.TRANSPARENT);\
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {\
            getWindow().setNavigationBarContrastEnforced(false);\
        }\
        var aliceEdgeToEdgeManager = getEdgeToEdgeManager();\
        if (aliceEdgeToEdgeManager != null) {\
            aliceEdgeToEdgeManager\
                    .getEdgeToEdgeSystemBarColorHelper()\
                    .setNavigationBarColor(Color.TRANSPARENT);\
            aliceEdgeToEdgeManager\
                    .getEdgeToEdgeSystemBarColorHelper()\
                    .setNavigationBarDividerColor(Color.TRANSPARENT);\
        }\
        // Alice patch end 0032' "$path9"


# chin 在非 edge-to-edge（小窗/导航栏关闭）时不占高度
sed -i 's|^        int newHeight = mEdgeToEdgeBottomInsetPx;$|        // Alice patch start 0032\n        int newHeight = mIsDrawingToEdge ? mEdgeToEdgeBottomInsetPx : 0;\n        // Alice patch end 0032|' "$path11"

# 6) 标签管理页底部避让
sed -i 's|^\( *\)mEdgeToEdgeBottomInsets = .*;$|\1// Alice patch start 0032\n\1mEdgeToEdgeBottomInsets = Math.max(inset, mEdgeToEdgeSupplier.get() != null ? mEdgeToEdgeSupplier.get().getSystemBottomInsetPx() : 0);\n\1// Alice patch end 0032|' "$path10"

# 7) 工具栏容器背景随主题更新，覆盖导航栏区域
sed -i '/^    private void updateBackgroundColor() {$/a\
        // Alice patch start 0032\
        if (mToolbarDataProvider != null) {\
            // Put the solid color on the moving ToolbarControlContainer itself.\
            // The inner toolbar container can remain at the old layout position during IME\
            // inset animation, which leaves a detached background behind.\
            setBackgroundColor(mToolbarDataProvider.getPrimaryColor());\
        }\
        // Alice patch end 0032\
' "$path12"

# 8) 设置页：页面延伸到导航栏下面，列表底部留出导航栏高度
sed -i '/^        setContentView(R.layout.settings_activity);$/a\
        // Alice patch start 0032\
        View aliceEdgeContent = getContentView();\
        aliceEdgeContent.addOnLayoutChangeListener(\
                (v, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {\
                    if (v.getPaddingBottom() != 0) {\
                        v.setPadding(\
                                v.getPaddingLeft(), v.getPaddingTop(), v.getPaddingRight(), 0);\
                    }\
                });\
        // Alice patch end 0032\
' "$path9"

sed -i '/^import androidx\.lifecycle\.Lifecycle;$/a\
// Alice patch start 0032\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0032
' "$path13"
sed -i '/^        super.onViewCreated(view, savedInstanceState);$/a\
        // Alice patch start 0032\
        getListView().setClipToPadding(false);\
        getListView().addOnLayoutChangeListener(\
                (v, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {\
                    android.view.WindowInsets aliceWindowInsets = v.getRootWindowInsets();\
                    int bottomInset = 0;\
                    if (aliceWindowInsets != null) {\
                        WindowInsetsCompat insets =\
                                WindowInsetsCompat.toWindowInsetsCompat(aliceWindowInsets, v);\
                        bottomInset =\
                                insets.getInsets(WindowInsetsCompat.Type.navigationBars())\
                                        .bottom;\
                    }\
                    if (v.getPaddingBottom() != bottomInset) {\
                        v.setPadding(\
                                v.getPaddingLeft(),\
                                v.getPaddingTop(),\
                                v.getPaddingRight(),\
                                bottomInset);\
                    }\
                });\
        // Alice patch end 0032\
' "$path13"

# Hub 布局也保留底部 chin 高度，避免进入/退出动画高度变短
sed -i 's|^\( *\)layoutType == LayoutType.BROWSING$|\1layoutType == LayoutType.BROWSING\n\1// Alice patch start 0032\n\1        \|\| layoutType == LayoutType.HUB\n\1// Alice patch end 0032|' "$path1"

# 导入 WindowInsetsCompat
if ! grep -q '^import androidx.core.view.WindowInsetsCompat;' "$path14"; then
    sed -i '/^import android\.widget\.FrameLayout;$/a\
\
// Alice patch start 0032\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0032' "$path14"
fi

# 设置 pinned view 时先应用一次底部 padding，避免首次动画使用旧高度
sed -i '/^    public void setPinnedBottomView(@Nullable View view) {$/,/^    }$/ s|^        mPinnedBottomView = view;$|        mPinnedBottomView = view;\n        // Alice patch start 0032\n        if (view != null) {\n            applyAliceBottomInset(view);\n            view.post(() -> applyAliceBottomInset(view));\n        }\n        // Alice patch end 0032|' "$path14"

# 每次布局时重新应用
sed -i '/^        if (pinned == null) return;$/a\
        // Alice patch start 0032\
        applyAliceBottomInset(pinned);\
        // Alice patch end 0032' "$path14"

# 新增 padding 辅助方法（插在 pinBottomView 结束之后）
sed -i '/^        \/\/ Alice patch end 0027$/{n;a\
\
    // Alice patch start 0032\
    private void applyAliceBottomInset(View pinned) {\
        android.view.WindowInsets aliceWindowInsets = pinned.getRootWindowInsets();\
        int bottomInset = 0;\
        if (aliceWindowInsets != null) {\
            WindowInsetsCompat insets =\
                    WindowInsetsCompat.toWindowInsetsCompat(aliceWindowInsets, pinned);\
            bottomInset =\
                    insets.isVisible(WindowInsetsCompat.Type.navigationBars())\
                            ? insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom\
                            : 0;\
        }\
        if (pinned.getContext() instanceof android.app.Activity\
                && ((android.app.Activity) pinned.getContext()).isInMultiWindowMode()) {\
            bottomInset = 0;\
        }\
        if (pinned.getPaddingBottom() != bottomInset) {\
            pinned.setPadding(\
                    pinned.getPaddingLeft(),\
                    pinned.getPaddingTop(),\
                    pinned.getPaddingRight(),\
                    bottomInset);\
            pinned.invalidate();\
        }\
    }\
    // Alice patch end 0032
}' "$path14"

# 9) 工具栏滑动/标签管理动画时，chin 背景直接跟随工具栏主色
sed -i '/^import android\.graphics\.Color;$/a\
// Alice patch start 0032\
import android.graphics.drawable.ColorDrawable;\
// Alice patch end 0032' "$path6"
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsStateProvider\.ControlsPosition;$/a\
// Alice patch start 0032\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0032' "$path6"
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BottomOverscrollHandler;$/a\
// Alice patch start 0032\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
// Alice patch end 0032' "$path6"
sed -i '/^    private @Nullable TabbedSystemUiCoordinator mSystemUiCoordinator;$/a\
    // Alice patch start 0032\
    private int mAliceTaskDescriptionNavColor = Integer.MIN_VALUE;\
    // Alice patch end 0032' "$path6"
sed -i '/^        mSystemBarColorHelperSupplier\.set(bottomChinColorHelper);$/a\
        // Alice patch start 0032\
        View aliceChinView = mActivity.findViewById(R.id.edge_to_edge_bottom_chin);\
        if (aliceChinView != null) {\
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {\
                mActivity.getWindow().setNavigationBarContrastEnforced(false);\
            }\
            mActivity.getWindow().setNavigationBarColor(Color.TRANSPARENT);\
            mAliceChinView = aliceChinView;\
            mAliceChinColorListener =\
                    () -> {\
                        if (mActivity == null\
                                || mActivity.isDestroyed()\
                                || !aliceChinView.isAttachedToWindow()) {\
                            return true;\
                        }\
                        int aliceColor = Color.TRANSPARENT;\
                        bottomChinColorHelper.setNavigationBarColor(aliceColor);\
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {\
                            mActivity.getWindow().setNavigationBarContrastEnforced(false);\
                        }\
                        if (mActivity.getWindow().getNavigationBarColor() != aliceColor) {\
                            mActivity.getWindow().setNavigationBarColor(aliceColor);\
                        }\
                        if (mActivity.getWindow().getNavigationBarDividerColor()\
                                != Color.TRANSPARENT) {\
                            mActivity.getWindow().setNavigationBarDividerColor(Color.TRANSPARENT);\
                        }\
                        if (android.os.Build.VERSION.SDK_INT\
                                >= android.os.Build.VERSION_CODES.TIRAMISU\
                                \&\& mAliceTaskDescriptionNavColor != Color.TRANSPARENT) {\
                            mAliceTaskDescriptionNavColor = Color.TRANSPARENT;\
                            mActivity.setTaskDescription(\
                                    new android.app.ActivityManager.TaskDescription.Builder()\
                                            .setNavigationBarColor(Color.TRANSPARENT)\
                                            .build());\
                        }\
                        if (aliceColor == Color.TRANSPARENT) {\
                            if (aliceChinView.getBackground() != null) {\
                                aliceChinView.setBackground(null);\
                            }\
                        } else {\
                            ColorDrawable aliceBackground =\
                                    aliceChinView.getBackground() instanceof ColorDrawable\
                                            ? (ColorDrawable) aliceChinView.getBackground()\
                                            : null;\
                            if (aliceBackground == null\
                                    || aliceBackground.getColor() != aliceColor) {\
                                aliceChinView.setBackgroundColor(aliceColor);\
                            }\
                        }\
                        return true;\
                    };\
            aliceChinView\
                    .getViewTreeObserver()\
                    .addOnPreDrawListener(mAliceChinColorListener);\
        }\
        // Alice patch end 0032\
' "$path6"

sed -i '/^        mGestureNavLayoutObserver =$/,/^                };$/c\
        // Alice patch start 0032\
        mGestureNavLayoutObserver =\
                new LayoutStateProvider.LayoutStateObserver() {\
                    @Override\
                    public void onStartedShowing(int layoutType) {\
                        if (layoutType == LayoutType.HUB) {\
                            assert mHistoryNavigationCoordinator != null;\
                            mHistoryNavigationCoordinator.reset();\
                            setActivityTitle(/* tab= */ null, /* isHub= */ true);\
                        }\
                    }\
                };\
        // Alice patch end 0032' "$path6"

sed -i '/^public class TabbedRootUiCoordinator extends RootUiCoordinator {$/a\
    // Alice patch start 0032\
    private @Nullable View mAliceChinView;\
    private android.view.ViewTreeObserver.@Nullable OnPreDrawListener mAliceChinColorListener;\
    // Alice patch end 0032' "$path6"

sed -i '/^    public void onDestroy() {$/a\
        // Alice patch start 0032\
        if (mAliceChinView != null \&\& mAliceChinColorListener != null) {\
            android.view.ViewTreeObserver aliceObserver =\
                    mAliceChinView.getViewTreeObserver();\
            if (aliceObserver.isAlive()) {\
                aliceObserver.removeOnPreDrawListener(mAliceChinColorListener);\
            }\
        }\
        mAliceChinView = null;\
        mAliceChinColorListener = null;\
        // Alice patch end 0032' "$path6"

# 9.1) TaskDescription 显式携带透明导航栏色，避免 MIUI 自动取色。
sed -i '/^    protected void setDefaultTaskDescription() {$/,/^    }$/c\
    protected void setDefaultTaskDescription() {\
        // Alice patch start 0032\
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
        // Alice patch end 0032\
    }' "$path22"

sed -i 's|^        edgeToEdgeSystemBarColorHelper\.setNavigationBarColor(defaultNavigationBarColor);$|        // Alice patch start 0032\n        edgeToEdgeSystemBarColorHelper.setNavigationBarColor(android.graphics.Color.TRANSPARENT);\n        // Alice patch end 0032|' "$path22"

sed -i '/^                                \.setBackgroundColor(opaqueBgColor)$/a\
                                // Alice patch start 0032\
                                .setNavigationBarColor(android.graphics.Color.TRANSPARENT)\
                                // Alice patch end 0032' "$path23"

sed -i '/^                                \.setStatusBarColor(opaqueColor)$/a\
                                // Alice patch start 0032\
                                .setNavigationBarColor(android.graphics.Color.TRANSPARENT)\
                                // Alice patch end 0032' "$path23"

# 10) 标签管理页收缩/展开动画使用完整底部工具栏高度和实际背景

sed -i '/^                    viewportRectf.round(viewportRect);$/a\
        // Alice patch start 0032\
        if (isTopToolbar) {\
            viewportRect.top -= viewHolder.getTopControlsHeightPixels();\
        } else {\
            RectF aliceWindowViewportRectf = new RectF();\
            Rect aliceWindowViewportRect = new Rect();\
            viewHolder.getWindowViewport(aliceWindowViewportRectf);\
            aliceWindowViewportRectf.round(aliceWindowViewportRect);\
            viewportRect.bottom = aliceWindowViewportRect.bottom;\
        }\
        // Alice patch end 0032' "$path21"

sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0032\
import android.graphics.drawable.Drawable;\
// Alice patch end 0032' "$path15"
sed -i '/^        int animatingHeight =$/,/^                        : Math\.max(0, bottomControlsHeight - bottomMargin);$/c\
        // Alice patch start 0032\
        // The bottom toolbar view includes the system navigation bar area. Reuse its\
        // exact geometry so the animation neither stops short nor leaves an extra strip.\
        int aliceToolbarHeight = toolbarView == null ? 0 : toolbarView.getHeight();\
        boolean aliceUseBottomToolbarGeometry =\
                toolbarView != null && !animationData.isTopToolbar();\
        int animatingHeight =\
                mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB\
                        ? 0\
                        : aliceUseBottomToolbarGeometry\
                                ? Math.max(0, aliceToolbarHeight)\
                                : Math.max(0, bottomControlsHeight - bottomMargin);\
        // Alice patch end 0032' "$path15"
sed -i 's|^            fakeViewParams\.bottomMargin = bottomMargin;$|            // Alice patch start 0032\n            fakeViewParams.bottomMargin =\n                    aliceUseBottomToolbarGeometry ? 0 : bottomMargin;\n            // Alice patch end 0032|' "$path15"
sed -i '/^            @ColorInt$/,/^            mFakeBottomControlsView\.setBackgroundColor(onSurfaceColor);$/c\
            // Alice patch start 0032\
            Drawable aliceToolbarDrawable =\
                    aliceUseBottomToolbarGeometry && toolbarView != null\
                            ? toolbarView.getBackground()\
                            : null;\
            Drawable aliceToolbarBackground = null;\
            if (aliceToolbarDrawable != null\
                    && aliceToolbarDrawable.getConstantState() != null) {\
                aliceToolbarBackground =\
                        aliceToolbarDrawable.getConstantState().newDrawable().mutate();\
            }\
            if (aliceToolbarBackground != null) {\
                mFakeBottomControlsView.setBackground(aliceToolbarBackground);\
            } else {\
                @ColorInt\
                int onSurfaceColor =\
                        BottomBarUtils.getBottomBarBackgroundColor(\
                                context,\
                                mIsIncognito\
                                        ? BrandedColorScheme.INCOGNITO\
                                        : BrandedColorScheme.APP_DEFAULT);\
                mFakeBottomControlsView.setBackgroundColor(onSurfaceColor);\
            }\
            // Alice patch end 0032' "$path15"

# Thumbnail providers can recycle their source bitmap after the callback returns. Keep a private
# copy for the draw pass so Canvas never retains a bitmap whose native storage was freed.
sed -i '/^            view.setImageBitmap(bitmap);$/c\
            // Alice patch start 0032\
            Bitmap aliceAnimationBitmap = null;\
            if (bitmap != null) {\
                try {\
                    Bitmap.Config aliceConfig = bitmap.getConfig();\
                    if (aliceConfig == null || aliceConfig == Bitmap.Config.HARDWARE) {\
                        aliceConfig = Bitmap.Config.ARGB_8888;\
                    }\
                    aliceAnimationBitmap =\
                            bitmap.copy(aliceConfig, false);\
                } catch (RuntimeException e) {\
                    aliceAnimationBitmap = null;\
                }\
            }\
            view.setImageBitmap(aliceAnimationBitmap);\
            // Alice patch end 0032' "$path15"

# 11) Hub 进入动画期间保留下方工具栏的 hairline，动画结束后再隐藏
sed -i '/^    protected boolean shouldDrawHairline() {$/,/^    }$/c\
    protected boolean shouldDrawHairline() {\
        // Alice patch start 0032\
        // TODO(twellington): Move this hairline state information to ToolbarDataProvider and show\
        // hairline when incognito NTP is scrolled.\
        return super.shouldDrawHairline()\
                \&\& (mTabSwitcherState == STATIC_TAB\
                        || (mTabSwitcherState == ENTERING_TAB_SWITCHER\
                                \&\& mBrowserControlsStateProvider != null\
                                \&\& mBrowserControlsStateProvider.getControlsPosition()\
                                        == ControlsPosition.BOTTOM))\
                \&\& !hideHairlineForIncognitoNtp()\
                \&\& !hideHairlineForInterstitial()\
                \&\& getVisibility() == View.VISIBLE;\
        // Alice patch end 0032\
    }' "$path16"

sed -i '/^        updateLayoutParamsForMultiline();$/a\
        // Alice patch start 0032\
        if (mBrowserControlsStateProvider != null\
                && mBrowserControlsStateProvider.getControlsPosition()\
                        == ControlsPosition.BOTTOM) {\
            ViewGroup.MarginLayoutParams aliceToolbarParams =\
                    (ViewGroup.MarginLayoutParams) getLayoutParams();\
            int aliceToolbarTopMargin =\
                    hasFocus\
                            ? 0\
                            : getResources()\
                                    .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
            if (aliceToolbarParams.topMargin != aliceToolbarTopMargin) {\
                aliceToolbarParams.topMargin = aliceToolbarTopMargin;\
                setLayoutParams(aliceToolbarParams);\
            }\
        }\
        // Alice patch end 0032\
' "$path16"
# 12) 地址栏聚焦遮罩逐帧跟随搜索栏底部
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0032\
import android.app.Activity;\
// Alice patch end 0032' "$path17"
sed -i '/^import androidx\.annotation\.ColorInt;$/a\
// Alice patch start 0032\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0032' "$path17"
sed -i '/^import org\.chromium\.ui\.util\.ColorUtils;$/a\
// Alice patch start 0032\
import java.util.List;\
// Alice patch end 0032' "$path17"
sed -i '/^        mTabStripHeightSupplier\.addSyncObserverAndPostIfNonNull(mTabStripHeightChangeCallback);$/a\
        // Alice patch start 0032\
        if (mContext instanceof Activity) {\
            View aliceBottomBoundary =\
                    ((Activity) mContext).findViewById(R.id.control_container);\
            if (aliceBottomBoundary != null) {\
                aliceBottomBoundary.addOnLayoutChangeListener(\
                        (v, left, top, right, bottom,\
                                oldLeft, oldTop, oldRight, oldBottom) ->\
                                updateScrimBottomMargin());\
                ViewCompat.setWindowInsetsAnimationCallback(\
                        aliceBottomBoundary,\
                        new WindowInsetsAnimationCompat.Callback(\
                                WindowInsetsAnimationCompat.Callback\
                                        .DISPATCH_MODE_CONTINUE_ON_SUBTREE) {\
                            @Override\
                            public WindowInsetsCompat onProgress(\
                                    WindowInsetsCompat insets,\
                                    List<WindowInsetsAnimationCompat> runningAnimations) {\
                                updateScrimBottomMargin(\
                                        insets.getInsets(WindowInsetsCompat.Type.ime()).bottom);\
                                return insets;\
                            }\
                        });\
            }\
        }\
        // Alice patch end 0032\
' "$path17"
sed -i '/^                mBottomControlsStacker\.getHeightFromLayerToBottom(LayerType\.BOTTOM_CHIN));$/,/^    }$/c\
        // Alice patch start 0032\
                mBottomControlsStacker.getHeightFromLayerToBottom(LayerType.BOTTOM_CHIN));\
        updateScrimBottomMargin();\
    }\
    // Alice patch end 0032' "$path17"
sed -i '/^    \/\*\* Controls the visibility of scrim overlay\. \*\/$/i\
    // Alice patch start 0032\
    private void updateScrimBottomMargin() {\
        if (!(mContext instanceof Activity)) return;\
        View aliceBottomBoundary =\
                ((Activity) mContext).findViewById(R.id.control_container);\
        if (aliceBottomBoundary == null) return;\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(aliceBottomBoundary);\
        if (insets != null) {\
            updateScrimBottomMargin(\
                    insets.getInsets(WindowInsetsCompat.Type.ime()).bottom);\
            return;\
        }\
        if (!(aliceBottomBoundary.getParent() instanceof View)) return;\
        View aliceBottomBoundaryParent = (View) aliceBottomBoundary.getParent();\
        if (aliceBottomBoundaryParent.getHeight() <= 0) return;\
        updateScrimBottomMargin(\
                Math.max(\
                        0,\
                        aliceBottomBoundaryParent.getHeight()\
                                - aliceBottomBoundary.getBottom()));\
    }\
\
    private void updateScrimBottomMargin(int bottomMargin) {\
        mScrimModel.set(ScrimProperties.BOTTOM_MARGIN, Math.max(0, bottomMargin));\
    }\
    // Alice patch end 0032\
' "$path17"
sed -i '/^    private boolean mIsXrFsm;$/a\
    // Alice patch start 0032\
    private boolean mIsUrlBarFocusedForSceneLayer;\
    // Alice patch end 0032' "$path18"

sed -i '/^    public int getPrimaryColor() {$/,/^    }$/c\
    public int getPrimaryColor() {\
        return mLocationBarModel.getPrimaryColor();\
    }\
\
    // Alice patch start 0032\
    public int getToolbarBackgroundColorForNavigationBar() {\
        if (mControlContainer == null) return getPrimaryColor();\
        return mControlContainer.getToolbarBackgroundColor();\
    }\
    // Alice patch end 0032' "$path18"

# 13) 地址栏聚焦时抑制 compositor 工具栏场景层，避免其在键盘后方残留
sed -i '/^        mSuppressToolbarSceneLayerSupplier\.set(mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow);$/c\
        // Alice patch start 0032\
        mSuppressToolbarSceneLayerSupplier.set(\
                mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow || mIsUrlBarFocusedForSceneLayer);\
        // Alice patch end 0032' "$path18"
sed -i '/^        mToolbar\.onUrlFocusChange(hasFocus);$/c\
        // Alice patch start 0032\
        mIsUrlBarFocusedForSceneLayer = hasFocus;\
        mToolbar.onUrlFocusChange(hasFocus);\
        updateToolbarSceneLayerSuppression();\
        // Alice patch end 0032\
' "$path18"

sed -i '/^    private boolean mControlsResizeView;$/a\
    // Alice patch start 0032\
    private int mAliceNavigationBarInset;\
    private int mAliceNavigationBarWidth;\
    // Alice patch end 0032' "$path19"

# 15) WebContents viewport 使用真实的 top/bottom controls 高度；controls 被
#     hiding token 隐藏时不再为空工具栏或 mini origin bar 避让。
path19="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
sed -i '/^        int verticalViewportInsets = controlsInsets + webContentsHeightInset;$/c\
        // Alice patch start 0032\
        if (mAliceNavigationBarWidth != getWidth()) {\
            mAliceNavigationBarWidth = getWidth();\
            mAliceNavigationBarInset = 0;\
        }\
        View aliceRoot = getRootView();\
        android.view.WindowInsets aliceWindowInsets = aliceRoot.getRootWindowInsets();\
        if (aliceWindowInsets != null) {\
            int aliceCurrentNavBarInset =\
                    androidx.core.view.WindowInsetsCompat.toWindowInsetsCompat(\
                                    aliceWindowInsets, aliceRoot)\
                            .getInsets(\
                                    androidx.core.view.WindowInsetsCompat.Type\
                                            .navigationBars())\
                            .bottom;\
            mAliceNavigationBarInset =\
                    Math.max(mAliceNavigationBarInset, aliceCurrentNavBarInset);\
        }\
        boolean aliceInFullscreen =\
                mBrowserControlsManager != null\
                        && mBrowserControlsManager\
                                .getFullscreenManager()\
                                .getPersistentFullscreenMode();\
        int aliceTopControlsInset = 0;\
        int aliceBottomControlsInset = 0;\
        if (!aliceInFullscreen && mBrowserControlsManager != null) {\
            aliceTopControlsInset =\
                    mControlsResizeView\
                            ? mBrowserControlsManager.getTopControlsHeight()\
                            : mBrowserControlsManager.getTopControlsMinHeight();\
            if (!mBrowserControlsManager.hasHidingTokens()) {\
                aliceBottomControlsInset =\
                        mControlsResizeView\
                                ? mBrowserControlsManager.getBottomControlsHeight()\
                                : mBrowserControlsManager.getBottomControlsMinHeight();\
            }\
        }\
        int verticalViewportInsets =\
                aliceTopControlsInset\
                        + aliceBottomControlsInset\
                        + webContentsHeightInset\
                        + (aliceInFullscreen ? 0 : mAliceNavigationBarInset);\
        // Alice patch end 0032' "$path19"

# 16) 标签组弹窗收回动画在下一帧重新读取网格卡片位置，避免使用布局变化前的坐标。
sed -i 's|^        assumeNonNull(mParent)\.getGlobalVisibleRect(dialogParentRect);$|        // Alice patch start 0032\n        int[] aliceDialogLocation = new int[2];\n        getLocationInWindow(aliceDialogLocation);\n        dialogParentRect.offsetTo(aliceDialogLocation[0], aliceDialogLocation[1]);\n        // Alice patch end 0032|' "$path24"

sed -i 's|^        rect\.offset(-dialogParentRect\.left, -dialogParentRect\.top);$|        // Alice patch start 0032\n        int[] aliceItemLocation = new int[2];\n        mItemView.getLocationInWindow(aliceItemLocation);\n        rect.offsetTo(\n                aliceItemLocation[0] - dialogParentRect.left,\n                aliceItemLocation[1] - dialogParentRect.top);\n        // Alice patch end 0032|' "$path24"

sed -i 's|^        int clipTop = itemViewParentRect\.top - dialogParentRect\.top;$|        // Alice patch start 0032\n        int[] aliceItemParentLocation = new int[2];\n        ((View) mItemView.getParent()).getLocationInWindow(aliceItemParentLocation);\n        int clipTop = aliceItemParentLocation[1] - dialogParentRect.top;\n        // Alice patch end 0032|' "$path24"

sed -i '/^        mHideDialogAnimation.start();$/c\
        // Alice patch start 0032\
        View aliceAnimationSource = mItemView;\
        if (aliceAnimationSource != null \&\& aliceAnimationSource.isAttachedToWindow()) {\
            aliceAnimationSource.postOnAnimation(\
                    () -> {\
                        if (getVisibility() != View.VISIBLE\
                                || mCurrentDialogAnimator != mHideDialogAnimation) {\
                            return;\
                        }\
                        setupDialogAnimation(aliceAnimationSource);\
                        mCurrentDialogAnimator = mHideDialogAnimation;\
                        mHideDialogAnimation.start();\
                    });\
        } else {\
            mHideDialogAnimation.start();\
        }\
        // Alice patch end 0032' "$path24"
