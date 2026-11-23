#!/bin/bash
# 横屏和竖屏 HTML 全屏不避让挖孔，普通竖屏页面保持短边挖孔模式

set -e

# 目标文件路径
path1="components/browser_ui/display_cutout/android/java/src/org/chromium/components/browser_ui/display_cutout/DisplayCutoutController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/ChromeBaseAppCompatActivity.java"
path3="ui/edge_to_edge/android/java/src/org/chromium/ui/edge_to_edge/layout/EdgeToEdgeLayoutCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0001' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 根据横屏或 HTML 全屏状态切换窗口挖孔模式，避免全屏页面继续避让挖孔。
sed -i '/^        final int displayCutoutMode = computeDisplayCutoutMode();$/,/^        setWindowAttributes(attributes);$/c\
        // Alice patch start 0001\
        android.app.Activity aliceActivity = mDelegate.getAttachedActivity();\
        boolean aliceLandscape =\
                aliceActivity != null\
                        \&\& aliceActivity.getResources().getConfiguration().orientation\
                                == android.content.res.Configuration.ORIENTATION_LANDSCAPE;\
        WebContents aliceWebContents = mDelegate.getWebContents();\
        boolean aliceHtmlFullscreen =\
                aliceWebContents != null \&\& aliceWebContents.isFullscreenForCurrentTab();\
        int aliceDisplayCutoutMode =\
                aliceLandscape || aliceHtmlFullscreen\
                        ? LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS\
                        : LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;\
        if (attributes.layoutInDisplayCutoutMode == aliceDisplayCutoutMode) return;\
        attributes.layoutInDisplayCutoutMode = aliceDisplayCutoutMode;\
        setWindowAttributes(attributes);\
        // Alice patch end 0001' "$path1"

# 所有 Chrome Activity 在 onCreate 阶段同步一次窗口挖孔策略。
sed -i '/^        applyThemeOverlays();$/a\
        // Alice patch start 0001\
        updateAliceDisplayCutoutMode(getResources().getConfiguration());\
        // Alice patch end 0001' "$path2"

# 新增窗口挖孔模式更新方法，并在配置变化时重新应用。
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

# 修正新方法插入后错误保留在方法上的 @Override 注解。
sed -i '/^    @Override$/{N;/^    @Override\n    \/\/ Alice patch start 0001$/s/^    @Override\n//}' "$path2"

# 配置变化后重新应用挖孔模式。
sed -i '/^        super\.onConfigurationChanged(newConfig);$/a\
        // Alice patch start 0001\
        updateAliceDisplayCutoutMode(newConfig);\
        // Alice patch end 0001' "$path2"

# Edge-to-edge 根布局按窗口挖孔模式决定是否保留左右安全区。
sed -i 's|^        Insets cutout = windowInsets\.getInsets(Type\.displayCutout());$|        // Alice patch start 0001\
        Insets cutout = windowInsets.getInsets(Type.displayCutout());\
        boolean shouldPadDisplayCutout =\
                WindowInsetsUtils.shouldPadDisplayCutout(windowInsets, mContext);\
        // Alice patch end 0001|' "$path3"

sed -i 's|^        if (WindowInsetsUtils\.shouldPadDisplayCutout(windowInsets, mContext)) {$|        // Alice patch start 0001\
        if (shouldPadDisplayCutout) {\
        // Alice patch end 0001|' "$path3"

sed -i 's|^            mView\.setDisplayCutoutInsetLeft(cutout\.left > 0 ? cutout : Insets\.NONE);$|            // Alice patch start 0001\
            mView.setDisplayCutoutInsetLeft(\
                    shouldPadDisplayCutout \&\& cutout.left > 0 ? cutout : Insets.NONE);\
            // Alice patch end 0001|' "$path3"

sed -i 's|^            mView\.setDisplayCutoutInsetRight(cutout\.right > 0 ? cutout : Insets\.NONE);$|            // Alice patch start 0001\
            mView.setDisplayCutoutInsetRight(\
                    shouldPadDisplayCutout \&\& cutout.right > 0 ? cutout : Insets.NONE);\
            // Alice patch end 0001|' "$path3"
