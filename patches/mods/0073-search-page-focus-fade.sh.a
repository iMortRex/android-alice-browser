#!/bin/bash
# 搜索页进入、退出和状态栏过渡。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListViewBinder.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/UrlBarCoordinator.java"
path5="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/UrlBar.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/ui/system/StatusBarColorController.java"
path7="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0073' "$path1"; then
    exit 100
fi

# --- ToolbarPhone：搜索页进入渐显 ---

sed -i 's|URL_FOCUS_CHANGE_ANIMATION_DURATION_MS = 225;|URL_FOCUS_CHANGE_ANIMATION_DURATION_MS = 100;|' "$path1"

sed -i '/^    private boolean mDropdownListScrolled;$/a\
    // Alice patch start 0073\
    private static final long ALICE_SEARCH_PAGE_ENTER_FADE_MS = 100L;\
    private @Nullable ValueAnimator mAliceSearchPageEnterAnimator;\
    private float mAliceSearchPageEnterAlpha = 1f;\
    private boolean mAliceSearchPageEnterActive;\
    private boolean mAliceSearchPageShown;\
    // Alice patch end 0073\
' "$path1"

sed -i '/^        super\.onUrlFocusChange(hasFocus);$/a\
        // Alice patch start 0073\
        animateAliceSearchPageEnter(hasFocus);\
        // Alice patch end 0073\
' "$path1"

sed -i '/^    private void updateToolbarBackground(@ColorInt int color) {$/i\
    // Alice patch start 0073\
    private void animateAliceSearchPageEnter(boolean hasFocus) {\
        boolean aliceWasActive = mAliceSearchPageEnterActive;\
        boolean aliceWasShown = mAliceSearchPageShown;\
        if (mAliceSearchPageEnterAnimator != null) {\
            mAliceSearchPageEnterAnimator.cancel();\
            mAliceSearchPageEnterAnimator = null;\
        }\
        if (!hasFocus) {\
            mAliceSearchPageEnterActive = false;\
            mAliceSearchPageShown = false;\
            setAliceSearchPageEnterAlpha(1f);\
            return;\
        }\
        mAliceSearchPageShown = true;\
        float aliceStart =\
                aliceWasActive\
                        ? mAliceSearchPageEnterAlpha\
                        : (aliceWasShown ? 1f : 0f);\
        startAliceSearchPageEnterFade(aliceStart, 1f);\
    }\
\
    private void startAliceSearchPageEnterFade(float start, float target) {\
        mAliceSearchPageEnterActive = true;\
        if (start >= 1f \&\& target >= 1f) {\
            finishAliceSearchPageEnterFade();\
            return;\
        }\
        ValueAnimator animator = ValueAnimator.ofFloat(start, target);\
        animator.setDuration(ALICE_SEARCH_PAGE_ENTER_FADE_MS);\
        animator.setInterpolator(Interpolators.FAST_OUT_SLOW_IN_INTERPOLATOR);\
        animator.addUpdateListener(\
                animation ->\
                        setAliceSearchPageEnterAlpha(\
                                (float) animation.getAnimatedValue()));\
        animator.addListener(\
                new CancelAwareAnimatorListener() {\
                    @Override\
                    public void onEnd(Animator animation) {\
                        if (mAliceSearchPageEnterAnimator != animation) return;\
                        finishAliceSearchPageEnterFade();\
                    }\
                });\
        mAliceSearchPageEnterAnimator = animator;\
        animator.start();\
    }\
\
    private void setAliceSearchPageEnterAlpha(float alpha) {\
        mAliceSearchPageEnterAlpha = MathUtils.clamp(alpha, 0f, 1f);\
        setAlpha(mAliceSearchPageEnterAlpha);\
        OmniboxSuggestionsContainer.setAliceSearchPageEnterAlpha(\
                mAliceSearchPageEnterAlpha);\
        invalidate();\
    }\
\
    private void finishAliceSearchPageEnterFade() {\
        mAliceSearchPageEnterAnimator = null;\
        mAliceSearchPageEnterActive = false;\
        setAliceSearchPageEnterAlpha(1f);\
    }\
    // Alice patch end 0073\
\
' "$path1"

