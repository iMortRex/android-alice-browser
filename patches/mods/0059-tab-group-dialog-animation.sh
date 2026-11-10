#!/bin/bash
# 标签组弹窗收回动画：下一帧重新读取网格卡片位置。

set -e

path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridDialogView.java"

# 检测是否已应用
if grep -q 'Alice patch start 0059' "$path1"; then
    exit 100
fi

# 使用当前窗口位置修正弹窗父容器坐标。
sed -i 's|^        assumeNonNull(mParent)\.getGlobalVisibleRect(dialogParentRect);$|        // Alice patch start 0059\n        int[] aliceDialogLocation = new int[2];\n        getLocationInWindow(aliceDialogLocation);\n        dialogParentRect.offsetTo(aliceDialogLocation[0], aliceDialogLocation[1]);\n        // Alice patch end 0059|' "$path1"

# 使用当前卡片位置修正动画起点。
sed -i 's|^        rect\.offset(-dialogParentRect\.left, -dialogParentRect\.top);$|        // Alice patch start 0059\n        int[] aliceItemLocation = new int[2];\n        mItemView.getLocationInWindow(aliceItemLocation);\n        rect.offsetTo(\n                aliceItemLocation[0] - dialogParentRect.left,\n                aliceItemLocation[1] - dialogParentRect.top);\n        // Alice patch end 0059|' "$path1"

# 使用当前卡片父容器位置修正裁剪区域。
sed -i 's|^        int clipTop = itemViewParentRect\.top - dialogParentRect\.top;$|        // Alice patch start 0059\n        int[] aliceItemParentLocation = new int[2];\n        ((View) mItemView.getParent()).getLocationInWindow(aliceItemParentLocation);\n        int clipTop = aliceItemParentLocation[1] - dialogParentRect.top;\n        // Alice patch end 0059|' "$path1"

# 下一帧重新读取卡片位置后再启动收回动画。
sed -i '/^        mHideDialogAnimation.start();$/c\
        // Alice patch start 0059\
        View aliceAnimationSource = mItemView;\
        if (aliceAnimationSource != null \&\& aliceAnimationSource.isAttachedToWindow()) {\
            aliceAnimationSource.postOnAnimation(\
                    () -> {\
                        if (getVisibility() != View.VISIBLE\
                                || mCurrentDialogAnimator != mHideDialogAnimation) {\
                            return;\
                        }\
                        setupDialogAnimation(aliceAnimationSource);\
                        mCurrentDialogAnimator = mHideDialogAnimation;\
                        mHideDialogAnimation.start();\
                    });\
        } else {\
            mHideDialogAnimation.start();\
        }\
        // Alice patch end 0059' "$path1"
