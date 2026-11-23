#!/bin/bash
# 标签页关闭撤销气泡：右下角窄按钮，从右侧滑入并向右侧滑出。
# 与 0002/0029/0034 兼容：保留现有显示时长、层级和导航栏/底栏避让。

set -e

path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"

# 检测是否已应用
if grep -q 'Alice patch start 0082' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

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

# 圆角取气泡高度的一半，使单按钮撤销气泡恢复完整胶囊形。
sed -i '/^        boolean isFullscreen = mIsFullscreenSupplier\.get();$/i\
        // Alice patch start 0082\
        if (isAliceActionOnlyUndoSnackbar() \&\& mSnackbarView.getHeight() > 0) {\
            Drawable aliceBackgroundDrawable = mSnackbarView.getBackground();\
            if (aliceBackgroundDrawable instanceof GradientDrawable) {\
                ((GradientDrawable) aliceBackgroundDrawable.mutate())\
                        .setCornerRadius(mSnackbarView.getHeight() / 2f);\
            }\
        }\
        // Alice patch end 0082' "$path1"

# 撤销气泡右下对齐；端部间距恢复 floating snackbar 的 16dp/24dp 规则。
sed -i '/^        int targetGravity = Gravity\.CENTER_HORIZONTAL | Gravity\.BOTTOM;$/,/^        }$/c\
        // Alice patch start 0082\
        int targetGravity =\
                aliceCompactUndo\
                        ? Gravity.END | Gravity.BOTTOM\
                        : Gravity.CENTER_HORIZONTAL | Gravity.BOTTOM;\
        int targetEndMargin =\
                aliceCompactUndo\
                        ? mSnackbarMargin\
                        : mContainerView\
                                .getResources()\
                                .getDimensionPixelSize(R.dimen.snackbar_margin);\
\
        if (lp.width != targetWidth\
                || lp.bottomMargin != targetBottomMargin\
                || lp.gravity != targetGravity\
                || lp.getMarginEnd() != targetEndMargin) {\
            lp.width = targetWidth;\
            lp.gravity = targetGravity;\
            lp.bottomMargin = targetBottomMargin;\
            lp.setMarginEnd(targetEndMargin);\
            mContainerView.setLayoutParams(lp);\
        }\
        // Alice patch end 0082' "$path1"

# 单按钮撤销气泡隐藏消息和图片，只显示操作按钮。
sed -i '/^        Drawable profileImage = snackbar\.getProfileImage();$/i\
        // Alice patch start 0082\
        mMessageView.setVisibility(\
                isAliceActionOnlyUndoSnackbar() ? View.GONE : View.VISIBLE);\
        // Alice patch end 0082\
' "$path1"

# 显示时从右侧屏幕外滑入，其他 Snackbar 继续从底部滑入。
sed -i '/^                        mContainerView\.setTranslationY(getYPositionForMoveAnimation());$/,/^                                ObjectAnimator\.ofFloat(mContainerView, View\.TRANSLATION_Y, 0);$/c\
                        // Alice patch start 0082\
                        Animator animator;\
                        if (isAliceActionOnlyUndoSnackbar()) {\
                            mContainerView.setTranslationX(\
                                    mContainerView.getWidth() + mSnackbarMargin);\
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

# 消失时从当前位置向右滑出，不执行普通 Snackbar 的垂直下落或透明度淡出。
sed -i '/^        if (translateData\.first != 0) {$/,/^        }$/c\
        // Alice patch start 0082\
        if (isAliceActionOnlyUndoSnackbar()) {\
            moveAnimator.play(\
                    ObjectAnimator.ofFloat(\
                            mContainerView,\
                            View.TRANSLATION_X,\
                            mContainerView.getWidth() + mSnackbarMargin));\
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
