#!/bin/bash
# Hub 和标签管理页底部工具栏：普通窗口保留导航栏 inset，小窗不避让导航栏，
# 并修正动画高度、背景和 content offset。

set -e

path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneCoordinator.java"
path2="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
path3="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path4="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path5="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path7="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/bottom/BottomControlsMediator.java"
path8="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path9="ui/android/java/src/org/chromium/ui/UiUtils.java"

# 检测是否已应用
if grep -q 'Alice patch start 0057' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 标签管理页底部 inset 同时考虑系统导航栏。
sed -i 's|^\( *\)mEdgeToEdgeBottomInsets = .*;$|\1// Alice patch start 0057\n\1boolean aliceMultiWindow =\n\1        org.chromium.ui.UiUtils.isInMultiWindowOrNarrowWindow(mActivity);\n\1mEdgeToEdgeBottomInsets =\n\1        aliceMultiWindow\n\1                ? 0\n\1                : Math.max(\n\1                        inset,\n\1                        mEdgeToEdgeSupplier.get() != null\n\1                                ? mEdgeToEdgeSupplier.get().getSystemBottomInsetPx()\n\1                                : 0);\n\1// Alice patch end 0057|' "$path1"

# Hub 容器导入 WindowInsetsCompat。
sed -i '/^import android\.widget\.FrameLayout;$/a\
\
// Alice patch start 0057\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0057' "$path2"

# 设置 pinned view 时先应用一次底部 padding。
sed -i '/^    public void setPinnedBottomView(@Nullable View view) {$/,/^    }$/ s|^        mPinnedBottomView = view;$|        mPinnedBottomView = view;\n        // Alice patch start 0057\n        if (view != null) {\n            applyAliceBottomInset(view);\n            view.post(() -> applyAliceBottomInset(view));\n        }\n        // Alice patch end 0057|' "$path2"

# 每次布局时重新应用底部 padding。
sed -i '/^        if (pinned == null) return;$/a\
        // Alice patch start 0057\
        applyAliceBottomInset(pinned);\
        // Alice patch end 0057' "$path2"

# 新增底部 inset 辅助方法。
sed -i '/^        \/\/ Alice patch end 0027$/{n;a\
\
    // Alice patch start 0057\
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
        android.app.Activity aliceActivity =\
                org.chromium.base.ContextUtils.activityFromContext(pinned.getContext());\
        if (org.chromium.ui.UiUtils.isInMultiWindowOrNarrowWindow(aliceActivity)) {\
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
    // Alice patch end 0057
}' "$path2"

# 小窗中的 NTP 底栏不再为系统导航栏追加 padding。
sed -i '/^    private int calculateBottomPadding() {$/a\
        // Alice patch start 0057\
        android.app.Activity aliceActivity =\
                org.chromium.base.ContextUtils.activityFromContext(\
                        mWindowAndroid.getContext() != null\
                                ? mWindowAndroid.getContext().get()\
                                : null);\
        if (org.chromium.ui.UiUtils.isInMultiWindowOrNarrowWindow(aliceActivity)) {\
            return 0;\
        }\
        // Alice patch end 0057\
' "$path7"

# 工具栏导航栏高度判断改为从包装 Context 中解出 Activity。
sed -i '/^        if (aliceRoot.getContext() instanceof android.app.Activity$/,/^        }$/c\
        // Alice patch start 0057\
        android.app.Activity aliceActivity =\
                org.chromium.base.ContextUtils.activityFromContext(\
                        aliceRoot.getContext());\
        if (org.chromium.ui.UiUtils.isInMultiWindowOrNarrowWindow(aliceActivity)) {\
            return 0;\
        }\
        // Alice patch end 0057\
' "$path8"

# 小窗不仅由 Activity#isInMultiWindowMode() 判断；部分系统的小窗仍返回 false。
sed -i '/^        return insets\.left > 0;$/{n;a\
    // Alice patch start 0057\
    @SuppressWarnings("deprecation")\
    public static boolean isInMultiWindowOrNarrowWindow(@Nullable Activity activity) {\
        if (activity == null) return false;\
        if (activity.isInMultiWindowMode() || activity.isInPictureInPictureMode()) {\
            return true;\
        }\
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false;\
        WindowManager windowManager = activity.getWindowManager();\
        android.graphics.Rect currentBounds =\
                windowManager.getCurrentWindowMetrics().getBounds();\
        android.util.DisplayMetrics realMetrics = new android.util.DisplayMetrics();\
        windowManager.getDefaultDisplay().getRealMetrics(realMetrics);\
        if (currentBounds.width() <= 0 || realMetrics.widthPixels <= 0) return false;\
        return (long) currentBounds.width() * 100L\
                < (long) realMetrics.widthPixels * 90L;\
    }\
    // Alice patch end 0057
}' "$path9"

