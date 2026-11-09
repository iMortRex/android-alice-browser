#!/bin/bash
# 临时诊断：输出工具栏滑动主题色链路的端点、混合值和应用结果。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarControlContainer.java"
path3="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path4="chrome/browser/ui/android/theme/java/src/org/chromium/chrome/browser/theme/ToolbarThemeColorProvider.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/ui/system/StatusBarColorController.java"
path6="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 9999' "$path1"; then
    exit 100
fi

# 0) 构造时确认诊断代码是否至少运行过一次。
sed -i '/^        mControlView = controlContainer instanceof View ? (View) controlContainer : null;$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "constructed control="\
                        + (controlContainer != null)\
                        + " provider="\
                        + (toolbarColorProvider != null));\
        // Alice patch end 9999' "$path1"

# 1) 滑动准备阶段：方向、Tab、端点颜色和地址栏颜色。
sed -i '/^        List<Integer> visibleTabs = new ArrayList<>();$/i\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "prepare direction="\
                        + direction\
                        + " enabled="\
                        + mAliceSwipeThemeEnabled\
                        + " from="\
                        + fromTabId\
                        + " to="\
                        + toTabId\
                        + " toolbar0="\
                        + Integer.toHexString(mAliceSwipeStartToolbarColor)\
                        + " toolbar1="\
                        + Integer.toHexString(mAliceSwipeEndToolbarColor)\
                        + " location0="\
                        + Integer.toHexString(mAliceSwipeStartLocationBarColor)\
                        + " location1="\
                        + Integer.toHexString(mAliceSwipeEndLocationBarColor));\
        // Alice patch end 9999' "$path1"

# 2) 每帧混合结果。
sed -i '/^        mControlContainer.setToolbarColorsForSwipe(toolbarColor, locationBarColor);$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "apply progress="\
                        + clampedProgress\
                        + " toolbar="\
                        + Integer.toHexString(toolbarColor)\
                        + " location="\
                        + Integer.toHexString(locationBarColor));\
        // Alice patch end 9999' "$path1"

# 3) ControlContainer 是否收到颜色，以及各层实际背景。
sed -i '/^    public void setToolbarColorsForSwipe($/i\
    // Alice patch start 9999\
    private String aliceDescribeBackground(Drawable drawable) {\
        if (drawable == null) return "null";\
        if (drawable instanceof ColorDrawable) {\
            return Integer.toHexString(((ColorDrawable) drawable).getColor());\
        }\
        return drawable.getClass().getSimpleName();\
    }\
    // Alice patch end 9999\
\
' "$path2"

sed -i '/^        getToolbarResourceAdapter()\.invalidate(.*$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "container toolbar="\
                        + Integer.toHexString(toolbarColor)\
                        + " location="\
                        + Integer.toHexString(locationBarColor)\
                        + " toolbarNull="\
                        + (mToolbar == null)\
                        + " rootBg="\
                        + aliceDescribeBackground(getBackground())\
                        + " containerBg="\
                        + aliceDescribeBackground(mToolbarContainer.getBackground())\
                        + " toolbarViewBg="\
                        + aliceDescribeBackground(mToolbarView.getBackground()));\
        // Alice patch end 9999' "$path2"

# 4) ToolbarPhone 实际应用后的绘制状态。
sed -i '/^        updateModernLocationBarColor(locationBarColor);$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "phone toolbar="\
                        + Integer.toHexString(toolbarColor)\
                        + " location="\
                        + Integer.toHexString(locationBarColor)\
                        + " currentToolbar="\
                        + Integer.toHexString(mToolbarBackground.getColor())\
                        + " currentLocation="\
                        + Integer.toHexString(mCurrentLocationBarColor)\
                        + " attached="\
                        + isAttachedToWindow()\
                        + " visible="\
                        + (getVisibility() == View.VISIBLE)\
                        + " texture="\
                        + mTextureCaptureMode);\
        // Alice patch end 9999' "$path3"

