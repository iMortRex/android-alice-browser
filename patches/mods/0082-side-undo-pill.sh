#!/bin/bash
# 标签页关闭撤销气泡：默认左下角，可切换为右下角；沿所在侧滑入和滑出。
# 与 0002/0029/0034 兼容：保留现有显示时长、层级和导航栏/底栏避让。

set -e

path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"
path2="chrome/android/java/res/xml/appearance_preferences.xml"
path3="chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java"

# 检测是否已应用
if grep -q 'Alice patch start 0082' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

sed -i '/^import android\.app\.Activity;$/a\
// Alice patch start 0082\
import android.graphics.Outline;\
// Alice patch end 0082\
' "$path1"

sed -i '/^import android\.util\.Pair;$/a\
// Alice patch start 0082\
import android.util.TypedValue;\
// Alice patch end 0082\
' "$path1"

sed -i '/^import android\.view\.LayoutInflater;$/a\
// Alice patch start 0082\
import android.view.MotionEvent;\
// Alice patch end 0082\
' "$path1"

sed -i '/^import android\.view\.ViewGroup;$/a\
// Alice patch start 0082\
import android.view.ViewOutlineProvider;\
// Alice patch end 0082\
' "$path1"

sed -i '/^import org\.chromium\.build\.annotations\.Nullable;$/a\
// Alice patch start 0082\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0082\
' "$path1"

sed -i '/^    private static final int DEFAULT_LINES = 2;$/a\
    // Alice patch start 0082\
    private static final String ALICE_UNDO_PILL_ON_RIGHT_PREF = "alice_undo_pill_on_right";\
    // Alice patch end 0082\
' "$path1"

sed -i '/^    private final int mSnackbarMargin;$/a\
    // Alice patch start 0082\
    private @Nullable Drawable mAliceOriginalActionButtonBackground;\
    private @Nullable Drawable mAliceUndoActionButtonBackground;\
    // Alice patch end 0082\
' "$path1"

sed -i '/^        mActionButtonView\.setOnClickListener(manager);$/a\
        // Alice patch start 0082\
        mAliceOriginalActionButtonBackground = mActionButtonView.getBackground();\
        TypedValue aliceUndoRippleValue = new TypedValue();\
        if (mActionButtonView\
                        .getContext()\
                        .getTheme()\
                        .resolveAttribute(\
                                android.R.attr.selectableItemBackground,\
                                aliceUndoRippleValue,\
                                true)\
                \&\& aliceUndoRippleValue.resourceId != 0) {\
            mAliceUndoActionButtonBackground =\
                    mActionButtonView\
                            .getContext()\
                            .getDrawable(aliceUndoRippleValue.resourceId);\
        }\
        mActionButtonView.setOutlineProvider(\
                new ViewOutlineProvider() {\
                    @Override\
                    public void getOutline(View view, Outline outline) {\
                        outline.setRoundRect(\
                                0,\
                                0,\
                                view.getWidth(),\
                                view.getHeight(),\
                                view.getHeight() / 2f);\
                    }\
                });\
        mActionButtonView.setClipToOutline(true);\
        mActionButtonView.setOnTouchListener(\
                (view, event) -> {\
                    if (isAliceActionOnlyUndoSnackbar()\
                            \&\& swipeGestureListener.onTouchEvent(event)) {\
                        return true;\
                    }\
                    return false;\
                });\
        // Alice patch end 0082\
' "$path1"

# 只对通过 UndoBarController 创建的撤销气泡启用单按钮形态。
# 标签组合并仍保留原有消息和按钮，避免扩大改动范围。
sed -i '/^    void adjustViewPosition() {$/i\
    // Alice patch start 0082\
    private boolean isAliceActionOnlyUndoSnackbar() {\
        int identifier = mSnackbar.getIdentifier();\
        return identifier == Snackbar.UMA_TAB_CLOSE_UNDO\
                || identifier == Snackbar.UMA_TAB_CLOSE_ALL_UNDO\
                || identifier == Snackbar.UMA_TAB_CLOSE_MULTIPLE_UNDO\
                || identifier == Snackbar.UMA_TAB_GROUP_DELETE_UNDO\
                || identifier == Snackbar.UMA_SINGLE_TAB_GROUP_DELETE_UNDO;\
    }\
\
    private boolean isAliceUndoPillOnRight() {\
        return ChromeSharedPreferences.getInstance()\
                .readBoolean(ALICE_UNDO_PILL_ON_RIGHT_PREF, false);\
    }\
\
    private void updateAliceActionButtonBackground() {\
        Drawable aliceTargetBackground =\
                isAliceActionOnlyUndoSnackbar()\
                        ? mAliceUndoActionButtonBackground\
                        : mAliceOriginalActionButtonBackground;\
        if (aliceTargetBackground != null\
                \&\& mActionButtonView.getBackground() != aliceTargetBackground) {\
            mActionButtonView.setBackground(aliceTargetBackground);\
            mActionButtonView.invalidateOutline();\
        }\
    }\
    // Alice patch end 0082\
' "$path1"