# 小窗中可见的底置工具栏直接贴住窗口底部，不再继承底部 chin 或导航栏层的抬升。
sed -i '/^        viewForLayer\.setTranslationY(layerYOffset);$/i\
        // Alice patch start 0057\
        if (layer == mBottomToolbarLayer\
                \&\& mCurrentPosition.get() == ControlsPosition.BOTTOM\
                \&\& mLayerVisibility == LayerVisibility.VISIBLE\
                \&\& !mIsOmniboxFocusedSupplier.get()\
                \&\& !mKeyboardVisibilityDelegate.isKeyboardShowing(\
                        mControlContainer.getView())\
                \&\& !FullscreenManager.FullscreenTransitionState\
                        .isPersistentFullscreen()\
                \&\& !FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()\
                \&\& org.chromium.ui.UiUtils.isInMultiWindowOrNarrowWindow(\
                        org.chromium.base.ContextUtils.activityFromContext(\
                                mControlContainer.getView().getContext()))) {\
            layerYOffset = 0;\
        }\
        // Alice patch end 0057\
' "$path8"

# 标签管理页动画使用窗口 viewport 底部。
sed -i '/^                    viewportRectf.round(viewportRect);$/a\
                    // Alice patch start 0057\
                    if (!isTopToolbar) {\
                        RectF aliceWindowViewportRectf = new RectF();\
                        Rect aliceWindowViewportRect = new Rect();\
                        viewHolder.getWindowViewport(aliceWindowViewportRectf);\
                        aliceWindowViewportRectf.round(aliceWindowViewportRect);\
                        viewportRect.bottom = aliceWindowViewportRect.bottom;\
                    }\
                    // Alice patch end 0057' "$path5"

# 修改对应源码以完成本补丁功能。
sed -i '/^                    if (!isTopToolbar \&\& !BottomBarConfigUtils\.isBottomBarEnabled(context)) {$/,/^                    }$/c\
                    if (!isTopToolbar \&\& !BottomBarConfigUtils.isBottomBarEnabled(context)) {\
                        RectF windowViewportRectf = new RectF();\
                        Rect windowViewportRect = new Rect();\
                        viewHolder.getWindowViewport(windowViewportRectf);\
                        windowViewportRectf.round(windowViewportRect);\
                        viewportRect.bottom = windowViewportRect.bottom;\
                    }\
' "$path5"

# 将 Compositor viewport 的窗口坐标转换为 HubContainer 的本地坐标。
sed -i '/^                    int initialLeftOffset;$/i\
                    // Alice patch start 0057\
                    int[] aliceViewportLocation = new int[2];\
                    int[] aliceHubLocation = new int[2];\
                    viewHolder.getLocationInWindow(aliceViewportLocation);\
                    hubContainerView.getLocationInWindow(aliceHubLocation);\
                    viewportRect.offset(\
                            0,\
                            aliceViewportLocation[1] - aliceHubLocation[1]);\
                    // Alice patch end 0057\
' "$path5"

# 小窗中的底部 inset 不计系统导航栏，只保留实际底部工具栏高度。
sed -i '/^                    int bottomMargin = 0;$/,/^                    }$/c\
                    // Alice patch start 0057\
                    android.app.Activity aliceActivity =\
                            org.chromium.base.ContextUtils.activityFromContext(\
                                    hubContainerView.getContext());\
                    boolean aliceMultiWindow =\
                            org.chromium.ui.UiUtils\
                                    .isInMultiWindowOrNarrowWindow(aliceActivity);\
                    @Nullable View aliceHubToolbar =\
                            hubContainerView.findViewById(R.id.hub_toolbar);\
                    int aliceHubToolbarHeight =\
                            aliceHubToolbar == null\
                                    ? 0\
                                    : aliceHubToolbar.getHeight();\
                    int aliceToolbarOffset =\
                            Math.max(mBottomBarHeight, aliceHubToolbarHeight);\
                    int bottomMargin = aliceToolbarOffset;\
                    if (mIsBottomBarEnabledOnGts) {\
                        if (!aliceMultiWindow) {\
                            EdgeToEdgeController edgeToEdgeController =\
                                    mEdgeToEdgeSupplier.get();\
                            if (edgeToEdgeController != null) {\
                                bottomMargin +=\
                                        edgeToEdgeController.getSystemBottomInsetPx();\
                            }\
                        }\
                    }\
                    // Alice patch end 0057\
' "$path5"

