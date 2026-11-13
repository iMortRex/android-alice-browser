#!/bin/bash
# 搜索页淡出诊断：tag=cr_Alice9999。必须先应用 0073（锚定其插入代码）。
# 记录：焦点事件、淡化动画完整生命周期（启动/逐帧/取消/结束）、draw 层进出、
# 四个冻结点命中、updateToolbarBackground 全部调用（hairline/导航栏的颜色来源）、
# applyAliceDeferredUnfocusVisuals 前后颜色、建议容器 alpha/注册/可见性判定、
# endInput 延迟清空调度与触发。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListViewBinder.java"

# 依赖检查与重复应用检测
if ! grep -q 'Alice patch start 0073' "$path1"; then
    echo "9999 依赖 0073，请先应用 0073" >&2
    exit 1
fi
if grep -q 'Alice patch start 9999' "$path1"; then
    exit 100
fi

# --- ToolbarPhone ---

sed -i '/^import org\.chromium\.base\.MathUtils;$/a\
// Alice patch start 9999\
import org.chromium.base.Log;\
// Alice patch end 9999\
' "$path1"

# 诊断助手：带序号和时间戳的日志 + 当前颜色/淡化状态快照。
sed -i '/^    private void animateAliceSearchPageFade(boolean hasFocus) {$/i\
    // Alice patch start 9999\
    private int mAliceLogSeq;\
    private boolean mAliceLogLastLayerEngaged;\
\
    private void aliceLog9999(String msg) {\
        Log.i(\
                "Alice9999",\
                "["\
                        + (mAliceLogSeq++)\
                        + "] t="\
                        + SystemClock.uptimeMillis()\
                        + " "\
                        + msg);\
    }\
\
    private String aliceColors9999() {\
        GradientDrawable aliceDrawable = getActiveLocationBarGradientDrawable();\
        android.content.res.ColorStateList aliceList =\
                aliceDrawable == null ? null : aliceDrawable.getColor();\
        android.widget.ImageView aliceHairline = getToolbarHairline();\
        android.content.res.ColorStateList aliceHairlineTint =\
                aliceHairline == null ? null : aliceHairline.getImageTintList();\
        return "toolbarBg="\
                + Integer.toHexString(mToolbarBackground.getColor())\
                + " locBar="\
                + (aliceList == null\
                        ? "null"\
                        : Integer.toHexString(aliceList.getDefaultColor()))\
                + " hairlineColor="\
                + (aliceHairlineTint == null\
                        ? "null"\
                        : Integer.toHexString(aliceHairlineTint.getDefaultColor()))\
                + " hairlineVis="\
                + (aliceHairline == null\
                        ? "null"\
                        : aliceHairline.getVisibility()\
                                + "/"\
                                + aliceHairline.getAlpha())\
                + " boxAlpha="\
                + mLocationBar.getPhoneCoordinator().getAlpha()\
                + " boxBgViewAlpha="\
                + mActiveLocationBarBackgroundView.getAlpha()\
                + " self[vis="\
                + getVisibility()\
                + " a="\
                + getAlpha()\
                + " tx="\
                + getTranslationX()\
                + " ty="\
                + getTranslationY()\
                + "]"\
                + " phoneVis="\
                + mLocationBar.getPhoneCoordinator().getVisibility()\
                + " "\
                + aliceUrlBarState9999()\
                + " boxTY="\
                + mLocationBar.getPhoneCoordinator().getTranslationY()\
                + " boxView=["\
                + mLocationBar.getContainerView().getLeft()\
                + ","\
                + mLocationBar.getContainerView().getTop()\
                + " "\
                + mLocationBar.getContainerView().getWidth()\
                + "x"\
                + mLocationBar.getContainerView().getHeight()\
                + "]"\
                + " bgView=["\
                + mActiveLocationBarBackgroundView.getLeft()\
                + ","\
                + mActiveLocationBarBackgroundView.getTop()\
                + " "\
                + mActiveLocationBarBackgroundView.getWidth()\
                + "x"\
                + mActiveLocationBarBackgroundView.getHeight()\
                + "]"\
                + " bgBounds="\
                + mLocationBarBackgroundBounds.toShortString()\
                + " ntpOffset="\
                + mLocationBarBackgroundNtpOffset.toShortString()\
                + " sbBounds="\
                + mNtpSearchBoxBounds.toShortString()\
                + " sbTrans="\
                + mNtpSearchBoxTranslation.toString()\
                + " shownInNtp="\
                + isLocationBarShownInNtp()\
                + " scrollFrac="\
                + mNtpSearchBoxScrollFraction\
                + " toolbarH="\
                + getHeight()\
                + " focus="\
                + urlHasFocus()\
                + " animating="\
                + mUrlFocusChangeInProgress\
                + " fade[active="\
                + mAliceSearchPageFadeActive\
                + " alpha="\
                + mAliceSearchPageFadeAlpha\
                + " shown="\
                + mAliceSearchPageShown\
                + " deferring="\
                + mAliceSearchPageFadeOutDeferring\
                + "]";\
    }\
\
    private String aliceUrlBarState9999() {\
        android.widget.TextView aliceUrlBar =\
                (android.widget.TextView)\
                        mLocationBar\
                                .getContainerView()\
                                .findViewById(\
                                        org.chromium.chrome.browser.omnibox\
                                                .R.id.url_bar);\
        if (aliceUrlBar == null) return "urlBar=null";\
        return "urlBar[vis="\
                + aliceUrlBar.getVisibility()\
                + " a="\
                + aliceUrlBar.getAlpha()\
                + " text="\
                + aliceUrlBar.getText()\
                + "]";\
    }\
    // Alice patch end 9999\
\
' "$path1"

