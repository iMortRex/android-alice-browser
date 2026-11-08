#!/bin/bash
# 工具栏左右滑动时，按滑动进度混合相邻标签页的主题色。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ControlContainer.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarControlContainer.java"
path3="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/Toolbar.java"
path4="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarCoordinator.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarLayout.java"
path6="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0046' "$path1"; then
    exit 100
fi

# 1) 给 ControlContainer 增加滑动期间的临时背景色入口。
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0046\
import androidx.annotation.ColorInt;\
// Alice patch end 0046' "$path1"

sed -i '/^    int getToolbarBackgroundColor();$/a\
\
    // Alice patch start 0046\
    /** Sets toolbar and location bar colors during a horizontal swipe. */\
    void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor);\
    // Alice patch end 0046' "$path1"

# 2) ToolbarControlContainer 同时更新自己的底色和真实工具栏。
sed -i '/^import androidx\.annotation\.IntDef;$/i\
// Alice patch start 0046\
import androidx.annotation.ColorInt;\
// Alice patch end 0046' "$path2"

sed -i 's|^    public int getToolbarHeight() {$|    // Alice patch start 0046\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {\
        setBackgroundColor(toolbarColor);\
        if (mToolbar != null) {\
            mToolbar.setToolbarColorsForSwipe(toolbarColor, locationBarColor);\
        }\
    }\
    // Alice patch end 0046\
\
    @Override\
    public int getToolbarHeight() {|' "$path2"

# 3) Toolbar 接口增加滑动期间的临时主题色入口。
sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0046\
import androidx.annotation.ColorInt;\
// Alice patch end 0046' "$path3"

sed -i '/^    int getPrimaryColor();$/a\
\
    // Alice patch start 0046\
    /** Sets toolbar and location bar colors during a horizontal swipe. */\
    void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor);\
    // Alice patch end 0046' "$path3"

# 4) TopToolbarCoordinator 将颜色转发给具体的 ToolbarLayout。
sed -i 's|^    public void getPositionRelativeToContainer(View containerView, int\[\] position) {$|    // Alice patch start 0046\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {\
        mToolbarLayout.setToolbarColorsForSwipe(toolbarColor, locationBarColor);\
    }\
    // Alice patch end 0046\
\
    @Override\
    public void getPositionRelativeToContainer(View containerView, int\[\] position) {|' "$path4"

# 5) ToolbarLayout 默认不处理，由手机布局覆盖。
sed -i '/^    protected void setToolbarHairlineColor(@ColorInt int toolbarColor) {$/i\
    // Alice patch start 0046\
    /** Applies temporary toolbar and location bar colors during a horizontal swipe. */\
    public void setToolbarColorsForSwipe(\
            @ColorInt int toolbarColor, @ColorInt int locationBarColor) {}\
    // Alice patch end 0046\
\
' "$path5"

# 6) ToolbarPhone 同时更新工具栏、地址栏、可选按钮和系统颜色观察者。
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

# 7) ToolbarSwipeLayout 按滑动进度混合相邻标签页的主题色。
sed -i '/^import org\.chromium\.ui\.interpolators\.Interpolators;$/a\
// Alice patch start 0046\
import org.chromium.ui.util.ColorUtils;\
// Alice patch end 0046' "$path7"

sed -i '/^    private final @Nullable View mControlView;$/a\
    // Alice patch start 0046\
    private final @Nullable ControlContainer mControlContainer;\
    private boolean mAliceSwipeThemeEnabled;\
    private int mAliceSwipeStartToolbarColor;\
    private int mAliceSwipeEndToolbarColor;\
    private int mAliceSwipeStartLocationBarColor;\
    private int mAliceSwipeEndLocationBarColor;\
    // Alice patch end 0046' "$path7"

sed -i '/^        mControlView = controlContainer instanceof View ? (View) controlContainer : null;$/i\
        // Alice patch start 0046\
        mControlContainer = controlContainer;\
        // Alice patch end 0046' "$path7"

sed -i '/^            @ScrollDirection int direction, int fromIndex, int toIndex) {$/a\
        // Alice patch start 0046\
        mAliceSwipeThemeEnabled =\
                direction == ScrollDirection.LEFT || direction == ScrollDirection.RIGHT;\
        // Alice patch end 0046\
' "$path7"

sed -i '/^        List<Integer> visibleTabs = new ArrayList<>();$/i\
        // Alice patch start 0046\
        if (mAliceSwipeThemeEnabled) {\
            @Nullable LayoutTab aliceTargetTab =\
                    mFromTab == mLeftTab ? mRightTab : mLeftTab;\
            mAliceSwipeStartToolbarColor =\
                    mFromTab != null ? mFromTab.getToolbarBackgroundColor() : 0;\
            mAliceSwipeEndToolbarColor =\
                    aliceTargetTab != null\
                            ? aliceTargetTab.getToolbarBackgroundColor()\
                            : mAliceSwipeStartToolbarColor;\
            mAliceSwipeStartLocationBarColor =\
                    mFromTab != null ? mFromTab.getTextBoxBackgroundColor() : 0;\
            mAliceSwipeEndLocationBarColor =\
                    aliceTargetTab != null\
                            ? aliceTargetTab.getTextBoxBackgroundColor()\
                            : mAliceSwipeStartLocationBarColor;\
            updateAliceToolbarThemeColor(0f);\
        }\
        // Alice patch end 0046' "$path7"

sed -i '/^    public void swipeUpdated(long time, float x, float y, float dx, float dy, float tx, float ty) {$/i\
    // Alice patch start 0046\
    private void updateAliceToolbarThemeColor(float progress) {\
        if (!mAliceSwipeThemeEnabled || mControlContainer == null) return;\
        float clampedProgress = MathUtils.clamp(progress, 0f, 1f);\
        int toolbarColor =\
                ColorUtils.blendColorsMultiply(\
                        mAliceSwipeStartToolbarColor,\
                        mAliceSwipeEndToolbarColor,\
                        clampedProgress);\
        int locationBarColor =\
                ColorUtils.blendColorsMultiply(\
                        mAliceSwipeStartLocationBarColor,\
                        mAliceSwipeEndLocationBarColor,\
                        clampedProgress);\
        mControlContainer.setToolbarColorsForSwipe(toolbarColor, locationBarColor);\
    }\
    // Alice patch end 0046\
\
' "$path7"

sed -i '/^        mOffset = smoothInput(mOffset, mOffsetTarget);$/a\
        // Alice patch start 0046\
        updateAliceToolbarThemeColor(Math.abs(mOffset) / getWidth());\
        // Alice patch end 0046' "$path7"

# 8) 回弹和切 Tab 动画期间也持续更新颜色，并在终点强制落到正确颜色。
sed -i 's|^        if (duration <= 0) return;$|        // Alice patch start 0046\
        if (duration <= 0) {\
            mOffset = end;\
            mOffsetTarget = end;\
            updateAliceToolbarThemeColor(Math.abs(end) / getWidth());\
            return;\
        }\
        // Alice patch end 0046|' "$path7"

sed -i '/^                    mOffsetTarget = mOffset;$/a\
                    // Alice patch start 0046\
                    updateAliceToolbarThemeColor(Math.abs(mOffset) / getWidth());\
                    // Alice patch end 0046' "$path7"
