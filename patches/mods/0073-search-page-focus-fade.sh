#!/bin/bash
# 进入和退出搜索页时，搜索页背景、搜索框、推荐列表统一渐隐渐显。
#
# 元素归属（源码核实）：
#  - 搜索框内容 = mLocationBar.getContainerView()（LocationBarLayout），是 ToolbarPhone 的子 View；
#  - 搜索框背景 = mLocationBarBackground（旧路径由 dispatchDraw 直接画）或
#    mActiveLocationBarBackgroundView + setBackground(mToolbarBackground)（refactor 路径，view 背景）；
#  - 搜索页纯色/0039 渐变背景同样由 ToolbarPhone 绘制。
# 因此在 ToolbarPhone.draw()（view 背景不走 dispatchDraw）整体套 canvas alpha 层。
#
# 退出搜索页时上游会在同一帧内瞬时切换到未聚焦状态（endFocusTransition 同步 snap）：
#  - updateNtpTransitionAnimation/updateToolbarAndLocationBarColorForFocusChange 立刻把
#    工具栏和地址栏颜色切回主题色；
#  - onFocusTransitionEnd 立刻隐藏搜索框（PhoneCoordinator alpha 0）并显示 NTP fakebox；
#  - updateBackground(false) 立刻把地址栏背景重置为 NTP 样式；
#  - endUrlFocusAnimation 立刻结束 refactored transition，搜索框内容/几何瞬间变成地址栏。
# 若不拦截，canvas 里已没有搜索页可淡出。因此淡出期间冻结以上视觉
# （mAliceSearchPageFadeOutDeferring），其中焦点动画改为让 transition 在淡化层下完整
# 跑完 225ms（与淡化同长），搜索框随过渡渐变成地址栏；淡出结束（canvas alpha 已为 0）
# 时统一应用其余视觉，再执行 150ms 工具栏回填淡入。
#
# 推荐列表在 ToolbarPhone 之外：统一 alpha 通过 OmniboxSuggestionsContainer 的静态入口
# 驱动当前可见容器的 view alpha；endInput() 把 propagateOmniboxSessionStateChange(false)
# 和 clearSuggestions() 的视觉收尾延迟 225ms（与淡化动画同长），期间会话仍标记为活跃，
# 容器保持 VISIBLE 由 alpha 淡出，延迟任务触发后一次性 GONE。beginInput() 立即取消延迟。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListViewBinder.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0073' "$path1" || grep -q 'Alice patch start 0073' "$path2" \
    || grep -q 'Alice patch start 0073' "$path5"; then
    exit 100
fi

# --- ToolbarPhone：整体淡化状态与动画 ---

# 搜索页淡化状态字段。
sed -i '/^    private boolean mDropdownListScrolled;$/a\
    // Alice patch start 0073\
    private static final long ALICE_SEARCH_PAGE_FADE_DURATION_MS = 225;\
    private static final long ALICE_SEARCH_PAGE_RESTORE_DURATION_MS = 150;\
    private @Nullable ValueAnimator mAliceSearchPageFadeAnimator;\
    private float mAliceSearchPageFadeAlpha = 1f;\
    private boolean mAliceSearchPageFadeActive;\
    private boolean mAliceSearchPageShown;\
    private static boolean mAliceSearchPageFadeOutDeferring;\
    private @Nullable ValueAnimator mAliceSearchPageColorFadeAnimator;\
    // Alice patch end 0073\
' "$path1"

# 地址栏焦点变化时启动整页淡化（与 URL_FOCUS_CHANGE_ANIMATION_DURATION_MS 同长）。
sed -i '/^        super\.onUrlFocusChange(hasFocus);$/a\
        // Alice patch start 0073\
        animateAliceSearchPageFade(hasFocus);\
        // Alice patch end 0073\
' "$path1"