# 焦点变化入口。
sed -i '/^        boolean aliceWasShown = mAliceSearchPageShown;$/a\
            // Alice patch start 9999\
            aliceLog9999(\
                    "focusChange hasFocus="\
                            + hasFocus\
                            + " "\
                            + aliceColors9999());\
            // Alice patch end 9999\
' "$path1"

# 分支决策。
sed -i '/^            mAliceSearchPageShown = true;$/a\
            // Alice patch start 9999\
            aliceLog9999("branch=focusIn");\
            // Alice patch end 9999\
' "$path1"

sed -i '/^            mAliceSearchPageFadeOutDeferring = true;$/a\
            // Alice patch start 9999\
            aliceLog9999("branch=fadeOut");\
            // Alice patch end 9999\
' "$path1"

# 取消前一个动画。
sed -i '/^            mAliceSearchPageFadeAnimator\.cancel();$/a\
            // Alice patch start 9999\
            aliceLog9999("cancelling previous animator");\
            // Alice patch end 9999\
' "$path1"

# onEnd 是否触发（区分正常结束与被替换）。
sed -i 's|^                        if (mAliceSearchPageFadeAnimator != animation) return;$|                        // Alice patch start 9999\n                        aliceLog9999("animator onEnd reached target=" + target);\n                        if (mAliceSearchPageFadeAnimator != animation) {\n                            aliceLog9999("animator onEnd STALE (replaced earlier)");\n                            return;\n                        }\n                        // Alice patch end 9999|' "$path1"

# 逐帧 alpha（同时观察搜索框 alpha 是否被旁路改写）。
sed -i '/^        mAliceSearchPageFadeAlpha = MathUtils\.clamp(alpha, 0f, 1f);$/a\
        // Alice patch start 9999\
        aliceLog9999(\
                "alpha="\
                        + mAliceSearchPageFadeAlpha\
                        + " boxAlpha="\
                        + mLocationBar.getPhoneCoordinator().getAlpha()\
                        + " active="\
                        + mAliceSearchPageFadeActive\
                        + " shown="\
                        + mAliceSearchPageShown\
                        + " deferring="\
                        + mAliceSearchPageFadeOutDeferring);\
        // Alice patch end 9999\
' "$path1"

# draw 层进出（只在状态翻转时打一条）。
sed -i '/^        aliceDrawWithFadeInner(canvas);$/i\
        // Alice patch start 9999\
        boolean aliceLayerEngaged = aliceFadeLayer >= 0;\
        if (aliceLayerEngaged != mAliceLogLastLayerEngaged) {\
            mAliceLogLastLayerEngaged = aliceLayerEngaged;\
            aliceLog9999(\
                    "drawLayer "\
                            + (aliceLayerEngaged\
                                    ? "ENGAGED alpha="\
                                            + mAliceSearchPageFadeAlpha\
                                    : "released")\
                            + " "\
                            + aliceColors9999());\
        }\
        // Alice patch end 9999\
' "$path1"

