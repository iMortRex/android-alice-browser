#!/bin/bash
# 工具栏横滑颜色混合：按滑动进度混合相邻标签页的主题色。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/LayoutManagerImpl.java"
path3="chrome/browser/ui/android/theme/java/src/org/chromium/chrome/browser/theme/ToolbarThemeColorProvider.java"

# 检测是否已应用
if grep -q 'Alice patch start 0071' "$path1"; then
    exit 100
fi

# 补充颜色混合和主题色计算 import。
sed -i '/^import org\.chromium\.ui\.resources\.ResourceManager;$/a\
// Alice patch start 0071\
import org.chromium.ui.util.ColorUtils;\
// Alice patch end 0071' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.chrome\.browser\.theme\.ToolbarThemeColorProvider;$/i\
// Alice patch start 0071\
import org.chromium.chrome.browser.theme.ThemeUtils;\
// Alice patch end 0071' "$path1"

# 增加横滑颜色状态字段。
sed -i '/^    private final @Nullable View mControlView;$/a\
    // Alice patch start 0071\
    private final @Nullable ControlContainer mControlContainer;\
    private final ToolbarThemeColorProvider mToolbarThemeColorProvider;\
    private boolean mAliceSwipeThemeEnabled;\
    private int mAliceSwipeStartToolbarColor;\
    private int mAliceSwipeEndToolbarColor;\
    private int mAliceSwipeStartLocationBarColor;\
    private int mAliceSwipeEndLocationBarColor;\
    // Alice patch end 0071' "$path1"

# 保存横滑颜色更新所需的容器和主题色提供者。
sed -i '/^        mControlView = controlContainer instanceof View ? (View) controlContainer : null;$/i\
        // Alice patch start 0071\
        mControlContainer = controlContainer;\
        mToolbarThemeColorProvider = toolbarColorProvider;\
        // Alice patch end 0071' "$path1"

# 记录当前横滑方向是否启用主题色混合。
sed -i '/^            @ScrollDirection int direction, int fromIndex, int toIndex) {$/a\
        // Alice patch start 0071\
        mAliceSwipeThemeEnabled =\
                direction == ScrollDirection.LEFT || direction == ScrollDirection.RIGHT;\
        // Alice patch end 0071\
' "$path1"

# 横滑开始前缓存起止标签页的主题色。
sed -i '/^        List<Integer> visibleTabs = new ArrayList<>();$/i\
        // Alice patch start 0071\
        if (mAliceSwipeThemeEnabled) {\
            @Nullable LayoutTab aliceTargetTab =\
                    mFromTab == mLeftTab ? mRightTab : mLeftTab;\
            @Nullable Tab aliceFromTab = mTabModelSelector.getTabById(fromTabId);\
            @Nullable Tab aliceToTab = mTabModelSelector.getTabById(toTabId);\
            if (aliceFromTab != null \&\& aliceToTab != null) {\
                mAliceSwipeStartToolbarColor =\
                        mToolbarThemeColorProvider.getToolbarBackgroundColorForTab(\
                                aliceFromTab);\
                mAliceSwipeEndToolbarColor =\
                        mToolbarThemeColorProvider.getToolbarBackgroundColorForTab(\
                                aliceToTab);\
                mAliceSwipeStartLocationBarColor =\
                        ThemeUtils.getTextBoxColorForToolbarBackground(\
                                getContext(),\
                                aliceFromTab,\
                                mAliceSwipeStartToolbarColor);\
                mAliceSwipeEndLocationBarColor =\
                        ThemeUtils.getTextBoxColorForToolbarBackground(\
                                getContext(), aliceToTab, mAliceSwipeEndToolbarColor);\
            } else {\
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
            }\
            updateAliceToolbarThemeColor(0f);\
        }\
        // Alice patch end 0071' "$path1"

# 增加按滑动进度混合颜色的方法。
sed -i '/^    public void swipeUpdated(long time, float x, float y, float dx, float dy, float tx, float ty) {$/i\
    // Alice patch start 0071\
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
    // Alice patch end 0071\
\
' "$path1"

# 手势移动和缓动时持续更新混合颜色。
sed -i '/^        mOffsetTarget = MathUtils\.clamp(mOffsetStart + tx, 0, getWidth()) - mOffsetStart;$/a\
        // Alice patch start 0071\
        updateAliceToolbarThemeColor(Math.abs(mOffsetTarget) / getWidth());\
        // Alice patch end 0071' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^        mOffset = smoothInput(mOffset, mOffsetTarget);$/a\
        // Alice patch start 0071\
        updateAliceToolbarThemeColor(Math.abs(mOffset) / getWidth());\
        // Alice patch end 0071' "$path1"

# 回弹动画时持续更新颜色，零时长时直接落到终点颜色。
sed -i 's|^        if (duration <= 0) return;$|        // Alice patch start 0071\
        if (duration <= 0) {\
            mOffset = end;\
            mOffsetTarget = end;\
            updateAliceToolbarThemeColor(Math.abs(end) / getWidth());\
            return;\
        }\
        // Alice patch end 0071|' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^                    mOffsetTarget = mOffset;$/a\
                    // Alice patch start 0071\
                    updateAliceToolbarThemeColor(Math.abs(mOffset) / getWidth());\
                    // Alice patch end 0071' "$path1"

# 为指定 Tab 计算工具栏颜色，支持底置工具栏模式。
sed -i '/^    public @ColorInt int getToolbarBackgroundColor(Tab tab) {$/i\
    // Alice patch start 0071\
    /** 返回指定 Tab 的工具栏颜色，不依赖当前顶部或底部颜色提供者。 */\
    public @ColorInt int getToolbarBackgroundColorForTab(Tab tab) {\
        return mTopUiThemeColorProvider.getToolbarBackgroundColor(tab);\
    }\
    // Alice patch end 0071\
\
' "$path3"

# 布局管理器使用指定 Tab 的真实工具栏颜色。
sed -i 's|^        @ColorInt int toolbarBackgroundColor = toolbarTheme\.getToolbarBackgroundColor(tab);$|        // Alice patch start 0071\
        @ColorInt int toolbarBackgroundColor =\
                toolbarTheme.getToolbarBackgroundColorForTab(tab);\
        // Alice patch end 0071|' "$path2"