# 淡化动画驱动：shown 表示搜索页视觉正在展示；淡出期间冻结上游的未聚焦瞬时切换，
# 淡出结束后统一应用（applyAliceDeferredUnfocusVisuals），再把未聚焦工具栏淡入回来。
sed -i '/^    private void updateToolbarBackground(@ColorInt int color) {$/i\
    // Alice patch start 0073\
    private void animateAliceSearchPageFade(boolean hasFocus) {\
        boolean aliceWasActive = mAliceSearchPageFadeActive;\
        boolean aliceWasShown = mAliceSearchPageShown;\
\
        if (!hasFocus \&\& !aliceWasShown) {\
            // 非搜索页状态（含工具栏回填动画进行中），无需处理。\
            return;\
        }\
\
        if (mAliceSearchPageFadeAnimator != null) {\
            mAliceSearchPageFadeAnimator.cancel();\
            mAliceSearchPageFadeAnimator = null;\
        }\
        // Alice patch start 0073\
        if (mAliceSearchPageColorFadeAnimator != null) {\
            mAliceSearchPageColorFadeAnimator.cancel();\
            mAliceSearchPageColorFadeAnimator = null;\
        }\
        // Alice patch end 0073\
\
        if (hasFocus) {\
            mAliceSearchPageFadeOutDeferring = false;\
            mAliceSearchPageShown = true;\
            float aliceStart =\
                    aliceWasActive\
                            ? mAliceSearchPageFadeAlpha\
                            : (aliceWasShown ? 1f : 0f);\
            startAliceSearchPageFade(\
                    aliceStart, 1f, ALICE_SEARCH_PAGE_FADE_DURATION_MS);\
        } else {\
            mAliceSearchPageFadeOutDeferring = true;\
            float aliceStart = aliceWasActive ? mAliceSearchPageFadeAlpha : 1f;\
            if (aliceStart <= 0f) {\
                mAliceSearchPageShown = false;\
                applyAliceDeferredUnfocusVisuals();\
                startAliceSearchPageRestore();\
                return;\
            }\
            startAliceSearchPageFade(\
                    aliceStart, 0f, ALICE_SEARCH_PAGE_FADE_DURATION_MS);\
        }\
    }\
\
    /** 退出颜色交叉渐变：聚焦浅色 → 未聚焦深色，与 alpha 淡出同步。 */\
    private void startAliceSearchPageColorFade() {\
        boolean aliceInGeneralNtp = isLocationBarShownInGeneralNtp();\
        @ColorInt int alicePrimary =\
                aliceInGeneralNtp\
                        ? mToolbarBackgroundColorForNtp\
                        : getToolbarDataProvider().getPrimaryColor();\
        @ColorInt int aliceStartToolbar = mToolbarBackground.getColor();\
        @ColorInt int aliceStartLocBar = mCurrentLocationBarColor;\
        @ColorInt int aliceEndLocBar =\
                getLocationBarColorForToolbarColor(alicePrimary);\
        ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);\
        animator.setDuration(ALICE_SEARCH_PAGE_FADE_DURATION_MS);\
        animator.setInterpolator(Interpolators.FAST_OUT_SLOW_IN_INTERPOLATOR);\
        animator.addUpdateListener(\
                animation -> {\
                    float aliceFraction = animation.getAnimatedFraction();\
                    mToolbarBackground.setColor(\
                            ColorUtils.blendColorsMultiply(\
                                    aliceStartToolbar,\
                                    alicePrimary,\
                                    aliceFraction));\
                    updateModernLocationBarColor(\
                            ColorUtils.blendColorsMultiply(\
                                    aliceStartLocBar,\
                                    aliceEndLocBar,\
                                    aliceFraction));\
                });\
        mAliceSearchPageColorFadeAnimator = animator;\
        animator.start();\
    }\
\
    private void startAliceSearchPageRestore() {\
        startAliceSearchPageFade(\
                0f, 1f, ALICE_SEARCH_PAGE_RESTORE_DURATION_MS);\
    }\
\
    private void startAliceSearchPageFade(float start, float target, long duration) {\
        mAliceSearchPageFadeActive = true;\
        if (start >= 1f \&\& target >= 1f) {\
            finishAliceSearchPageFade();\
            return;\
        }\
\
        ValueAnimator animator = ValueAnimator.ofFloat(start, target);\
        animator.setDuration(duration);\
        animator.setInterpolator(Interpolators.FAST_OUT_SLOW_IN_INTERPOLATOR);\
        animator.addUpdateListener(\
                animation ->\
                        setAliceSearchPageFadeAlpha(\
                                (float) animation.getAnimatedValue()));\
        animator.addListener(\
                new CancelAwareAnimatorListener() {\
                    @Override\
                    public void onEnd(Animator animation) {\
                        if (mAliceSearchPageFadeAnimator != animation) return;\
                        if (target < 1f) {\
                            // 淡出结束：canvas 已透明，此时应用被冻结的\
                            // 未聚焦视觉不会被发现。\
                            mAliceSearchPageShown = false;\
                            applyAliceDeferredUnfocusVisuals();\
                            startAliceSearchPageRestore();\
                        } else {\
                            finishAliceSearchPageFade();\
                        }\
                    }\
                });\
        mAliceSearchPageFadeAnimator = animator;\
        animator.start();\
    }\
\
    private void setAliceSearchPageFadeAlpha(float alpha) {\
        mAliceSearchPageFadeAlpha = MathUtils.clamp(alpha, 0f, 1f);\
        OmniboxSuggestionsContainer.setAliceSearchPageFadeAlpha(\
                mAliceSearchPageFadeAlpha);\
        invalidate();\
    }\
\
    private void finishAliceSearchPageFade() {\
        mAliceSearchPageFadeAnimator = null;\
        mAliceSearchPageFadeActive = false;\
        setAliceSearchPageFadeAlpha(1f);\
    }\
\
    /** 淡出冻结状态，供 ToolbarPositionController 的模拟导航栏读取。 */\
    public static boolean aliceIsSearchPageFadeOutDeferring() {\
        return mAliceSearchPageFadeOutDeferring;\
    }\
\
    private void applyAliceDeferredUnfocusVisuals() {\
        mAliceSearchPageFadeOutDeferring = false;\
        updateBackground(false);\
        updateToolbarBackgroundFromState(mVisualState);\
        updateToolbarAndLocationBarColorForFocusChange();\
        if (isLocationBarShownInNtp()\
                \&\& mNtpSearchBoxScrollFraction != 1.f\
                \&\& !urlHasFocus()) {\
            getToolbarDataProvider()\
                    .getNewTabPageDelegate()\
                    .setSearchBoxAlpha(1.f);\
            updateLocationBarTranslationOnScroll();\
            mLocationBar.getPhoneCoordinator().setAlpha(0.f);\
            mActiveLocationBarBackgroundView.setAlpha(0.f);\
        }\
        invalidate();\
    }\
    // Alice patch end 0073\
\
' "$path1"

