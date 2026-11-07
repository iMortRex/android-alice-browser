#!/bin/bash
# Temporary diagnostics for Hub snackbar positioning and dismissal.

set -e

path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarView.java"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"

if grep -q 'Alice patch start 9998' "$path1"; then
    exit 100
fi

sed -i '/^        int targetBottomMargin = aliceBottomMargin;$/a\
        // Alice patch start 9998\
        {\
            int[] aliceRootLocation = new int[2];\
            int[] aliceParentLocation = new int[2];\
            int[] aliceChildLocation = new int[2];\
            mRootContentView.getLocationInWindow(aliceRootLocation);\
            mParent.getLocationInWindow(aliceParentLocation);\
            mContainerView.getLocationInWindow(aliceChildLocation);\
            android.graphics.Rect aliceVisibleRect = new android.graphics.Rect();\
            boolean aliceVisible =\
                    mContainerView.getGlobalVisibleRect(aliceVisibleRect);\
            android.util.Log.e(\
                    "cr_AliceSnackbar9998",\
                    "adjust tag=" + mParent.getTag()\
                            + " parent=" + mParent.getClass().getName()\
                            + " rootBottom="\
                            + (aliceRootLocation[1] + mRootContentView.getHeight())\
                            + " parentTop=" + aliceParentLocation[1]\
                            + " parentBottom="\
                            + (aliceParentLocation[1] + mParent.getHeight())\
                            + " childTop=" + aliceChildLocation[1]\
                            + " childBottom="\
                            + (aliceChildLocation[1] + mContainerView.getHeight())\
                            + " childHeight=" + mContainerView.getHeight()\
                            + " margin=" + targetBottomMargin\
                            + " translationY=" + mContainerView.getTranslationY()\
                            + " translationZ=" + mContainerView.getTranslationZ()\
                            + " parentClip=" + mParent.getClipChildren()\
                            + " parentClipPadding=" + mParent.getClipToPadding()\
                            + " visible=" + aliceVisible\
                            + " visibleRect=" + aliceVisibleRect);\
        }\
        // Alice patch end 9998\
' "$path1"

sed -i '/^    public void dismiss() {$/a\
        // Alice patch start 9998\
        {\
            int[] aliceRootLocation = new int[2];\
            int[] aliceParentLocation = new int[2];\
            int[] aliceChildLocation = new int[2];\
            mRootContentView.getLocationInWindow(aliceRootLocation);\
            mParent.getLocationInWindow(aliceParentLocation);\
            mContainerView.getLocationInWindow(aliceChildLocation);\
            android.graphics.Rect aliceVisibleRect = new android.graphics.Rect();\
            boolean aliceVisible =\
                    mContainerView.getGlobalVisibleRect(aliceVisibleRect);\
            android.util.Log.e(\
                    "cr_AliceSnackbar9998",\
                    "dismiss START tag=" + mParent.getTag()\
                            + " parent=" + mParent.getClass().getName()\
                            + " rootBottom="\
                            + (aliceRootLocation[1] + mRootContentView.getHeight())\
                            + " parentTop=" + aliceParentLocation[1]\
                            + " parentBottom="\
                            + (aliceParentLocation[1] + mParent.getHeight())\
                            + " childTop=" + aliceChildLocation[1]\
                            + " childBottom="\
                            + (aliceChildLocation[1] + mContainerView.getHeight())\
                            + " childHeight=" + mContainerView.getHeight()\
                            + " margin=" + getLayoutParams().bottomMargin\
                            + " target=" + getYPositionForMoveAnimation()\
                            + " translationY=" + mContainerView.getTranslationY()\
                            + " translationZ=" + mContainerView.getTranslationZ()\
                            + " parentClip=" + mParent.getClipChildren()\
                            + " parentClipPadding=" + mParent.getClipToPadding()\
                            + " visible=" + aliceVisible\
                            + " visibleRect=" + aliceVisibleRect);\
        }\
        // Alice patch end 9998\
' "$path1"

sed -i '0,/^        moveAnimator\.setDuration(mAnimationDuration);$/s//        moveAnimator.setDuration(mAnimationDuration);\n        \/\/ Alice patch start 9998\n        moveAnimator.addListener(\n                new android.animation.AnimatorListenerAdapter() {\n                    @Override\n                    public void onAnimationStart(android.animation.Animator animation) {\n                        android.util.Log.e(\n                                "cr_AliceSnackbar9998",\n                                "dismiss ANIM_START translationY="\n                                        + mContainerView.getTranslationY());\n                    }\n\n                    @Override\n                    public void onAnimationEnd(android.animation.Animator animation) {\n                        android.util.Log.e(\n                                "cr_AliceSnackbar9998",\n                                "dismiss ANIM_END translationY="\n                                        + mContainerView.getTranslationY()\n                                        + " childTop=" + mContainerView.getTop());\n                    }\n                });\n        \/\/ Alice patch end 9998/' "$path1"

sed -i '/^                    rootContent.addView(alicePinnedSnackbarContainer, params);$/a\
                    // Alice patch start 9998\
                    rootContent.post(\
                            () -> {\
                                int[] aliceRootLocation = new int[2];\
                                int[] aliceContainerLocation = new int[2];\
                                rootContent.getLocationInWindow(aliceRootLocation);\
                                alicePinnedSnackbarContainer.getLocationInWindow(\
                                        aliceContainerLocation);\
                                android.util.Log.e(\
                                        "cr_AliceSnackbar9998",\
                                        "hub overlay root=" + rootContent.getWidth()\
                                                + "x" + rootContent.getHeight()\
                                                + " rootTop=" + aliceRootLocation[1]\
                                                + " containerTop="\
                                                + aliceContainerLocation[1]\
                                                + " containerBottom="\
                                                + (aliceContainerLocation[1]\
                                                        + alicePinnedSnackbarContainer\
                                                                .getHeight())\
                                                + " containerHeight="\
                                                + alicePinnedSnackbarContainer.getHeight()\
                                                + " paddingBottom="\
                                                + alicePinnedSnackbarContainer\
                                                        .getPaddingBottom()\
                                                + " translationZ="\
                                                + alicePinnedSnackbarContainer\
                                                        .getTranslationZ()\
                                                + " rootClip=" + rootContent.getClipChildren()\
                                                + " rootClipPadding="\
                                                + rootContent.getClipToPadding());\
                            });\
                    // Alice patch end 9998\
' "$path2"
