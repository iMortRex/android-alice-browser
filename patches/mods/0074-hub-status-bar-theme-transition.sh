#!/bin/bash
# Hub 状态栏主题渐变：进入标签管理时变为其背景色，返回标签页时变为网页主题色。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/ui/system/StatusBarColorController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0074' "$path1"; then
    exit 100
fi

# 动画进度依赖。
sed -i '/^import android\.app\.Activity;$/i\
// Alice patch start 0074\
import android.animation.ValueAnimator;\
// Alice patch end 0074' "$path1"

sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsStateProvider\.ControlsPosition;$/a\
// Alice patch start 0074\
import org.chromium.chrome.browser.hub.HubAnimationConstants;\
// Alice patch end 0074' "$path1"

sed -i '/^import org\.chromium\.ui\.edge_to_edge\.EdgeToEdgeSystemBarColorHelper;$/a\
// Alice patch start 0074\
import org.chromium.ui.interpolators.Interpolators;\
// Alice patch end 0074' "$path1"

sed -i 's#^    private final Callback<Integer> mOverviewColorObserver = ignored -> updateStatusBarColor();$#    // Alice patch start 0074\
    private final Callback<Integer> mOverviewColorObserver =\
            ignored -> onAliceHubOverviewColorChanged();\
    // Alice patch end 0074#' "$path1"

# 记录状态栏动画状态和 Hub 背景色。
sed -i '/^    private boolean mAllowToolbarColorOnTablets;$/a\
    // Alice patch start 0074\
    private static final long ALICE_HUB_STATUS_ANIMATION_START_DELAY_MS = 80L;\
    private static final long ALICE_STATUS_BAR_FRAME_OVERRIDE_MS = 50L;\
    private @Nullable ValueAnimator mAliceHubStatusBarAnimator;\
    private boolean mAliceHubStatusBarTransitionActive;\
    private boolean mAliceHubAwaitingOverviewClear;\
    private boolean mAliceHubShowing;\
    private float mAliceHubTransitionFraction;\
    private @ColorInt int mAliceHubBackgroundColor = Color.TRANSPARENT;\
    private @ColorInt int mAliceLastBrowsingStatusBarColor = Color.TRANSPARENT;\
    private final AliceStatusBarColorTransitionController.Observer mAliceThemeColorObserver =\
            this::onAliceThemeColorChanged;\
    private final AliceStatusBarColorTransitionController mAliceThemeColorController;\
    // Alice patch end 0074' "$path1"

# 创建 Activity 级共享主题色控制器并订阅颜色变化。
sed -i '/^        mActivity = activity;$/a\
        // Alice patch start 0074\
        mAliceThemeColorController = AliceStatusBarColorTransitionController.forActivity(activity);\
        mAliceThemeColorController.addObserver(mAliceThemeColorObserver);\
        // Alice patch end 0074' "$path1"

# Hub 开始显示/隐藏时自行启动状态栏动画，避免依赖 Hub alpha 回调。
sed -i '/^                public void onFinishedHiding(@LayoutType int layoutType) {$/i\
                public void onStartedShowing(@LayoutType int layoutType) {\
                    if (layoutType == LayoutType.HUB) {\
                        // Alice patch start 0074\
                        startAliceHubStatusBarTransition(true);\
                        // Alice patch end 0074\
                    }\
                }\
\
                @Override\
                public void onStartedHiding(@LayoutType int layoutType) {\
                    if (layoutType == LayoutType.HUB) {\
                        // Alice patch start 0074\
                        startAliceHubStatusBarTransition(false);\
                        // Alice patch end 0074\
                    }\
                }\
\
                @Override\
                public void onFinishedShowing(@LayoutType int layoutType) {\
                    if (layoutType == LayoutType.BROWSING \&\& !mAliceHubShowing) {\
                        // Alice patch start 0074\
                        mAliceHubAwaitingOverviewClear = true;\
                        onAliceHubOverviewColorChanged();\
                        // Alice patch end 0074\
                    }\
                }\
\
                @Override\
' "$path1"