sed -i '/^    private void cancelAnimations() {$/a\
        // Alice patch start 0073\
        if (mAliceSearchPageEnterAnimator != null) {\
            mAliceSearchPageEnterAnimator.cancel();\
            mAliceSearchPageEnterAnimator = null;\
        }\
        mAliceSearchPageEnterActive = false;\
        mAliceSearchPageShown = false;\
        setAliceSearchPageEnterAlpha(1f);\
        // Alice patch end 0073\
' "$path1"

sed -i '/^import org\.chromium\.chrome\.browser\.omnibox\.suggestions\.OmniboxSuggestionsDropdownScrollListener;$/a\
// Alice patch start 0073\
import org.chromium.chrome.browser.omnibox.suggestions.OmniboxSuggestionsContainer;\
// Alice patch end 0073\
' "$path1"

# --- 推荐列表：跟随搜索页进入渐显 ---

sed -i '/^    \/\*\* Clean up resources and remove observers installed by this class\. \*\/$/i\
    // Alice patch start 0073\
    private static float sAliceSearchPageEnterAlpha = 1f;\
    private static @Nullable OmniboxSuggestionsContainer sAliceSearchPageEnterInstance;\
\
    public static void setAliceSearchPageEnterAlpha(float alpha) {\
        sAliceSearchPageEnterAlpha = Math.max(0f, Math.min(1f, alpha));\
        OmniboxSuggestionsContainer aliceInstance = sAliceSearchPageEnterInstance;\
        if (aliceInstance != null) aliceInstance.setAlpha(sAliceSearchPageEnterAlpha);\
    }\
\
    public void registerAliceSearchPageEnterInstance() {\
        sAliceSearchPageEnterInstance = this;\
        setAlpha(sAliceSearchPageEnterAlpha);\
    }\
    // Alice patch end 0073\
\
' "$path2"

sed -i '/^        mDropdown\.destroy();$/i\
        // Alice patch start 0073\
        if (sAliceSearchPageEnterInstance == this) {\
            sAliceSearchPageEnterInstance = null;\
        }\
        // Alice patch end 0073\
' "$path2"

sed -i '/^        holder\.dropdown\.setVisibility(listVisibility);$/a\
        // Alice patch start 0073\
        if (containerVisibility == View.VISIBLE) {\
            holder.container.registerAliceSearchPageEnterInstance();\
        }\
        // Alice patch end 0073\
' "$path3"

# --- UrlBar：失焦前冻结流程并捕获整屏快照 ---

sed -i '/^    private @Nullable Callback<UrlBarFocusChangeInfo> mFocusChangeCallback;$/a\
    // Alice patch start 0073\
    private android.widget.@Nullable ImageView mAliceSnapshotView;\
    private android.graphics.@Nullable Bitmap mAliceSnapshotBitmap;\
    private android.animation.@Nullable ObjectAnimator mAliceSnapshotAnimator;\
    private int mAliceSnapshotGeneration;\
    // Alice patch end 0073\
' "$path5"

