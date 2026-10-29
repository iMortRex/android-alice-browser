#!/bin/bash
# 地址栏背景和描边彻底透明

set -e

path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarBackgroundDrawable.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path3="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarOverlayMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 9999' "$path1"; then
    exit 100
fi

# 1) 地址栏背景 drawable 始终使用透明色，覆盖普通页面、NTP 和聚焦状态。
sed -i '/^    public void setBackgroundColor(@ColorInt int color) {$/,/^    }$/c\
    // Alice patch start 9999\
    public void setBackgroundColor(@ColorInt int color) {\
        mBackgroundGradient.setColor(android.graphics.Color.TRANSPARENT);\
        invalidateSelf();\
    }\
    // Alice patch end 9999' "$path1"

# 2) 同时禁用实线、彩虹描边和焦点边框。
sed -i '/^    public void setHairlineBehavior(@HairlineBehavior int hairlineBehavior) {$/,/^    }$/c\
    // Alice patch start 9999\
    public void setHairlineBehavior(@HairlineBehavior int hairlineBehavior) {\
        mHairlineBehavior = HairlineBehavior.NONE;\
        invalidateSelf();\
    }\
    // Alice patch end 9999' "$path1"

# 3) 地址栏右侧按钮的合成底色也同步透明。
sed -i '/^            mOptionalButtonCoordinator\.setBackgroundColorFilter(color);$/c\
            // Alice patch start 9999\
            mOptionalButtonCoordinator.setBackgroundColorFilter(\
                    android.graphics.Color.TRANSPARENT);\
            // Alice patch end 9999' "$path2"

sed -i '/^            mOptionalButtonCoordinator\.setBackgroundColorFilter(mCurrentLocationBarColor);$/c\
            // Alice patch start 9999\
            mOptionalButtonCoordinator.setBackgroundColorFilter(\
                    android.graphics.Color.TRANSPARENT);\
            // Alice patch end 9999' "$path2"

# 4) 工具栏由 compositor 绘制时，URL 栏颜色也保持完全透明。
sed -i '/^    private @ColorInt int getUrlBarBackgroundColor(Tab tab, @ColorInt int backgroundColor) {$/,/^    }$/c\
    // Alice patch start 9999\
    private @ColorInt int getUrlBarBackgroundColor(Tab tab, @ColorInt int backgroundColor) {\
        return android.graphics.Color.TRANSPARENT;\
    }\
    // Alice patch end 9999' "$path3"