# draw() 整体套一层 canvas alpha：view 背景（refactor 路径的 setBackground）、
# dispatchDraw 里画的内容（旧路径背景、0039 渐变）、搜索框内容全部包含在内。
# 纹理捕获模式不加层，避免快照带上半透明。
sed -i 's|^    public void draw(Canvas canvas) {$|    // Alice patch start 0073\n    public void draw(Canvas canvas) {\n        int aliceFadeLayer = -1;\n        if (!mTextureCaptureMode\n                \&\& mAliceSearchPageFadeActive\n                \&\& mAliceSearchPageFadeAlpha < 1f) {\n            aliceFadeLayer =\n                    canvas.saveLayerAlpha(\n                            0,\n                            0,\n                            getWidth(),\n                            getHeight(),\n                            Math.round(mAliceSearchPageFadeAlpha * 255));\n        }\n        aliceDrawWithFadeInner(canvas);\n        if (aliceFadeLayer >= 0) {\n            canvas.restoreToCount(aliceFadeLayer);\n        }\n    }\n\n    private void aliceDrawWithFadeInner(Canvas canvas) {\n    // Alice patch end 0073|' "$path1"

# 关闭或销毁时终止淡化动画并复位。
sed -i '/^    private void cancelAnimations() {$/a\
        // Alice patch start 0073\
        if (mAliceSearchPageFadeAnimator != null) {\
            mAliceSearchPageFadeAnimator.cancel();\
            mAliceSearchPageFadeAnimator = null;\
        }\
        // Alice patch start 0073\
        if (mAliceSearchPageColorFadeAnimator != null) {\
            mAliceSearchPageColorFadeAnimator.cancel();\
            mAliceSearchPageColorFadeAnimator = null;\
        }\
        // Alice patch end 0073\
        mAliceSearchPageFadeActive = false;\
        mAliceSearchPageShown = false;\
        mAliceSearchPageFadeOutDeferring = false;\
        setAliceSearchPageFadeAlpha(1f);\
        // Alice patch end 0073\
' "$path1"