sed -i '/^    public void destroy() {$/i\
    // Alice patch start 0073\
    public void captureAliceExitSnapshot(Runnable continuation) {\
        releaseAliceExitSnapshot();\
        if (!(getContext() instanceof android.app.Activity)) {\
            continuation.run();\
            return;\
        }\
        android.app.Activity aliceActivity = (android.app.Activity) getContext();\
        View aliceDecorView = aliceActivity.getWindow().getDecorView();\
        if (!(aliceDecorView instanceof android.view.ViewGroup)\
                || aliceDecorView.getWidth() <= 0\
                || aliceDecorView.getHeight() <= 0) {\
            continuation.run();\
            return;\
        }\
        int aliceGeneration = mAliceSnapshotGeneration;\
        waitAliceExitSnapshotWindow(\
                aliceActivity,\
                aliceDecorView,\
                aliceGeneration,\
                -1,\
                0,\
                0,\
                () -> captureAliceSnapshotBitmap(\
                        aliceActivity,\
                        aliceDecorView,\
                        aliceGeneration,\
                        continuation));\
    }\
\
    private void waitAliceExitSnapshotWindow(\
            android.app.Activity aliceActivity,\
            View aliceDecorView,\
            int aliceGeneration,\
            int aliceLastHeight,\
            int aliceStableFrames,\
            int aliceAttempt,\
            Runnable continuation) {\
        if (aliceGeneration != mAliceSnapshotGeneration\
                || aliceActivity.isFinishing()\
                || aliceActivity.isDestroyed()) {\
            return;\
        }\
        if (aliceAttempt >= 120) {\
            continuation.run();\
            return;\
        }\
        android.view.WindowInsets aliceInsets = aliceDecorView.getRootWindowInsets();\
        boolean aliceImeVisible = false;\
        if (aliceInsets != null) {\
            androidx.core.view.WindowInsetsCompat aliceCompatInsets =\
                    androidx.core.view.WindowInsetsCompat.toWindowInsetsCompat(\
                            aliceInsets, aliceDecorView);\
            aliceImeVisible =\
                    aliceCompatInsets.isVisible(\
                            androidx.core.view.WindowInsetsCompat.Type.ime());\
        }\
        int aliceHeight = aliceDecorView.getHeight();\
        boolean aliceHeightStable =\
                aliceHeight > 0 \&\& aliceHeight == aliceLastHeight;\
        if (!aliceImeVisible \&\& (aliceHeightStable || aliceStableFrames >= 2)) {\
            continuation.run();\
            return;\
        }\
        aliceDecorView.postOnAnimation(\
                () ->\
                        waitAliceExitSnapshotWindow(\
                                aliceActivity,\
                                aliceDecorView,\
                                aliceGeneration,\
                                aliceHeight,\
                                aliceHeightStable ? aliceStableFrames + 1 : 0,\
                                aliceAttempt + 1,\
                                continuation));\
    }\
\
    private void captureAliceSnapshotBitmap(\
            android.app.Activity aliceActivity,\
            View aliceDecorView,\
            int aliceGeneration,\
            Runnable continuation) {\
        if (aliceGeneration != mAliceSnapshotGeneration) return;\
        int aliceWidth = aliceDecorView.getWidth();\
        int aliceHeight = aliceDecorView.getHeight();\
        if (aliceWidth <= 0 || aliceHeight <= 0) {\
            continuation.run();\
            return;\
        }\
        android.graphics.Bitmap aliceBitmap =\
                android.graphics.Bitmap.createBitmap(\
                        aliceWidth,\
                        aliceHeight,\
                        android.graphics.Bitmap.Config.ARGB_8888);\
        android.view.PixelCopy.request(\
                aliceActivity.getWindow(),\
                aliceBitmap,\
                result -> {\
                    if (aliceGeneration != mAliceSnapshotGeneration) {\
                        aliceBitmap.recycle();\
                        return;\
                    }\
                    if (result == android.view.PixelCopy.SUCCESS) {\
                        showAliceExitSnapshot(\
                                aliceBitmap, aliceGeneration, continuation);\
                    } else {\
                        aliceBitmap.recycle();\
                        continuation.run();\
                    }\
                },\
                new android.os.Handler(android.os.Looper.getMainLooper()));\
    }\
\
    private void showAliceExitSnapshot(\
            android.graphics.Bitmap aliceBitmap,\
            int aliceGeneration,\
            Runnable continuation) {\
        android.app.Activity aliceActivity = (android.app.Activity) getContext();\
        View aliceDecorView = aliceActivity.getWindow().getDecorView();\
        android.widget.ImageView aliceImageView =\
                new android.widget.ImageView(getContext());\
        aliceImageView.setImageBitmap(aliceBitmap);\
        aliceImageView.setScaleType(android.widget.ImageView.ScaleType.MATRIX);\
        float aliceScale =\
                aliceDecorView.getWidth() / (float) aliceBitmap.getWidth();\
        android.graphics.Matrix aliceMatrix = new android.graphics.Matrix();\
        aliceMatrix.setScale(aliceScale, aliceScale);\
        aliceMatrix.postTranslate(\
                0f,\
                aliceDecorView.getHeight()\
                        - aliceBitmap.getHeight() * aliceScale);\
        aliceImageView.setImageMatrix(aliceMatrix);\
        aliceImageView.setBackgroundColor(aliceBitmap.getPixel(0, 0));\
        aliceImageView.setAlpha(1f);\
        aliceImageView.setClickable(false);\
        aliceImageView.setFocusable(false);\
        aliceImageView.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);\
        ((android.view.ViewGroup) aliceDecorView)\
                .addView(\
                        aliceImageView,\
                        new android.widget.FrameLayout.LayoutParams(\
                                android.view.ViewGroup.LayoutParams.MATCH_PARENT,\
                                android.view.ViewGroup.LayoutParams.MATCH_PARENT));\
        aliceImageView.bringToFront();\
        aliceImageView.setTranslationZ(10000f);\
        mAliceSnapshotView = aliceImageView;\
        mAliceSnapshotBitmap = aliceBitmap;\
        boolean[] aliceDrawConsumed = new boolean[1];\
        aliceImageView\
                .getViewTreeObserver()\
                .addOnDrawListener(\
                        new android.view.ViewTreeObserver.OnDrawListener() {\
                            @Override\
                            public void onDraw() {\
                                if (aliceDrawConsumed[0]) return;\
                                aliceDrawConsumed[0] = true;\
                                aliceImageView.postOnAnimation(\
                                        () -> {\
                                            android.view.ViewTreeObserver observer =\
                                                    aliceImageView.getViewTreeObserver();\
                                            if (observer.isAlive()) {\
                                                observer.removeOnDrawListener(this);\
                                            }\
                                            if (aliceGeneration\
                                                            != mAliceSnapshotGeneration\
                                                    || mAliceSnapshotView != aliceImageView) {\
                                                return;\
                                            }\
                                            android.animation.ObjectAnimator animator =\
                                                    android.animation.ObjectAnimator.ofFloat(\
                                                            aliceImageView,\
                                                            View.ALPHA,\
                                                            1f,\
                                                            0f);\
                                            animator.setDuration(100L);\
                                            animator.setInterpolator(\
                                                    org.chromium.ui.interpolators.Interpolators\
                                                            .FAST_OUT_SLOW_IN_INTERPOLATOR);\
                                            animator.addListener(\
                                                    new android.animation.AnimatorListenerAdapter() {\
                                                        @Override\
                                                        public void onAnimationEnd(\
                                                                android.animation.Animator\
                                                                        animation) {\
                                                            if (mAliceSnapshotAnimator\
                                                                    != animation) {\
                                                                return;\
                                                            }\
                                                            finishAliceExitSnapshot();\
                                                        }\
                                                    });\
                                            mAliceSnapshotAnimator = animator;\
                                            animator.start();\
                                            continuation.run();\
                                        });\
                            }\
                        });\
    }\
\
    private void finishAliceExitSnapshot() {\
        mAliceSnapshotAnimator = null;\
        android.widget.@Nullable ImageView aliceImageView = mAliceSnapshotView;\
        mAliceSnapshotView = null;\
        if (aliceImageView != null) {\
            aliceImageView.setImageDrawable(null);\
            android.view.@Nullable ViewParent aliceParent = aliceImageView.getParent();\
            if (aliceParent instanceof android.view.ViewGroup) {\
                ((android.view.ViewGroup) aliceParent).removeView(aliceImageView);\
            }\
        }\
        android.graphics.@Nullable Bitmap aliceBitmap = mAliceSnapshotBitmap;\
        mAliceSnapshotBitmap = null;\
        if (aliceBitmap != null \&\& !aliceBitmap.isRecycled()) aliceBitmap.recycle();\
    }\
\
    private void releaseAliceExitSnapshot() {\
        mAliceSnapshotGeneration++;\
        android.animation.@Nullable ObjectAnimator animator = mAliceSnapshotAnimator;\
        mAliceSnapshotAnimator = null;\
        if (animator != null) animator.cancel();\
        finishAliceExitSnapshot();\
    }\
\
    // Alice patch end 0073\
\
' "$path5"