# 启动与预览缩略图缩放一致的 325ms 状态栏动画。
sed -i '/^    public void setTabStripHiddenOnTablet(boolean tabStripHiddenOnTablet) {$/i\
    // Alice patch start 0074\
    private void animateAliceHubStatusBarColorForFrame(@ColorInt int color) {\
        int token = mAliceThemeColorController.animateTo(color, 0L);\
        mActivity.getWindow().getDecorView().postDelayed(\
                () -> mAliceThemeColorController.clearOverride(token),\
                ALICE_STATUS_BAR_FRAME_OVERRIDE_MS);\
    }\
\
    private void onAliceHubOverviewColorChanged() {\
        if (mAliceHubAwaitingOverviewClear\
                \&\& Color.alpha(mOverviewColorSupplier.get()) == 0) {\
            mAliceHubAwaitingOverviewClear = false;\
        }\
        updateStatusBarColor();\
    }\
\
    private void onAliceThemeColorChanged(@ColorInt int color) {\
        if (color != mAliceThemeColorController.getCurrentColor()) return;\
        updateStatusBarColor();\
    }\
\
    private void startAliceHubStatusBarTransition(boolean showingHub) {\
        @ColorInt int targetColor =\
                showingHub\
                        ? getAliceHubBackgroundColorForStatusBar()\
                        : getAlicePageThemeColorForStatusBar();\
        long durationMs =\
                showingHub\
                        ? Math.round(\
                                HubAnimationConstants.HUB_LAYOUT_SHRINK_EXPAND_DURATION_MS * 0.55f)\
                        : Math.round(\
                                HubAnimationConstants.HUB_LAYOUT_SHRINK_EXPAND_DURATION_MS * 2.4f);\
        mAliceHubAwaitingOverviewClear = false;\
        @ColorInt int startColor =\
                mAliceThemeColorController.hasColor()\
                        ? mAliceThemeColorController.getCurrentColor()\
                        : getAlicePageThemeColorForStatusBar();\
        mAliceThemeColorController.animateTo(startColor, targetColor, durationMs);\
        if (showingHub\
                \&\& (!mAliceHubStatusBarTransitionActive || !mAliceHubShowing)\
                \&\& Color.alpha(mStatusBarColorWithoutStatusIndicator) != 0) {\
            mAliceLastBrowsingStatusBarColor =\
                    ColorUtils.getOpaqueColor(mStatusBarColorWithoutStatusIndicator);\
        }\
        if (mAliceHubStatusBarTransitionActive\
                \&\& mAliceHubShowing == showingHub\
                \&\& mAliceHubStatusBarAnimator != null\
                \&\& mAliceHubStatusBarAnimator.isRunning()) {\
            return;\
        }\
        if (mAliceHubStatusBarAnimator != null) {\
            mAliceHubStatusBarAnimator.cancel();\
        }\
        mAliceHubStatusBarTransitionActive = true;\
        mAliceHubShowing = showingHub;\
        mAliceHubTransitionFraction = 0f;\
        int aliceOverviewColor = mOverviewColorSupplier.get();\
        if (Color.alpha(aliceOverviewColor) != 0) {\
            mAliceHubBackgroundColor = ColorUtils.getOpaqueColor(aliceOverviewColor);\
        }\
        ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);\
        animator.setDuration(\
            showingHub\
                ? Math.round(\
                        HubAnimationConstants.HUB_LAYOUT_SHRINK_EXPAND_DURATION_MS * 0.55f)\
                : Math.round(\
                        HubAnimationConstants.HUB_LAYOUT_SHRINK_EXPAND_DURATION_MS * 2.4f);\
        animator.setStartDelay(\
                showingHub ? 0L : ALICE_HUB_STATUS_ANIMATION_START_DELAY_MS);\
        animator.setInterpolator(Interpolators.EMPHASIZED);\
        animator.addUpdateListener(\
                animation -> setAliceHubTransitionProgress(\
                        showingHub, animation.getAnimatedFraction()));\
        mAliceHubStatusBarAnimator = animator;\
        updateStatusBarColor();\
        animator.start();\
    }\
\
    private void setAliceHubTransitionProgress(boolean showingHub, float fraction) {\
        float aliceFraction = Math.max(0f, Math.min(1f, fraction));\
        if (!mAliceHubStatusBarTransitionActive || mAliceHubShowing != showingHub) {\
            mAliceHubTransitionFraction = 0f;\
        } else if (aliceFraction + 0.001f >= mAliceHubTransitionFraction) {\
            mAliceHubTransitionFraction = aliceFraction;\
        }\
        mAliceHubStatusBarTransitionActive = true;\
        mAliceHubShowing = showingHub;\
        int aliceOverviewColor = mOverviewColorSupplier.get();\
        if (Color.alpha(aliceOverviewColor) != 0) {\
            mAliceHubBackgroundColor = ColorUtils.getOpaqueColor(aliceOverviewColor);\
        }\
        updateStatusBarColor();\
    }\
\
    private @ColorInt int getAliceBrowserThemeColorForStatusBar() {\
        return mIsIncognitoBranded\
                ? mIncognitoDefaultThemeColor\
                : mStandardDefaultThemeColor;\
    }\
\
    private @ColorInt int getAlicePageThemeColorForStatusBar() {\
        if (mAliceHubShowing \&\& mAliceLastBrowsingStatusBarColor != Color.TRANSPARENT) {\
            return mAliceLastBrowsingStatusBarColor;\
        }\
        if (mCurrentTab == null) return getAliceBrowserThemeColorForStatusBar();\
        return mTopUiThemeColor.getToolbarBackgroundColor(mCurrentTab);\
    }\
\
    private @ColorInt int getAliceHubBackgroundColorForStatusBar() {\
        int aliceOverviewColor = mOverviewColorSupplier.get();\
        if (Color.alpha(aliceOverviewColor) != 0) {\
            mAliceHubBackgroundColor = ColorUtils.getOpaqueColor(aliceOverviewColor);\
        }\
        return mAliceHubBackgroundColor != Color.TRANSPARENT\
                ? mAliceHubBackgroundColor\
                : getAliceBrowserThemeColorForStatusBar();\
    }\
\
    private @ColorInt int applyAliceHubStatusBarTransition(@ColorInt int fallbackColor) {\
        if (mIsOmniboxFocused || !mAliceHubStatusBarTransitionActive) return fallbackColor;\
        float aliceHubFraction =\
                mAliceHubShowing\
                        ? mAliceHubTransitionFraction\
                        : 1f - mAliceHubTransitionFraction;\
        return ColorUtils.getOpaqueColor(\
                ColorUtils.blendColorsOklab(\
                        getAlicePageThemeColorForStatusBar(),\
                        getAliceHubBackgroundColorForStatusBar(),\
                        aliceHubFraction));\
    }\
\
    // Alice patch end 0074
