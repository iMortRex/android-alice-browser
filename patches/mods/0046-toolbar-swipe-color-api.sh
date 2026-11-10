#!/bin/bash
# 工具栏横滑颜色 API：提供临时更新工具栏和地址栏颜色的入口。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ControlContainer.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarControlContainer.java"
path3="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/Toolbar.java"
path4="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarCoordinator.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarLayout.java"
path6="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"

# 检测是否已应用
if grep -q 'Alice patch start 0046' "$path1"; then
    exit 100
fi

# 在 ControlContainer 中增加横滑临时颜色入口。
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0046\
import androidx.annotation.ColorInt;\
// Alice patch end 0046' "$path1"

# 声明横滑期间更新工具栏和地址栏颜色的方法。
sed -i '/^    int getToolbarBackgroundColor();$/a\
\
    // Alice patch start 0046\
    /** Sets toolbar and location bar colors during a horizontal swipe. */\
    void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor);\
    // Alice patch end 0046' "$path1"

# 在 ToolbarControlContainer 中同步容器底色和真实工具栏颜色。
sed -i '/^import androidx\.annotation\.IntDef;$/i\
// Alice patch start 0046\
import androidx.annotation.ColorInt;\
// Alice patch end 0046' "$path2"

# 实现横滑临时颜色更新，并主动重绘工具栏资源。
sed -i 's|^    public int getToolbarHeight() {$|    // Alice patch start 0046\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {\
        setBackgroundColor(toolbarColor);\
        if (mToolbar != null) {\
            mToolbar.setToolbarColorsForSwipe(toolbarColor, locationBarColor);\
        }\
        getToolbarResourceAdapter().invalidate(/* dirtyRect= */ null);\
    }\
    // Alice patch end 0046\
\
    @Override\
    public int getToolbarHeight() {|' "$path2"

# 在 Toolbar 接口中声明横滑临时颜色入口。
sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0046\
import androidx.annotation.ColorInt;\
// Alice patch end 0046' "$path3"

# 增加工具栏和地址栏的横滑颜色方法声明。
sed -i '/^    int getPrimaryColor();$/a\
\
    // Alice patch start 0046\
    /** Sets toolbar and location bar colors during a horizontal swipe. */\
    void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor);\
    // Alice patch end 0046' "$path3"

# 由 TopToolbarCoordinator 将颜色转发给具体 ToolbarLayout。
# 实现颜色转发方法。
sed -i 's|^    public void getPositionRelativeToContainer(View containerView, int\[\] position) {$|    // Alice patch start 0046\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {\
        mToolbarLayout.setToolbarColorsForSwipe(toolbarColor, locationBarColor);\
    }\
    // Alice patch end 0046\
\
    @Override\
    public void getPositionRelativeToContainer(View containerView, int\[\] position) {|' "$path4"

# ToolbarLayout 提供空实现，由手机布局覆盖。
# 增加默认为空实现的横滑颜色方法。
sed -i '/^    protected void setToolbarHairlineColor(@ColorInt int toolbarColor) {$/i\
    // Alice patch start 0046\
    /** Applies temporary toolbar and location bar colors during a horizontal swipe. */\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {}\
    // Alice patch end 0046\
\
' "$path5"

# ToolbarPhone 实现工具栏和地址栏颜色更新。
# 应用横滑临时颜色并通知相关观察者。
sed -i '/^    private void updateToolbarBackgroundFromState(@VisualState int visualState) {$/i\
    // Alice patch start 0046\
    @Override\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {\
        updateToolbarBackground(toolbarColor);\
        updateModernLocationBarColor(locationBarColor);\
    }\
    // Alice patch end 0046\
\
' "$path6"