sed -i '/^        boolean wasFocused = mFocused;$/i\
        // Alice patch start 0073\
        if (focused) releaseAliceExitSnapshot();\
        // Alice patch end 0073\
' "$path5"

# --- UrlBarCoordinator：退出前抓取并显示快照 ---

sed -i '/^    \/\* package \*\/ void clearFocus() {$/i\
    // Alice patch start 0073\
    /* package */ void captureAliceExitSnapshotAndWait(Runnable onComplete) {\
        if (!mUrlBar.isFocused()) {\
            onComplete.run();\
            return;\
        }\
        mKeyboardVisibilityDelegate.hideKeyboard(mUrlBar);\
        mUrlBar.captureAliceExitSnapshot(onComplete);\
    }\
    // Alice patch end 0073\
' "$path4"

# --- LocationBarMediator：在清理输入会话前显示退出快照 ---

sed -i '/^    private boolean mDeferredFocusCurrentTab;$/a\
    // Alice patch start 0073\
    private boolean mAliceEndingInput;\
    // Alice patch end 0073\
' "$path7"

sed -i '/^    private void endInputAndFocusCurrentTab() {$/,/^    }$/c\
    private void endInputAndFocusCurrentTab() {\
        try (TraceEvent traceEvent =\
                TraceEvent.scoped("LocationBarMediator.endInputAndFocusCurrentTab")) {\
            assert mLocationBarDataProvider != null;\
            if (!mLocationBarDataProvider.hasTab()) return;\
\
            mDeferredFocusCurrentTab =\
                    mCurrentInput != null \&\& mScrimHandler != null \&\& mScrimHandler.isScrimShown();\
            if (mCurrentInput != null) {\
                // Alice patch start 0073\
                endInput(\
                        () -> {\
                            if (!mDeferredFocusCurrentTab) focusCurrentTab();\
                        });\
                // Alice patch end 0073\
            } else if (!mDeferredFocusCurrentTab) {\
                focusCurrentTab();\
            }\
        }\
    }\
' "$path7"