# 冻结点 1：淡出期间不回退工具栏/地址栏颜色。
sed -i '/^    private void updateToolbarAndLocationBarColorForFocusChange() {$/a\
        // Alice patch start 0073\
        if (mAliceSearchPageFadeOutDeferring) return;\
        // Alice patch end 0073\
' "$path1"

# 冻结点 2：淡出期间不按视觉状态回退工具栏颜色（refactor 路径）。
sed -i '/^            \/\/ TODO(crbug\.com\/425817689): We still need to update the color here, though, since this$/i\
            // Alice patch start 0073\
            if (mAliceSearchPageFadeOutDeferring) return;\
            // Alice patch end 0073\
' "$path1"

# 冻结点 3：淡出期间不把地址栏背景重置为 NTP 样式。
sed -i '/^        } else if (isLocationBarShownInNtp()) {$/,/^        }$/ s|^            updateToNtpBackground();$|            // Alice patch start 0073\
            if (!mAliceSearchPageFadeOutDeferring) {\
                updateToNtpBackground();\
            }\
            // Alice patch end 0073|' "$path1"

# 冻结点 4：淡出期间不隐藏搜索框、不显示 NTP fakebox。
sed -i 's|^            if (mNtpSearchBoxScrollFraction != 1\.f) {$|            // Alice patch start 0073\n            if (mNtpSearchBoxScrollFraction != 1.f\n                    \&\& !mAliceSearchPageFadeOutDeferring) {\n            // Alice patch end 0073|' "$path1"

# 冻结点 5：淡出期间不立即结束焦点动画。上游 unfocus 是 beginDelayedTransition
# 之后立刻 endTransitions 强制跳变，搜索框内容/几何会在淡出开始前瞬间变成地址栏。
# 跳过后 transition 在淡化层下完整跑 225ms（与淡化同长），搜索框随过渡渐变成
# 地址栏形态；applyAliceDeferredUnfocusVisuals 结束时如仍在进行则补收尾。
sed -i '/^        if (!hasFocus || mLocationBar\.shouldShortCircuitFocusAnimation(true)) {$/i\
        // Alice patch start 0073\
        if (!mAliceSearchPageFadeOutDeferring) {\
        // Alice patch end 0073\
' "$path1"

sed -i '/^            TraceEvent\.instant("ToolbarPhone\.ShortCircuitUnfocusAnimation");$/,/^        }$/ s|^        }$|        }\n        // Alice patch start 0073\n        }\n        // Alice patch end 0073|' "$path1"

# applyAliceDeferredUnfocusVisuals：transition 仍在进行时补一次强制收尾
# （正常情况下它已在淡化结束前自然完成，此处跳过）。
sed -i '/^        if (isLocationBarShownInNtp()$/i\
        // Alice patch start 0073\
        if (mUrlFocusChangeInProgress) {\
            endUrlFocusAnimation();\
        }\
        // Alice patch end 0073\
' "$path1"

# 冻结点 6：淡出期间 hairline 保持隐藏（hairline 是 control_container 的兄弟 View，
# 不在 canvas 层内，聚焦浅色会直接弹出），applyDeferred 里恢复为深色。
sed -i '/^                && getVisibility() == View\.VISIBLE;$/i\
                // Alice patch start 0073\
                \&\& !mAliceSearchPageFadeOutDeferring\
                // Alice patch end 0073\
' "$path1"