# 中文使用简短完整文案，其他语言沿用 Snackbar 已有的本地化操作文案。
sed -i '/^            mActionButtonView\.setContentDescription(snackbar\.getActionText());$/,/^            setViewText(mActionButtonView, snackbar\.getActionText(), animate);$/c\
            // Alice patch start 0082\
            if (isAliceActionOnlyUndoSnackbar()) {\
                String aliceLanguage =\
                        mContainerView\
                                .getResources()\
                                .getConfiguration()\
                                .getLocales()\
                                .get(0)\
                                .getLanguage();\
                @Nullable CharSequence aliceActionText =\
                        "zh".equals(aliceLanguage)\
                                ? "撤销关闭"\
                                : snackbar.getActionText();\
                mActionButtonView.setContentDescription(aliceActionText);\
                setViewText(mActionButtonView, aliceActionText, animate);\
            } else {\
                mActionButtonView.setContentDescription(snackbar.getActionText());\
                setViewText(mActionButtonView, snackbar.getActionText(), animate);\
            }\
            // Alice patch end 0082' "$path1"

# 单按钮撤销气泡按内容测量宽度，其他 Snackbar 保持原有最大宽度规则。
sed -i 's|^        int targetWidth = Math\.min(mMaxWidth, mParent\.getWidth() - 2 \* mSnackbarMargin);$|        // Alice patch start 0082\
        boolean aliceCompactUndo = isAliceActionOnlyUndoSnackbar();\
        int targetWidth =\
                aliceCompactUndo\
                        ? ViewGroup.LayoutParams.WRAP_CONTENT\
                        : Math.min(mMaxWidth, mParent.getWidth() - 2 * mSnackbarMargin);\
        // Alice patch end 0082|' "$path1"

# 圆角取气泡高度的一半，并让按钮点击态跟随胶囊高度更新圆角裁切。
sed -i '/^        boolean isFullscreen = mIsFullscreenSupplier\.get();$/i\
        // Alice patch start 0082\
        if (aliceCompactUndo \&\& mSnackbarView.getHeight() > 0) {\
            Drawable aliceBackgroundDrawable = mSnackbarView.getBackground();\
            if (aliceBackgroundDrawable instanceof GradientDrawable) {\
                ((GradientDrawable) aliceBackgroundDrawable.mutate())\
                        .setCornerRadius(mSnackbarView.getHeight() / 2f);\
            }\
            mActionButtonView.invalidateOutline();\
        }\
        // Alice patch end 0082' "$path1"

# 撤销气泡按开关贴左或贴右；端部间距保持 floating snackbar 的 margin。
sed -i '/^        int targetGravity = Gravity\.CENTER_HORIZONTAL | Gravity\.BOTTOM;$/,/^        }$/c\
        // Alice patch start 0082\
        boolean aliceUndoOnRight = aliceCompactUndo \&\& isAliceUndoPillOnRight();\
        int targetGravity =\
                aliceCompactUndo\
                        ? (aliceUndoOnRight\
                                ? Gravity.RIGHT | Gravity.BOTTOM\
                                : Gravity.LEFT | Gravity.BOTTOM)\
                        : Gravity.CENTER_HORIZONTAL | Gravity.BOTTOM;\
        int targetMargin =\
                aliceCompactUndo\
                        ? mSnackbarMargin\
                        : mContainerView\
                                .getResources()\
                                .getDimensionPixelSize(R.dimen.snackbar_margin);\
\
        if (lp.width != targetWidth\
                || lp.bottomMargin != targetBottomMargin\
                || lp.gravity != targetGravity\
                || lp.getMarginStart() != targetMargin\
                || lp.getMarginEnd() != targetMargin) {\
            lp.width = targetWidth;\
            lp.gravity = targetGravity;\
            lp.bottomMargin = targetBottomMargin;\
            lp.setMarginStart(targetMargin);\
            lp.setMarginEnd(targetMargin);\
            mContainerView.setLayoutParams(lp);\
        }\
        // Alice patch end 0082' "$path1"

# 单按钮撤销气泡隐藏消息和图片，只显示操作按钮。
sed -i '/^        Drawable profileImage = snackbar\.getProfileImage();$/i\
        // Alice patch start 0082\
        updateAliceActionButtonBackground();\
        mMessageView.setVisibility(\
                isAliceActionOnlyUndoSnackbar() ? View.GONE : View.VISIBLE);\
        // Alice patch end 0082\
' "$path1"

# 只允许撤销气泡沿当前所在侧滑动，普通 Snackbar 保持双向滑动。
sed -i '/^        SwipeGestureListener swipeGestureListener =$/,/^                new SwipeGestureListener(activity, mSnackbarSwipeHandler);$/c\
        // Alice patch start 0082\
        SwipeGestureListener swipeGestureListener =\
                new SwipeGestureListener(activity, mSnackbarSwipeHandler) {\
                    @Override\
                    public boolean shouldRecognizeSwipe(MotionEvent e1, MotionEvent e2) {\
                        if (!isAliceActionOnlyUndoSnackbar()) return true;\
                        float aliceSwipeDistance = e2.getRawX() - e1.getRawX();\
                        return isAliceUndoPillOnRight()\
                                ? aliceSwipeDistance > 0f\
                                : aliceSwipeDistance < 0f;\
                    }\
                };\
        // Alice patch end 0082' "$path1"

