#!/bin/bash
# Temporary diagnostics for search-page background and hairline state.

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"

if grep -q 'Alice patch start 9999' "$path1"; then
    exit 100
fi

# Common toolbar geometry and background state.
sed -i '/^    public static final long THEME_COLOR_TRANSITION_DURATION = 250;$/a\
    // Alice patch start 9999\
    private void aliceLog9999(String event) {\
        int[] aliceLocation = new int[2];\
        getLocationInWindow(aliceLocation);\
        android.util.Log.i(\
                "Alice9999",\
                event\
                        + " window=" + aliceLocation[0] + "," + aliceLocation[1]\
                        + " size=" + getWidth() + "x" + getHeight()\
                        + " alpha=" + getAlpha()\
                        + " focus=" + urlHasFocus()\
                        + " gradient=" + mAliceSearchPageGradientEnabled);\
    }\
    // Alice patch end 9999\
' "$path1"

sed -i '/^    protected void dispatchDraw(Canvas canvas) {$/a\
        // Alice patch start 9999\
        if (mAliceSearchPageGradientEnabled || urlHasFocus()) {\
            aliceLog9999("dispatchDraw");\
        }\
        // Alice patch end 9999\
' "$path1"

sed -i '/^        @ColorInt int color = mToolbarBackground.getColor();$/a\
        // Alice patch start 9999\
        android.util.Log.i(\
                "Alice9999",\
                "gradient width=" + width\
                        + " height=" + height\
                        + " color=#" + Integer.toHexString(color)\
                        + " focus=" + urlHasFocus());\
        // Alice patch end 9999\
' "$path1"

# Hairline visibility and token state at focus changes.
sed -i '/^    private void updateHairlineVisibility() {$/i\
    // Alice patch start 9999\
    private String aliceHairlineState9999() {\
        if (mToolbarHairline == null) return "hairline=null";\
        return "hairline vis=" + mToolbarHairline.getVisibility()\
                + " alpha=" + mToolbarHairline.getAlpha()\
                + " size=" + mToolbarHairline.getWidth() + "x" + mToolbarHairline.getHeight()\
                + " token=" + mHairlineVisibilityTokenHolder.hasTokens();\
    }\
    // Alice patch end 9999\
' "$path3"

sed -i '/^    public void onUrlFocusChange(boolean hasFocus) {$/a\
        // Alice patch start 9999\
        android.util.Log.i(\
                "Alice9999", "focusChange=" + hasFocus + " " + aliceHairlineState9999());\
        // Alice patch end 9999\
' "$path3"

sed -i '/^    private void updateHairlineVisibility() {$/a\
        // Alice patch start 9999\
        android.util.Log.i(\
                "Alice9999", "updateHairline " + aliceHairlineState9999());\
        // Alice patch end 9999\
' "$path3"

sed -i '/^            if (mToolbar != null) mToolbar.onToolbarHairlineSuppressedChanged(suppressed);$/a\
        // Alice patch start 9999\
        android.util.Log.i(\
                "Alice9999", "updateHairlineDone " + aliceHairlineState9999());\
        // Alice patch end 9999\
' "$path3"

# Scrim state transitions.
sed -i '/^    public void setVisibility(boolean shouldShow, boolean animate) {$/a\
        // Alice patch start 9999\
        android.util.Log.i(\
                "Alice9999",\
                "scrim show=" + shouldShow + " animate=" + animate + " shown=" + mScrimShown);\
        // Alice patch end 9999\
' "$path2"

sed -i '/^        int aliceDelta = mAliceScrimToolbarLocation\[1\] - aliceScrimBottom;$/a\
        // Alice patch start 9999\
        android.util.Log.i(\
                "Alice9999",\
                "scrimAlign toolbarY=" + mAliceScrimToolbarLocation[1]\
                        + " scrimY=" + mAliceScrimViewLocation[1]\
                        + " scrimH=" + aliceScrim.getHeight()\
                        + " scrimBottom=" + aliceScrimBottom\
                        + " delta=" + aliceDelta\
                        + " translationY=" + aliceScrim.getTranslationY()\
                        + " scrimColor=" + mScrimModel.get(ScrimProperties.BACKGROUND_COLOR));\
        // Alice patch end 9999\
' "$path2"
