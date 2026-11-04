#!/bin/bash
# Temporary diagnostics for the bottom-toolbar flash while the IME closes.

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="components/browser_ui/bottomsheet/android/internal/java/src/org/chromium/components/browser_ui/bottomsheet/BottomSheet.java"

if grep -q 'Alice patch start 9999' "$path1" || grep -q 'Alice patch start 9999' "$path2"; then
    exit 100
fi

sed -i '/^import android\.graphics\.Bitmap;$/a\
// Alice patch start 9999\
import android.graphics.Rect;\
// Alice patch end 9999' "$path1"

sed -i '/^    private static final String TAG = "ToolbarPosition";$/a\
    // Alice patch start 9999\
    private void logAliceImeToolbarState(String event, int imeInset) {\
        View controlView = mControlContainer.getView();\
        BottomSheetContent content = mBottomSheetController.getCurrentSheetContent();\
        String contentName = content == null ? "null" : content.getClass().getSimpleName();\
        int[] controlLocation = new int[2];\
        controlView.getLocationOnScreen(controlLocation);\
        Rect controlScreenRect =\
                new Rect(\
                        controlLocation[0],\
                        controlLocation[1],\
                        controlLocation[0] + controlView.getWidth(),\
                        controlLocation[1] + controlView.getHeight());\
        Rect controlVisibleRect = new Rect();\
        boolean controlHasVisibleRect =\
                controlView.getGlobalVisibleRect(controlVisibleRect);\
        View rootView = controlView.getRootView();\
        Rect rootVisibleRect = new Rect();\
        boolean rootHasVisibleRect = rootView.getGlobalVisibleRect(rootVisibleRect);\
        Log.i(\
                TAG,\
                "[AliceIME] "\
                        + event\
                        + " position=" + mCurrentPosition.get()\
                        + " layerVisibility=" + mLayerVisibility\
                        + " imeAnimation=" + mIsImeAnimationRunning\
                        + " animationIme=" + mCurrentImeAnimationHeight\
                        + " inputIme=" + imeInset\
                        + " keyboardShowing=" + mKeyboardVisibilityDelegate.isKeyboardShowing(controlView)\
                        + " controlVisibility=" + controlView.getVisibility()\
                        + " controlShown=" + controlView.isShown()\
                        + " controlTranslationY=" + controlView.getTranslationY()\
                        + " controlHeight=" + controlView.getHeight()\
                        + " controlAlpha=" + controlView.getAlpha()\
                        + " controlScreenRect=" + controlScreenRect\
                        + " controlVisibleRect=" + controlVisibleRect\
                        + " controlHasVisibleRect=" + controlHasVisibleRect\
                        + " controlClip=" + controlView.getClipBounds()\
                        + " rootSize=" + rootView.getWidth() + "x" + rootView.getHeight()\
                        + " rootVisibleRect=" + rootVisibleRect\
                        + " rootHasVisibleRect=" + rootHasVisibleRect\
                        + " bottomOffset=" + mBrowserControlsSizer.getBottomControlOffset()\
                        + " bottomHeight=" + mBrowserControlsSizer.getBottomControlsHeight()\
                        + " bottomTotalHeight=" + mBottomControlsStacker.getTotalHeight()\
                        + " bottomMinHeight=" + mBottomControlsStacker.getTotalMinHeight()\
                        + " bottomLayerOffset=" + mBottomToolbarLayer.getLayerOffsetPx()\
                        + " sheetState=" + mBottomSheetController.getSheetState()\
                        + " sheetContent=" + contentName);\
    }\
    // Alice patch end 9999\
' "$path1"

sed -i '/^                        updateImeLayerOffsets();$/i\
                        // Alice patch start 9999\
                        logAliceImeToolbarState(\
                                "beforeUpdateImeLayerOffsets",\
                                mCurrentImeAnimationHeight);\
                        // Alice patch end 9999\
' "$path1"

sed -i '/^                        mCurrentAnimation = null;$/a\
                        // Alice patch start 9999\
                        logAliceImeToolbarState("imeAnimationEnd", animation.getTypeMask());\
                        // Alice patch end 9999\
' "$path1"

sed -i '/^        viewForLayer.setTranslationY(layerYOffset);$/a\
        // Alice patch start 9999\
        if (layer == mBottomToolbarLayer) {\
            Log.i(\
                    TAG,\
                    "[AliceIME] applyBottomToolbarOffset"\
                            + " requestedY=" + layerYOffset\
                            + " actualY=" + viewForLayer.getTranslationY()\
                            + " visibility=" + mLayerVisibility\
                            + " keyboardShowing="\
                            + mKeyboardVisibilityDelegate.isKeyboardShowing(\
                                    mControlContainer.getView())\
                            + " animationIme=" + mCurrentImeAnimationHeight);\
        }\
        // Alice patch end 9999\
' "$path1"

sed -i '/^    private boolean updateLayerVisibility(boolean animate) {$/a\
        // Alice patch start 9999\
        int aliceOldLayerVisibility = mLayerVisibility;\
        // Alice patch end 9999\
' "$path1"