sed -i '/^    public void endInput() {$/,/^    }$/c\
    public void endInput() {\
        endInput(null);\
    }\
\
    private void endInput(@Nullable Runnable onComplete) {\
        if (!mAliceEndingInput\
                \&\& mUrlCoordinator != null\
                \&\& mUrlCoordinator.hasFocus()) {\
            // Alice patch start 0073\
            mAliceEndingInput = true;\
            mUrlCoordinator.captureAliceExitSnapshotAndWait(\
                    () -> {\
                        mAliceEndingInput = false;\
                        endInputAfterAliceSnapshot();\
                        if (onComplete != null) onComplete.run();\
                    });\
            // Alice patch end 0073\
            return;\
        }\
        endInputAfterAliceSnapshot();\
        if (onComplete != null) onComplete.run();\
    }\
\
    private void endInputAfterAliceSnapshot() {\
        mUrlFocusedWithoutAnimations = false;\
        if (mAutocompleteCoordinator == null || mCurrentInput == null || mIsReparenting) return;\
\
        FuseboxSessionState state = FuseboxSessionState.from(mLocationBarDataProvider);\
        if (state == null) return;\
\
        suspendInput();\
        state.deactivate();\
        updateUrl();\
        mSelectionController.reset();\
        clearUrlBarFocus();\
    }\
' "$path7"

sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0073\
        releaseAliceExitSnapshot();\
        // Alice patch end 0073\
' "$path5"

# --- StatusBarColorController：搜索页状态栏颜色过渡 ---

sed -i '/^    private boolean mIsOmniboxFocused;$/a\
    // Alice patch start 0073\
    private static final long ALICE_SEARCH_STATUS_BAR_FADE_MS = 100L;\
    private final AliceStatusBarColorTransitionController mAliceSearchStatusBarController;\
    private final AliceStatusBarColorTransitionController.Observer\
            mAliceSearchStatusBarObserver = ignored -> updateStatusBarColor();\
    private int mAliceSearchStatusBarToken;\
    // Alice patch end 0073\
' "$path6"

sed -i '/^        mActivity = activity;$/a\
        // Alice patch start 0073\
        mAliceSearchStatusBarController =\
                AliceStatusBarColorTransitionController.forActivity(activity);\
        mAliceSearchStatusBarController.addObserver(mAliceSearchStatusBarObserver);\
        // Alice patch end 0073\
' "$path6"