# applyAliceDeferredUnfocusVisuals 进入。
sed -i '/^    private void applyAliceDeferredUnfocusVisuals() {$/a\
        // Alice patch start 9999\
        aliceLog9999("applyDeferred ENTER " + aliceColors9999());\
        // Alice patch end 9999\
' "$path1"

# applyAliceDeferredUnfocusVisuals 的颜色应用（updateBackground(false) 前）。
sed -i '/^        updateBackground(false);$/i\
        // Alice patch start 9999\
        aliceLog9999("applyDeferred applying colors");\
        // Alice patch end 9999\
' "$path1"

# 冻结点 1/2 命中日志。
sed -i 's|^        if (mAliceSearchPageFadeOutDeferring) return;$|        // Alice patch start 9999\n        if (mAliceSearchPageFadeOutDeferring) {\n            aliceLog9999("gate1 BLOCKED updateToolbarAndLocationBarColorForFocusChange");\n            return;\n        }\n        // Alice patch end 9999|' "$path1"
sed -i 's|^            if (mAliceSearchPageFadeOutDeferring) return;$|            // Alice patch start 9999\n            if (mAliceSearchPageFadeOutDeferring) {\n                aliceLog9999("gate2 BLOCKED updateNtpTransitionAnimation");\n                return;\n            }\n            // Alice patch end 9999|' "$path1"

# onFocusTransitionStart / onFocusTransitionEnd 入口（观察冻结点 4 的执行与跳过）。
sed -i '/^    private void onFocusTransitionStart() {$/a\
        // Alice patch start 9999\
        aliceLog9999("onFocusTransitionStart " + aliceColors9999());\
        // Alice patch end 9999\
' "$path1"
sed -i '/^    private void onFocusTransitionEnd() {$/a\
        // Alice patch start 9999\
        aliceLog9999("onFocusTransitionEnd " + aliceColors9999());\
        // Alice patch end 9999\
' "$path1"

# updateBackground 入口（冻结点 3）。
sed -i '/^    private void updateBackground(final boolean hasFocus) {$/a\
        // Alice patch start 9999\
        aliceLog9999("updateBackground hasFocus=" + hasFocus + " deferring=" + mAliceSearchPageFadeOutDeferring);\
        // Alice patch end 9999\
' "$path1"

# updateToolbarBackground 全量记录（hairline/导航栏颜色的唯一来源）。
sed -i 's|^        if (mToolbarBackground\.getColor() == color) return;$|        // Alice patch start 9999\n        if (mToolbarBackground.getColor() == color) {\n            aliceLog9999(\n                    "updateToolbarBackground SKIP already="\n                            + Integer.toHexString(color)\n                            + " deferring="\n                            + mAliceSearchPageFadeOutDeferring);\n            return;\n        }\n        aliceLog9999(\n                "updateToolbarBackground "\n                        + Integer.toHexString(mToolbarBackground.getColor())\n                        + " -> "\n                        + Integer.toHexString(color)\n                        + " deferring="\n                        + mAliceSearchPageFadeOutDeferring);\n        // Alice patch end 9999|' "$path1"

# updateLocationBarTranslationOnScroll 入口。
sed -i '/^    private void updateLocationBarTranslationOnScroll() {$/a\
        // Alice patch start 9999\
        aliceLog9999("updateLocBarTranslationOnScroll " + aliceColors9999());\
        // Alice patch end 9999\
' "$path1"

# cancelAnimations 入口。
sed -i '/^    private void cancelAnimations() {$/a\
        // Alice patch start 9999\
        aliceLog9999("cancelAnimations " + aliceColors9999());\
        // Alice patch end 9999\
' "$path1"

# --- AutocompleteMediator ---

sed -i '/^import org\.chromium\.base\.supplier\.NonNullObservableSupplier;$/i\
// Alice patch start 9999\
import org.chromium.base.Log;\
// Alice patch end 9999\
' "$path2"

# endInput 入口与出口。
sed -i '/^    void endInput() {$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "endInput ENTER inSession="\
                        + isInInputSession()\
                        + " count="\
                        + mSuggestionModels.size()\
                        + " t="\
                        + SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path2"

sed -i '/^        setFuseboxAttachmentModelList(null);$/a\
        // Alice patch start 9999\
        Log.i("Alice9999", "endInput EXIT t=" + SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path2"