sed -i '/^            mLayerVisibility = targetVisibility;$/a\
            // Alice patch start 9999\
            Log.i(\
                    TAG,\
                    "[AliceIME] layerVisibilityChange old=" + aliceOldLayerVisibility\
                            + " new=" + targetVisibility\
                            + " animate=" + animate\
                            + " position=" + mCurrentPosition.get());\
            // Alice patch end 9999\
' "$path1"

sed -i '/^    private void onInsetChanged() {$/i\
    // Alice patch start 9999\
    private void logAliceImeSheetState(String event, int imeInset) {\
        Rect backgroundClip =\
                mSheetBackground == null ? null : mSheetBackground.getClipBounds();\
        Rect contentClip =\
                mBottomSheetContentContainer == null\
                        ? null\
                        : mBottomSheetContentContainer.getClipBounds();\
        Rect sheetVisibleRect = new Rect();\
        boolean sheetHasVisibleRect = getGlobalVisibleRect(sheetVisibleRect);\
        Rect backgroundVisibleRect = new Rect();\
        boolean backgroundHasVisibleRect =\
                mSheetBackground.getGlobalVisibleRect(backgroundVisibleRect);\
        Rect contentVisibleRect = new Rect();\
        boolean contentHasVisibleRect =\
                mBottomSheetContentContainer.getGlobalVisibleRect(contentVisibleRect);\
        Rect toolbarVisibleRect = new Rect();\
        boolean toolbarHasVisibleRect =\
                mToolbarHolder.getGlobalVisibleRect(toolbarVisibleRect);\
        int[] sheetLocation = new int[2];\
        getLocationOnScreen(sheetLocation);\
        Log.i(\
                TAG,\
                "[AliceIME] "\
                        + event\
                        + " sheetState=" + mCurrentState\
                        + " targetState=" + mTargetState\
                        + " keyboardShowing=" + isKeyboardShowing()\
                        + " imeAnimation=" + mFullWindowImeAnimationRunning\
                        + " imeClosing=" + mImeAnimationClosing\
                        + " cropped=" + mFullWindowImeCropped\
                        + " restoring=" + mRestoringFullWindowImeCrop\
                        + " inputIme=" + imeInset\
                        + " animationIme=" + mFullWindowCurrentImeInset\
                        + " previewHeightBeforeIme=" + mFullWindowPreviewHeightBeforeIme\
                        + " currentOffset=" + mCurrentOffsetPx\
                        + " sheetTranslationY=" + getTranslationY()\
                        + " sheetHeight=" + getHeight()\
                        + " sheetClip=" + getClipBounds()\
                        + " sheetLocation=" + sheetLocation[0] + "," + sheetLocation[1]\
                        + " sheetVisibleRect=" + sheetVisibleRect\
                        + " sheetHasVisibleRect=" + sheetHasVisibleRect\
                        + " backgroundVisibility=" + mSheetBackground.getVisibility()\
                        + " backgroundClip=" + backgroundClip\
                        + " backgroundVisibleRect=" + backgroundVisibleRect\
                        + " backgroundHasVisibleRect=" + backgroundHasVisibleRect\
                        + " contentVisibility=" + mBottomSheetContentContainer.getVisibility()\
                        + " contentClip=" + contentClip\
                        + " contentVisibleRect=" + contentVisibleRect\
                        + " contentHasVisibleRect=" + contentHasVisibleRect\
                        + " toolbarVisibility=" + mToolbarHolder.getVisibility()\
                        + " toolbarTranslationY=" + mToolbarHolder.getTranslationY()\
                        + " toolbarHeight=" + mToolbarHolder.getHeight()\
                        + " toolbarVisibleRect=" + toolbarVisibleRect\
                        + " toolbarHasVisibleRect=" + toolbarHasVisibleRect);\
    }\
    // Alice patch end 9999\
' "$path2"

sed -i '/^    private void onInsetChanged() {$/a\
        // Alice patch start 9999\
        logAliceImeSheetState(\
                "onInsetChanged",\
                mFullWindowImeAnimationRunning\
                        ? mFullWindowCurrentImeInset\
                        : mInsetObserver.getSupplierForKeyboardInset().get());\
        // Alice patch end 9999\
' "$path2"

sed -i '/^        if (!mFullWindowImeCropped || mRestoringFullWindowImeCrop) return;$/a\
        // Alice patch start 9999\
        logAliceImeSheetState(\
                "restoreStart", mInsetObserver.getSupplierForKeyboardInset().get());\
        // Alice patch end 9999\
' "$path2"

sed -i '/^            mRestoringFullWindowImeCrop = false;$/a\
            // Alice patch start 9999\
            logAliceImeSheetState(\
                    "restoreEnd", mInsetObserver.getSupplierForKeyboardInset().get());\
            // Alice patch end 9999\
' "$path2"

sed -i '/^                    mSheetContent.onSheetHeightChanged(croppedHeight);$/a\
                    // Alice patch start 9999\
                    logAliceImeSheetState("afterSheetHeightChanged", imeInset);\
                    // Alice patch end 9999\
' "$path2"

sed -i '/^        setTranslationY(translationY);$/a\
        // Alice patch start 9999\
        logAliceImeSheetState(\
                "afterSetSheetTranslation", mFullWindowCurrentImeInset);\
        // Alice patch end 9999\
' "$path2"
