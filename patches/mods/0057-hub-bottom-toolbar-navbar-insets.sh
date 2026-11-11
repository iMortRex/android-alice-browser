#!/bin/bash
# Hub 和标签管理页底部工具栏：保留导航栏 inset，修正动画高度、背景和 content offset。

set -e

path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneCoordinator.java"
path2="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
path3="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path4="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path5="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0057' "$path1"; then
    exit 100
fi

# 标签管理页底部 inset 同时考虑系统导航栏。
sed -i 's|^\( *\)mEdgeToEdgeBottomInsets = .*;$|\1// Alice patch start 0057\n\1mEdgeToEdgeBottomInsets = Math.max(inset, mEdgeToEdgeSupplier.get() != null ? mEdgeToEdgeSupplier.get().getSystemBottomInsetPx() : 0);\n\1// Alice patch end 0057|' "$path1"

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
    // Alice patch end 0057
}' "$path2"

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