sed -i '/^        if (isLocationBarShownInNtp()$/i\
        // Alice patch start 0073\
        updateHairlineVisibility();\
        // Alice patch end 0073\
' "$path1"

# 冻结点 7：淡出期间模拟导航栏（0033，同样在 canvas 层外）保持隐藏，
# 颜色随 applyDeferred 的 updateToolbarBackground 通知恢复为深色后再显示。
sed -i '/^import org\.chromium\.chrome\.browser\.toolbar\.top\.ToolbarLayout;$/a\
// Alice patch start 0073\
import org.chromium.chrome.browser.toolbar.top.ToolbarPhone;\
// Alice patch end 0073\
' "$path5"

sed -i '/^                        && !mIsOmniboxFocusedSupplier\.get()$/a\
                        // Alice patch start 0073\
                        \&\& !ToolbarPhone.aliceIsSearchPageFadeOutDeferring()\
                        // Alice patch end 0073\
' "$path5"

# 冻结点 8：淡出期间把 hairline 从 refactored transition 中排除——transition 的
# Fade 会强制目标 View 可见并直接改 alpha，绕过 shouldDrawHairline 的可见性冻结，
# 使 hairline 以聚焦浅色在 canvas 层外闪现。恢复统一由 applyDeferred 负责。
sed -i 's|^                        \.addTransition(new Fade()\.addTarget(getToolbarHairline()))$|                        // Alice patch start 0073\n                        // 淡出期间不由 transition 淡入 hairline（它在 canvas 层外，会以聚焦浅色闪现）。\n                        // Alice patch end 0073|' "$path1"

sed -i '/^                        \.setInterpolator(interpolator);$/a\
                        // Alice patch start 0073\
                        if (!mAliceSearchPageFadeOutDeferring) {\
                            locationBarTransition.addTransition(\
                                    new Fade().addTarget(getToolbarHairline()));\
                        }\
                        // Alice patch end 0073\
' "$path1"

# OmniboxSuggestionsContainer 供统一 alpha 驱动当前可见的建议容器。
sed -i '/^import org\.chromium\.chrome\.browser\.omnibox\.suggestions\.OmniboxSuggestionsDropdownScrollListener;$/a\
// Alice patch start 0073\
import org.chromium.chrome.browser.omnibox.suggestions.OmniboxSuggestionsContainer;\
// Alice patch end 0073\
' "$path1"

# --- OmniboxSuggestionsContainer：统一 alpha 的静态入口 ---

sed -i '/^    \/\*\* Clean up resources and remove observers installed by this class\. \*\/$/i\
    // Alice patch start 0073\
    private static float sAliceSearchPageFadeAlpha = 1f;\
    private static @Nullable OmniboxSuggestionsContainer sAliceSearchPageFadeInstance;\
\
    /** ToolbarPhone 统一搜索页淡化 alpha；作用于当前可见的建议容器。 */\
    public static void setAliceSearchPageFadeAlpha(float alpha) {\
        sAliceSearchPageFadeAlpha = Math.max(0f, Math.min(1f, alpha));\
        OmniboxSuggestionsContainer aliceInstance = sAliceSearchPageFadeInstance;\
        if (aliceInstance != null) {\
            aliceInstance.setAlpha(sAliceSearchPageFadeAlpha);\
        }\
    }\
\
    /** 建议容器可见时注册为淡化目标，并同步当前淡化进度。 */\
    public void registerAliceSearchPageFadeInstance() {\
        sAliceSearchPageFadeInstance = this;\
        setAlpha(sAliceSearchPageFadeAlpha);\
    }\
    // Alice patch end 0073\
\
' "$path3"

sed -i '/^        mDropdown\.destroy();$/i\
        // Alice patch start 0073\
        if (sAliceSearchPageFadeInstance == this) {\
            sAliceSearchPageFadeInstance = null;\
        }\
        // Alice patch end 0073\
' "$path3"

# --- SuggestionListViewBinder：容器可见时注册为淡化目标 ---