sed -i '/^    public void onUrlFocusChange(boolean hasFocus) {$/,/^    }$/c\
    public void onUrlFocusChange(boolean hasFocus) {\
        // Alice patch start 0073\
        if (hasFocus) {\
            @ColorInt int startColor =\
                    isStandardNtp()\
                            ? ColorUtils.getOpaqueColor(mBackgroundColorForNtp)\
                            : mCurrentTab == null\
                                    ? ColorUtils.getOpaqueColor(\
                                            calculateDefaultStatusBarColor())\
                                    : ColorUtils.getOpaqueColor(\
                                            mTopUiThemeColor.getToolbarBackgroundColor(\
                                                    mCurrentTab));\
            mIsOmniboxFocused = true;\
            @ColorInt int targetColor =\
                    ColorUtils.getOpaqueColor(calculateDefaultStatusBarColor());\
            setStatusBarColor(\
                    mEdgeToEdgeSystemBarColorHelper,\
                    mActivity,\
                    startColor,\
                    /* forceLightIconColor= */ false);\
            int aliceToken =\
                    mAliceSearchStatusBarController.animateTo(\
                            startColor, targetColor, ALICE_SEARCH_STATUS_BAR_FADE_MS);\
            mAliceSearchStatusBarToken = aliceToken;\
            mActivity\
                    .getWindow()\
                    .getDecorView()\
                    .postDelayed(\
                            () -> {\
                                if (mAliceSearchStatusBarToken != aliceToken\
                                        || !mIsOmniboxFocused) {\
                                    return;\
                                }\
                                mAliceSearchStatusBarController.clearOverride(aliceToken);\
                                mAliceSearchStatusBarToken = 0;\
                                updateStatusBarColor();\
                            },\
                            ALICE_SEARCH_STATUS_BAR_FADE_MS + 16L);\
        } else {\
            mIsOmniboxFocused = false;\
            @ColorInt int startColor =\
                    mAliceSearchStatusBarController.hasColor()\
                            ? mAliceSearchStatusBarController.getCurrentColor()\
                            : ColorUtils.getOpaqueColor(\
                                    mStatusBarColorWithoutStatusIndicator);\
            @ColorInt int targetColor =\
                    isStandardNtp()\
                            ? ColorUtils.getOpaqueColor(mBackgroundColorForNtp)\
                            : mCurrentTab == null\
                                    ? ColorUtils.getOpaqueColor(\
                                            calculateDefaultStatusBarColor())\
                                    : ColorUtils.getOpaqueColor(\
                                            mTopUiThemeColor.getToolbarBackgroundColor(\
                                                    mCurrentTab));\
            int aliceToken =\
                    mAliceSearchStatusBarController.animateTo(\
                            startColor, targetColor, ALICE_SEARCH_STATUS_BAR_FADE_MS);\
            mAliceSearchStatusBarToken = aliceToken;\
            mActivity\
                    .getWindow()\
                    .getDecorView()\
                    .postDelayed(\
                            () -> {\
                                if (mAliceSearchStatusBarToken != aliceToken\
                                        || mIsOmniboxFocused) {\
                                    return;\
                                }\
                                mAliceSearchStatusBarController.clearOverride(aliceToken);\
                                mAliceSearchStatusBarToken = 0;\
                                updateStatusBarColor();\
                            },\
                            ALICE_SEARCH_STATUS_BAR_FADE_MS + 16L);\
        }\
        // Alice patch end 0073\
        updateStatusBarColor();\
    }\
' "$path6"

sed -i '/^        @ColorInt int statusBarColor = calculateFinalStatusBarColor();$/a\
        // Alice patch start 0073\
        if (mAliceSearchStatusBarController.isOverriding()) {\
            statusBarColor = mAliceSearchStatusBarController.getCurrentColor();\
        }\
        // Alice patch end 0073\
' "$path6"

sed -i '/^    public void onDestroy() {$/a\
        // Alice patch start 0073\
        mAliceSearchStatusBarController.clearOverride(mAliceSearchStatusBarToken);\
        mAliceSearchStatusBarToken = 0;\
        mAliceSearchStatusBarController.removeObserver(mAliceSearchStatusBarObserver);\
        // Alice patch end 0073\
' "$path6"