' "$path1"

# 非 Hub 状态下缓存浏览页状态栏颜色，作为进入 Hub 的渐变起点。
sed -i '/^        @ColorInt int statusBarColor = calculateFinalStatusBarColor();$/a\
        // Alice patch start 0074\
        if (!mAliceHubStatusBarTransitionActive \&\& !mAliceHubShowing) {\
            mAliceLastBrowsingStatusBarColor = statusBarColor;\
        }\
        // Alice patch end 0074' "$path1"

# toolbar 真正开始更新时退出 Hub override，恢复横滑状态栏渐变的入口。
sed -i '/^        mToolbarColor = color;$/a\
        // Alice patch start 0074\
        if (mAliceHubStatusBarTransitionActive || mAliceHubShowing) {\
            animateAliceHubStatusBarColorForFrame(color);\
            mAliceHubAwaitingOverviewClear = false;\
            mAliceHubStatusBarTransitionActive = false;\
            if (mAliceHubStatusBarAnimator != null) {\
                mAliceHubStatusBarAnimator.cancel();\
                mAliceHubStatusBarAnimator = null;\
            }\
            if (mAliceThemeColorController.hasColor()) return;\
        }\
        // Alice patch end 0074' "$path1"

# 在 overview/scrim 最终合成后应用渐变，避免 Hub 背景色覆盖逐帧混合结果。
sed -i 's|^        return statusBarColor;$|        // Alice patch start 0074\
        int aliceFinalColor = applyAliceHubStatusBarTransition(statusBarColor);\
        return mAliceThemeColorController.isOverriding()\
                ? mAliceThemeColorController.getCurrentColor()\
                : aliceFinalColor;\
        // Alice patch end 0074|' "$path1"

# 销毁时停止动画。
sed -i '/^    public void onDestroy() {$/a\
        // Alice patch start 0074\
        mAliceThemeColorController.removeObserver(mAliceThemeColorObserver);\
        AliceStatusBarColorTransitionController.releaseForActivity(mActivity);\
        if (mAliceHubStatusBarAnimator != null) {\
            mAliceHubStatusBarAnimator.cancel();\
            mAliceHubStatusBarAnimator = null;\
        }\
        // Alice patch end 0074' "$path1"