sed -i '/^        holder\.dropdown\.setVisibility(listVisibility);$/a\
        // Alice patch start 0073\
        if (containerVisibility == View.VISIBLE) {\
            holder.container.registerAliceSearchPageFadeInstance();\
        }\
        // Alice patch end 0073\
' "$path4"

# --- AutocompleteMediator：推荐列表延迟清空 ---

# 延迟常量与待执行任务。
sed -i '/^    private static final long OMNIBOX_SUGGESTION_START_DELAY_MS = 30;$/a\
    // Alice patch start 0073\
    private static final long ALICE_SUGGESTION_LIST_CLEAR_DELAY_MS = 225;\
    // Alice patch end 0073\
' "$path2"

sed -i '/^    private @Nullable AutocompleteResult mAutocompleteResult;$/a\
    // Alice patch start 0073\
    private @Nullable Runnable mAliceSuggestionListClearRunnable;\
    // Alice patch end 0073\
' "$path2"

# 取消与调度方法。
sed -i '/^    void endInput() {$/i\
    // Alice patch start 0073\
    private void cancelAliceSuggestionListClear() {\
        Runnable aliceClearRunnable = mAliceSuggestionListClearRunnable;\
        if (aliceClearRunnable == null) return;\
        mHandler.removeCallbacks(aliceClearRunnable);\
        mAliceSuggestionListClearRunnable = null;\
    }\
\
    private void scheduleAliceSuggestionListClear() {\
        cancelAliceSuggestionListClear();\
        Runnable aliceClearRunnable =\
                () -> {\
                    mAliceSuggestionListClearRunnable = null;\
                    propagateOmniboxSessionStateChange(false);\
                    mDropdownViewInfoListManager.clear();\
                    mAutocompleteResult = null;\
                };\
        mAliceSuggestionListClearRunnable = aliceClearRunnable;\
        mHandler.postDelayed(\
                aliceClearRunnable, ALICE_SUGGESTION_LIST_CLEAR_DELAY_MS);\
    }\
    // Alice patch end 0073\
\
' "$path2"

# 新会话开始时立即取消延迟清空。
sed -i '/^    void beginInput(FuseboxSessionState session) {$/a\
        // Alice patch start 0073\
        cancelAliceSuggestionListClear();\
        // Alice patch end 0073\
' "$path2"

# endInput：会话数据立刻复位；propagate(false) 和视觉清空推迟到淡化动画结束。
# 另外退出流程中有一个先于 endInput 到达的空结果回调（isInInputSession() 仍为
# true，上面延迟收尾拦不住它）：此时直接清空会让列表在淡出开始前瞬间消失，
# 因此在每处 setSourceViewInfoList 前拦截"空结果 + 列表非空"的组合，跳过清空
# 交给延迟任务。条件只用局部变量 viewInfoList 和字段，保证在任何调用点都合法；
# 正常输入时 native 至少返回默认匹配，不会命中该组合。
sed -i '/^        propagateOmniboxSessionStateChange(false);$/c\
        // Alice patch start 0073\
        scheduleAliceSuggestionListClear();\
        // Alice patch end 0073' "$path2"

sed -i '/^        mDropdownViewInfoListManager\.setSourceViewInfoList(viewInfoList);$/i\
        // Alice patch start 0073\
        if (viewInfoList.isEmpty() \&\& mSuggestionModels.size() > 0) {\
            return;\
        }\
        // Alice patch end 0073\
' "$path2"

sed -i '/^        clearSuggestions();$/c\
        // Alice patch start 0073\
        stopAutocomplete(AutocompleteStopReason.CLOBBERED);\
        dismissDeleteDialog(DialogDismissalCause.NAVIGATE_BACK_OR_TOUCH_OUTSIDE);\
        // Alice patch end 0073' "$path2"

# destroy() 里 removeCallbacksAndMessages 会清掉延迟任务，只需把引用复位。
sed -i '/^        mHandler\.removeCallbacksAndMessages(null);$/i\
        // Alice patch start 0073\
        mAliceSuggestionListClearRunnable = null;\
        // Alice patch end 0073\
' "$path2"
