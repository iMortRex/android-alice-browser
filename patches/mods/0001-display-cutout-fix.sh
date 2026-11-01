#!/bin/bash
# 横屏不避让挖孔，竖屏保持短边挖孔模式

set -e

# 目标文件路径
path1="components/browser_ui/display_cutout/android/java/src/org/chromium/components/browser_ui/display_cutout/DisplayCutoutController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/ChromeBaseAppCompatActivity.java"
path3="ui/edge_to_edge/android/java/src/org/chromium/ui/edge_to_edge/layout/EdgeToEdgeLayoutCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0001' "$path1"; then
    exit 100
fi

# 标签页控制器中，横屏覆盖整个挖孔区域，竖屏沿用短边模式。
sed -i '/^        final int displayCutoutMode = computeDisplayCutoutMode();$/,/^        setWindowAttributes(attributes);$/c\
        // Alice patch start 0001\
        android.app.Activity aliceActivity = mDelegate.getAttachedActivity();\
        boolean aliceLandscape =\
                aliceActivity != null\
                        \&\& aliceActivity.getResources().getConfiguration().orientation\
                                == android.content.res.Configuration.ORIENTATION_LANDSCAPE;\
        int aliceDisplayCutoutMode =\
                aliceLandscape\
                        ? LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS\
                        : LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;\
        if (attributes.layoutInDisplayCutoutMode == aliceDisplayCutoutMode) return;\
        attributes.layoutInDisplayCutoutMode = aliceDisplayCutoutMode;\
        setWindowAttributes(attributes);\
        // Alice patch end 0001' "$path1"

# 所有 Chrome Activity 共用同一横屏挖孔策略，设置页等非标签页也不会再避让挖孔。
# 在 super.onCreate 前设置，避免窗口已附加后才切换 cutout 模式。
sed -i '/^        applyThemeOverlays();$/a\
        // Alice patch start 0001\
        updateAliceDisplayCutoutMode(getResources().getConfiguration());\
        // Alice patch end 0001' "$path2"

sed -i '/^    protected void onStart() {$/i\
    // Alice patch start 0001\
    private void updateAliceDisplayCutoutMode(Configuration configuration) {\
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return;\
\
        getWindow()\
                .setBackgroundDrawable(\
                        new android.graphics.drawable.ColorDrawable(\
                                SemanticColorUtils.getDefaultBgColor(this)));\
        getWindow().setStatusBarColor(android.graphics.Color.TRANSPARENT);\
        getWindow().setNavigationBarColor(android.graphics.Color.TRANSPARENT);\
\
        android.view.WindowManager.LayoutParams attributes = getWindow().getAttributes();\
        int displayCutoutMode =\
                configuration.orientation == Configuration.ORIENTATION_LANDSCAPE\
                        ? android.view.WindowManager.LayoutParams\
                                .LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS\
                        : android.view.WindowManager.LayoutParams\
                                .LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;\
        if (attributes.layoutInDisplayCutoutMode == displayCutoutMode) return;\
\
        attributes.layoutInDisplayCutoutMode = displayCutoutMode;\
        getWindow().setAttributes(attributes);\
    }\
    // Alice patch end 0001\
' "$path2"

# `onStart()` 上方原本带有 @Override；在新方法前插入后，该注解会错误地
# 作用于 private 的 updateAliceDisplayCutoutMode()。
sed -i '/^    @Override$/{N;/^    @Override\n    \/\/ Alice patch start 0001$/s/^    @Override\n//}' "$path2"

sed -i '/^        super\.onConfigurationChanged(newConfig);$/a\
        // Alice patch start 0001\
        updateAliceDisplayCutoutMode(newConfig);\
        // Alice patch end 0001' "$path2"

# Edge-to-edge 根布局只在需要安全区时绘制挖孔；ALWAYS 模式让背景自然铺满挖孔区域。
sed -i '/^        Insets cutout = windowInsets\.getInsets(Type\.displayCutout());$/,/^        mView\.setDisplayCutoutInsetRight(cutout\.right > 0 ? cutout : Insets\.NONE);$/c\
        // Alice patch start 0001\
        Insets cutout = windowInsets.getInsets(Type.displayCutout());\
        boolean shouldPadDisplayCutout =\
                WindowInsetsUtils.shouldPadDisplayCutout(windowInsets, mContext);\
        mView.setDisplayCutoutInsetLeft(\
                shouldPadDisplayCutout \&\& cutout.left > 0 ? cutout : Insets.NONE);\
        mView.setDisplayCutoutInsetRight(\
                shouldPadDisplayCutout \&\& cutout.right > 0 ? cutout : Insets.NONE);\
        // Alice patch end 0001' "$path3"

sed -i '/^        if (WindowInsetsUtils\.shouldPadDisplayCutout(windowInsets, mContext)) {$/,/^        }$/c\
        // Alice patch start 0001\
        if (shouldPadDisplayCutout) {\
            paddingInsetTypes += Type.displayCutout();\
            // Color display cutout padding to keep behaviour for Android 15-.\
            mView.setDisplayCutoutTop(cutout.top > 0 ? cutout : Insets.NONE);\
        } else {\
            mView.setDisplayCutoutTop(Insets.NONE);\
        }\
        // Alice patch end 0001' "$path3"