# 显示时从气泡所在侧滑入，其他 Snackbar 继续从底部滑入。
sed -i '/^                        mContainerView\.setTranslationY(getYPositionForMoveAnimation());$/,/^                                ObjectAnimator\.ofFloat(mContainerView, View\.TRANSLATION_Y, 0);$/c\
                        // Alice patch start 0082\
                        Animator animator;\
                        if (isAliceActionOnlyUndoSnackbar()) {\
                            float aliceUndoOffset =\
                                    mContainerView.getWidth() + mSnackbarMargin;\
                            mContainerView.setTranslationX(\
                                    isAliceUndoPillOnRight()\
                                            ? aliceUndoOffset\
                                            : -aliceUndoOffset);\
                            mContainerView.setTranslationY(0);\
                            animator =\
                                    ObjectAnimator.ofFloat(\
                                            mContainerView, View.TRANSLATION_X, 0);\
                        } else {\
                            mContainerView.setTranslationY(\
                                    getYPositionForMoveAnimation());\
                            animator =\
                                    ObjectAnimator.ofFloat(\
                                            mContainerView, View.TRANSLATION_Y, 0);\
                        }\
                        // Alice patch end 0082' "$path1"

# 消失时向气泡所在侧滑出，不执行普通 Snackbar 的垂直下落或透明度淡出。
sed -i '/^        if (translateData\.first != 0) {$/,/^        }$/c\
        // Alice patch start 0082\
        if (isAliceActionOnlyUndoSnackbar()) {\
            float aliceUndoOffset =\
                    mContainerView.getWidth() + mSnackbarMargin;\
            moveAnimator.play(\
                    ObjectAnimator.ofFloat(\
                            mContainerView,\
                            View.TRANSLATION_X,\
                            isAliceUndoPillOnRight()\
                                    ? aliceUndoOffset\
                                    : -aliceUndoOffset));\
        } else if (translateData.first != 0) {\
            Animator translate =\
                    ObjectAnimator.ofFloat(\
                            mContainerView,\
                            View.TRANSLATION_X,\
                            (translateData.first > 0 ? 1 : -1) * getMaximumTranslateX());\
            moveAnimator = new AnimatorSet();\
            moveAnimator.playTogether(\
                    translate, ObjectAnimator.ofFloat(mContainerView, View.ALPHA, 0));\
        } else {\
            moveAnimator.play(\
                    ObjectAnimator.ofFloat(\
                            mContainerView, View.TRANSLATION_Y, getYPositionForMoveAnimation()));\
        }\
        // Alice patch end 0082' "$path1"

# 外观设置页增加撤销气泡左右位置开关，默认关闭即显示在左侧。
sed -i 's|^        android:summary="@string/bookmark_bar_setting_subtitle" />$|&\
\
    <!-- Alice patch start 0082 -->\
    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\
        android:key="alice_undo_pill_on_right_switch"\
        android:order="5"\
        android:title="Show undo bubble on the right"\
        android:summary="Off: left side. On: right side. Swipe toward that side to dismiss." />\
    <!-- Alice patch end 0082 -->|' "$path2"

sed -i '/^    public static final String PREF_UI_THEME = "ui_theme";$/a\
    // Alice patch start 0082\
    public static final String PREF_ALICE_UNDO_PILL_ON_RIGHT =\
            "alice_undo_pill_on_right_switch";\
    // Alice patch end 0082\
' "$path3"

sed -i '/^        initTabPositionPref();$/a\
        // Alice patch start 0082\
        initAliceUndoPillSidePref();\
        // Alice patch end 0082\
' "$path3"

sed -i '/^    private void updateUiThemePref() {$/i\
    // Alice patch start 0082\
    /** Alice: 撤销气泡左右位置开关。 */\
    private void initAliceUndoPillSidePref() {\
        ChromeSwitchPreference switchPref =\
                (ChromeSwitchPreference)\
                        findPreference(PREF_ALICE_UNDO_PILL_ON_RIGHT);\
        String aliceLanguage =\
                getResources().getConfiguration().getLocales().get(0).getLanguage();\
        if ("zh".equals(aliceLanguage)) {\
            switchPref.setTitle("撤销气泡显示在右侧");\
            switchPref.setSummary(\
                    "关闭时显示在左侧；开启后显示在右侧，沿气泡所在侧滑动即可清除。");\
        }\
        switchPref.setChecked(\
                org.chromium.chrome.browser.preferences.ChromeSharedPreferences.getInstance()\
                        .readBoolean(\
                                "alice_undo_pill_on_right",\
                                false));\
        switchPref.setOnPreferenceChangeListener(\
                (preference, newValue) -> {\
                    org.chromium.chrome.browser.preferences.ChromeSharedPreferences.getInstance()\
                            .writeBoolean(\
                                    "alice_undo_pill_on_right",\
                                    (boolean) newValue);\
                    return true;\
                });\
    }\
    // Alice patch end 0082\
' "$path3"