# 延迟清空：调度 / 取消 / 触发。
sed -i '/^                aliceClearRunnable, ALICE_SUGGESTION_LIST_CLEAR_DELAY_MS);$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "delayedClear SCHEDULED t="\
                        + SystemClock.uptimeMillis()\
                        + " + "\
                        + ALICE_SUGGESTION_LIST_CLEAR_DELAY_MS);\
        // Alice patch end 9999\
' "$path2"

sed -i '/^        mHandler\.removeCallbacks(aliceClearRunnable);$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "delayedClear CANCELLED t=" + SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path2"

sed -i '/^                    mAliceSuggestionListClearRunnable = null;$/a\
                    // Alice patch start 9999\
                    Log.i(\
                            "Alice9999",\
                            "delayedClear FIRING t="\
                                    + SystemClock.uptimeMillis());\
                    // Alice patch end 9999\
' "$path2"

# onSuggestionsReceived 入口（观察延迟窗口内是否有回调到达）。
sed -i '/^    public void onSuggestionsReceived(AutocompleteResult autocompleteResult, boolean isFinal) {$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "suggestionsReceived isFinal="\
                        + isFinal\
                        + " count="\
                        + autocompleteResult.getSuggestionsList().size()\
                        + " inSession="\
                        + isInInputSession()\
                        + " t="\
                        + SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path2"

# 会话状态传播。
sed -i '/^        boolean wasActive = mListPropertyModel\.get(SuggestionListProperties\.OMNIBOX_SESSION_ACTIVE);$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "propagateSession isActive="\
                        + isActive\
                        + " wasActive="\
                        + wasActive\
                        + " count="\
                        + mSuggestionModels.size()\
                        + " t="\
                        + SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path2"

# --- OmniboxSuggestionsContainer ---

sed -i '/^import org\.chromium\.base\.TraceEvent;$/i\
// Alice patch start 9999\
import org.chromium.base.Log;\
// Alice patch end 9999\
' "$path3"

# 容器注册。
sed -i '/^        setAlpha(sAliceSearchPageFadeAlpha);$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "containerRegistered inst="\
                        + Integer.toHexString(System.identityHashCode(this))\
                        + " vis="\
                        + getVisibility()\
                        + " alpha="\
                        + sAliceSearchPageFadeAlpha\
                        + " t="\
                        + android.os.SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path3"

# 统一 alpha 每次下发。
sed -i '/^        sAliceSearchPageFadeAlpha = Math\.max(0f, Math\.min(1f, alpha));$/a\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "containerAlpha a="\
                        + sAliceSearchPageFadeAlpha\
                        + " inst="\
                        + (sAliceSearchPageFadeInstance == null\
                                ? "null"\
                                : Integer.toHexString(\
                                        System.identityHashCode(\
                                                sAliceSearchPageFadeInstance)))\
                        + " vis="\
                        + (sAliceSearchPageFadeInstance == null\
                                ? "null"\
                                : Integer.toString(\
                                        sAliceSearchPageFadeInstance\
                                                .getVisibility()))\
                        + " t="\
                        + android.os.SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path3"

# 容器销毁注销。
sed -i '/^            sAliceSearchPageFadeInstance = null;$/a\
            // Alice patch start 9999\
            Log.i("Alice9999", "containerUnregistered t=" + android.os.SystemClock.uptimeMillis());\
            // Alice patch end 9999\
' "$path3"

# --- SuggestionListViewBinder ---

sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/i\
// Alice patch start 9999\
import org.chromium.base.Log;\
// Alice patch end 9999\
' "$path4"

# 可见性判定的输入与输出。
sed -i '/^        holder\.dropdown\.setVisibility(listVisibility);$/i\
        // Alice patch start 9999\
        Log.i(\
                "Alice9999",\
                "binderVisibility session="\
                        + model.get(SuggestionListProperties.OMNIBOX_SESSION_ACTIVE)\
                        + " windowFocused="\
                        + model.get(SuggestionListProperties.ACTIVITY_WINDOW_FOCUSED)\
                        + " count="\
                        + listItems.size()\
                        + " alwaysVisible="\
                        + model.get(SuggestionListProperties.CONTAINER_ALWAYS_VISIBLE)\
                        + " -> container="\
                        + containerVisibility\
                        + " list="\
                        + listVisibility\
                        + " t="\
                        + android.os.SystemClock.uptimeMillis());\
        // Alice patch end 9999\
' "$path4"