# 收缩展开动画使用底部工具栏实际几何和背景。
sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0057\
import android.graphics.drawable.Drawable;\
// Alice patch end 0057' "$path3"

sed -i '/^        int animatingHeight =$/,/^                        : Math\.max(0, bottomControlsHeight - bottomMargin);$/c\
        // Alice patch start 0057\
        int aliceToolbarHeight = toolbarView == null ? 0 : toolbarView.getHeight();\
        boolean aliceUseBottomToolbarGeometry =\
                toolbarView != null && !animationData.isTopToolbar();\
        int animatingHeight =\
                mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB\
                        ? 0\
                        : aliceUseBottomToolbarGeometry\
                                ? Math.max(0, aliceToolbarHeight)\
                                : Math.max(0, bottomControlsHeight - bottomMargin);\
        // Alice patch end 0057' "$path3"
sed -i 's|^            fakeViewParams\.bottomMargin = bottomMargin;$|            // Alice patch start 0057\n            fakeViewParams.bottomMargin =\n                    aliceUseBottomToolbarGeometry ? 0 : bottomMargin;\n            // Alice patch end 0057|' "$path3"
sed -i '/^            @ColorInt$/,/^            mFakeBottomControlsView\.setBackgroundColor(onSurfaceColor);$/c\
            // Alice patch start 0057\
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
            // Alice patch end 0057' "$path3"

# 动画 Bitmap 复制私有副本，避免源 Bitmap 回收后 Canvas 读取失效。
sed -i '/^            view.setImageBitmap(bitmap);$/c\
            // Alice patch start 0057\
            Bitmap aliceAnimationBitmap = null;\
            if (bitmap != null) {\
                try {\
                    Bitmap.Config aliceConfig = bitmap.getConfig();\
                    if (aliceConfig == null || aliceConfig == Bitmap.Config.HARDWARE) {\
                        aliceConfig = Bitmap.Config.ARGB_8888;\
                    }\
                    aliceAnimationBitmap = bitmap.copy(aliceConfig, false);\
                } catch (RuntimeException e) {\
                    aliceAnimationBitmap = null;\
                }\
            }\
            view.setImageBitmap(aliceAnimationBitmap);\
            // Alice patch end 0057' "$path3"

# Hub 进入动画期间保留底部工具栏 hairline。
sed -i '/^    protected boolean shouldDrawHairline() {$/,/^    }$/c\
    protected boolean shouldDrawHairline() {\
        // Alice patch start 0057\
        return super.shouldDrawHairline()\
                \&\& (mTabSwitcherState == STATIC_TAB\
                        || (mTabSwitcherState == ENTERING_TAB_SWITCHER\
                                \&\& mBrowserControlsStateProvider != null\
                                \&\& mBrowserControlsStateProvider.getControlsPosition()\
                                        == ControlsPosition.BOTTOM))\
                \&\& !hideHairlineForIncognitoNtp()\
                \&\& !hideHairlineForInterstitial()\
                \&\& getVisibility() == View.VISIBLE;\
        // Alice patch end 0057\
    }' "$path4"

sed -i '/^        updateLayoutParamsForMultiline();$/a\
        // Alice patch start 0057\
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
        // Alice patch end 0057\
' "$path4"

# Hub 临时 tab scene layer 使用稳定的顶部 controls 高度作为 content offset。
sed -i '/^        layoutTab.set(LayoutTab.CONTENT_OFFSET_Y, browserControls.getContentOffset());$/c\
        // Alice patch start 0057\
        int aliceContentOffsetY = browserControls.getContentOffset();\
        if (browserControls.getControlsPosition()\
                == BrowserControlsStateProvider.ControlsPosition.TOP) {\
            aliceContentOffsetY =\
                    Math.max(aliceContentOffsetY, browserControls.getTopControlsHeight());\
        }\
        layoutTab.set(LayoutTab.CONTENT_OFFSET_Y, aliceContentOffsetY);\
        // Alice patch end 0057' "$path6"