# 5) 每个 Tab 的原始 theme-color 与最终解析色。
sed -i '/^    public @ColorInt int getToolbarBackgroundColorForTab(Tab tab) {$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "resolve tab="\
                        + tab.getId()\
                        + " raw="\
                        + Integer.toHexString(tab.getThemeColor())\
                        + " resolved="\
                        + Integer.toHexString(\
                                mTopUiThemeColorProvider.getToolbarBackgroundColor(tab))\
                        + " incognito="\
                        + tab.isIncognito());\
        // Alice patch end 9999' "$path4"

# 6) 状态栏最终计算色及窗口当前色。
sed -i '/^        @ColorInt int statusBarColor = calculateFinalStatusBarColor();$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "status final="\
                        + Integer.toHexString(statusBarColor)\
                        + " toolbar="\
                        + Integer.toHexString(mToolbarColor)\
                        + " toolbarChanged="\
                        + mToolbarColorChanged\
                        + " focused="\
                        + mIsOmniboxFocused\
                        + " edgeCanSet="\
                        + (mEdgeToEdgeSystemBarColorHelper != null\
                                \&\& mEdgeToEdgeSystemBarColorHelper.canSetStatusBarColor())\
                        + " window="\
                        + Integer.toHexString(mActivity.getWindow().getStatusBarColor()));\
        // Alice patch end 9999' "$path5"

# 7) 模拟导航栏收到的颜色及实际 View 背景。
sed -i '/^        mNavigationBarBackgroundColor = color;$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "navbar request="\
                        + Integer.toHexString(color)\
                        + " backgroundNull="\
                        + (mNavigationBarBackground == null)\
                        + " fullPreview="\
                        + BottomSheetContent.FullWindowPresentationState.isActive());\
        // Alice patch end 9999' "$path6"

sed -i '/^        aliceBackground.setBackgroundColor(aliceConfiguredBackgroundColor);$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "navbar actual="\
                        + Integer.toHexString(aliceConfiguredBackgroundColor)\
                        + " visible="\
                        + (aliceBackground.getVisibility() == View.VISIBLE)\
                        + " alpha="\
                        + aliceBackground.getAlpha());\
        // Alice patch end 9999' "$path6"

# 8) 配置变化时的工具栏颜色。
sed -i '/^                    public void onConfigurationChanged(Configuration configuration) {$/a\
                        // Alice patch start 9999\
                        android.util.Log.e(\
                                "Alice9999",\
                                "config uiMode="\
                                        + configuration.uiMode\
                                        + " toolbar="\
                                        + Integer.toHexString(mToolbar.getPrimaryColor())\
                                        + " provider="\
                                        + Integer.toHexString(\
                                                mToolbarThemeColorProvider.getThemeColor()));\
                        // Alice patch end 9999' "$path7"

# 9) 模拟导航栏生命周期和创建位置。
sed -i '/^        mHandler = handler;$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "navbar init controlAttached="\
                        + mControlContainer.getView().isAttachedToWindow()\
                        + " parent="\
                        + (mControlContainer.getView().getParent() != null));\
        // Alice patch end 9999' "$path6"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "navbar destroy backgroundNull=" + (mNavigationBarBackground == null));\
        // Alice patch end 9999' "$path6"

sed -i '/^        if (mNavigationBarBackground == null) {$/a\
            // Alice patch start 9999\
            android.util.Log.e(\
                    "Alice9999",\
                    "navbar create navHeight="\
                            + aliceNavigationBarHeight\
                            + " bottom="\
                            + aliceToolbarOnBottom\
                            + " parentIndex="\
                            + aliceParent.indexOfChild(aliceControlContainer));\
            // Alice patch end 9999' "$path6"

# 10) ToolbarPhone 主题色刷新入口的 previous/final。
sed -i '/^        final @ColorInt int initialColor = mToolbarBackground.getColor();$/a\
        // Alice patch start 9999\
        android.util.Log.e(\
                "Alice9999",\
                "primary changed initial="\
                        + Integer.toHexString(initialColor)\
                        + " provider="\
                        + Integer.toHexString(getToolbarDataProvider().getPrimaryColor())\
                        + " visualState="\
                        + mVisualState);\
        // Alice patch end 9999' "$path3"
