#!/bin/bash
# 点击地址栏后，让搜索页背景从顶部实色渐隐到底部透明，并保持搜索框原背景。
# 开关在 设置 - 外观，默认关。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"
path2="chrome/android/java/res/xml/appearance_preferences.xml"
path3="chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarFocusScrimHandler.java"

# 检测是否已应用
if grep -q 'Alice patch start 0039' "$path1"; then
    exit 100
fi

# 1) 工具栏增加绘制搜索页背景渐变所需的状态。
sed -i '/^import android\.graphics\.Color;$/a\
// Alice patch start 0039\
import android.graphics.LinearGradient;\
// Alice patch end 0039\
' "$path1"

sed -i '/^import android\.graphics\.Outline;$/a\
// Alice patch start 0039\
import android.graphics.Paint;\
// Alice patch end 0039\
' "$path1"

sed -i '/^import android\.graphics\.Point;$/a\
// Alice patch start 0039\
import android.graphics.PorterDuff;\
import android.graphics.PorterDuffXfermode;\
// Alice patch end 0039\
' "$path1"

sed -i '/^import android\.graphics\.Rect;$/a\
// Alice patch start 0039\
import android.graphics.Shader;\
// Alice patch end 0039\
' "$path1"

sed -i '/^import org\.chromium\.chrome\.browser\.omnibox\.suggestions\.OmniboxSuggestionsDropdownScrollListener;$/a\
// Alice patch start 0039\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0039\
' "$path1"

sed -i '/^    private static final int URL_CLEAR_FOCUS_TABSTACK_DELAY_MS = 200;$/a\
    // Alice patch start 0039\
    private static final String ALICE_SEARCH_PAGE_GRADIENT_PREF =\
            "alice_search_page_gradient";\
    // Alice patch end 0039\
' "$path1"

sed -i '/^    protected ColorDrawable mToolbarBackground;$/a\
    // Alice patch start 0039\
    private final Paint mAliceSearchPageBackgroundPaint =\
            new Paint(Paint.ANTI_ALIAS_FLAG | Paint.DITHER_FLAG);\
    private final Paint mAliceSearchPageBackgroundMaskPaint =\
            new Paint(Paint.ANTI_ALIAS_FLAG | Paint.DITHER_FLAG);\
    private final PorterDuffXfermode mAliceSearchPageBackgroundMaskXfermode =\
            new PorterDuffXfermode(PorterDuff.Mode.DST_IN);\
    private @Nullable LinearGradient mAliceSearchPageBackgroundShader;\
    private @ColorInt int mAliceSearchPageBackgroundColor;\
    private int mAliceSearchPageBackgroundWidth = -1;\
    private int mAliceSearchPageBackgroundHeight = -1;\
    private boolean mAliceSearchPageGradientEnabled;\
    // Alice patch end 0039\
' "$path1"

# 2) 聚焦时停用原纯色实底，改为整块渐变；失焦时恢复。
sed -i '/^    private void updateBackground(final boolean hasFocus) {$/,/^    }$/c\
    // Alice patch start 0039\
    private void updateBackground(final boolean hasFocus) {\
        mAliceSearchPageGradientEnabled =\
                hasFocus\
                        \&\& ChromeSharedPreferences.getInstance()\
                                .readBoolean(\
                                        ALICE_SEARCH_PAGE_GRADIENT_PREF,\
                                        false);\
        if (ChromeFeatureList.sToolbarPhoneAnimationRefactor.isEnabled()) {\
            setBackground(\
                    mAliceSearchPageGradientEnabled ? null : mToolbarBackground);\
        }\
        if (!mAliceSearchPageGradientEnabled) {\
            mAliceSearchPageBackgroundShader = null;\
        }\
\
        if (hasFocus) {\
            mDropdownListScrolled = false;\
        } else if (isLocationBarShownInNtp()) {\
            updateToNtpBackground();\
        }\
    }\
    // Alice patch end 0039\
' "$path1"

# 3) 搜索页纯色背景改为顶部实色、底部完全透明，搜索框背景不动。
sed -i 's|^        if (!mTextureCaptureMode \&\& mToolbarBackground.getColor() != Color.TRANSPARENT) {$|        // Alice patch start 0039\n        if (!mTextureCaptureMode\n                \&\& mAliceSearchPageGradientEnabled\n                \&\& urlHasFocus()) {\n            drawAliceSearchPageBackgroundGradient(canvas);\n        } else if (!mTextureCaptureMode\n                \&\& mToolbarBackground.getColor() != Color.TRANSPARENT) {\n        // Alice patch end 0039|' "$path1"

sed -i '/^    private void updateToolbarBackground(@ColorInt int color) {$/i\
    // Alice patch start 0039\
    private void drawAliceSearchPageBackgroundGradient(Canvas canvas) {\
        int width = getWidth();\
        int height = getHeight();\
        if (width <= 0 || height <= 0) return;\
\
        @ColorInt int color = mToolbarBackground.getColor();\
        if (Color.alpha(color) == 0) {\
            color = getToolbarDefaultColor(/* shouldUseFocusColor= */ false);\
        }\
        color = ColorUtils.setAlphaComponent(color, 255);\
        if (mAliceSearchPageBackgroundShader == null\
                || mAliceSearchPageBackgroundColor != color\
                || mAliceSearchPageBackgroundWidth != width\
                || mAliceSearchPageBackgroundHeight != height) {\
            mAliceSearchPageBackgroundColor = color;\
            mAliceSearchPageBackgroundWidth = width;\
            mAliceSearchPageBackgroundHeight = height;\
            mAliceSearchPageBackgroundShader =\
                    new LinearGradient(\
                            0,\
                            0,\
                            0,\
                            height,\
                            color,\
                            color \& 0x00FFFFFF,\
                            Shader.TileMode.CLAMP);\
        }\
        int saveCount = canvas.saveLayer(0, 0, width, height, null);\
        mAliceSearchPageBackgroundPaint.setShader(null);\
        mAliceSearchPageBackgroundPaint.setColor(color);\
        mAliceSearchPageBackgroundPaint.setXfermode(null);\
        canvas.drawRect(0, 0, width, height, mAliceSearchPageBackgroundPaint);\
\
        mAliceSearchPageBackgroundMaskPaint.setShader(mAliceSearchPageBackgroundShader);\
        mAliceSearchPageBackgroundMaskPaint.setXfermode(\
                mAliceSearchPageBackgroundMaskXfermode);\
        canvas.drawRect(0, 0, width, height, mAliceSearchPageBackgroundMaskPaint);\
        canvas.restoreToCount(saveCount);\
    }\
    // Alice patch end 0039\
' "$path1"

# 4) 外观 Fragment 增加读取开关所需的偏好依赖。
sed -i '/^import org\.chromium\.chrome\.browser\.preferences\.ChromePreferenceKeys;$/a\
// Alice patch start 0039\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0039\
' "$path3"

# 5) 外观设置页加开关（默认英文，简体中文由 Fragment 覆盖）。
sed -i 's|^        android:summary="@string/bookmark_bar_setting_subtitle" />$|&\
\
    <!-- Alice patch start 0039 -->\
    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\
        android:key="alice_search_page_gradient_switch"\
        android:order="5"\
        android:title="Fade the search box background" />\
    <!-- Alice patch end 0039 -->|' "$path2"

# 6) Fragment：读/写开关（默认关，与行为默认值一致）。
sed -i '/^    public static final String PREF_UI_THEME = "ui_theme";$/a\
    // Alice patch start 0039\
    public static final String PREF_ALICE_SEARCH_PAGE_GRADIENT =\
            "alice_search_page_gradient_switch";\
    // Alice patch end 0039\
' "$path3"

sed -i '/^        initTabPositionPref();$/a\
        // Alice patch start 0039\
        initAliceSearchPageGradientPref();\
        // Alice patch end 0039\
' "$path3"

sed -i '/^    private void updateUiThemePref() {$/i\
    // Alice patch start 0039\
    /** Alice: 搜索框背景渐隐开关。 */\
    private void initAliceSearchPageGradientPref() {\
        ChromeSwitchPreference switchPref =\
                (ChromeSwitchPreference)\
                        findPreference(PREF_ALICE_SEARCH_PAGE_GRADIENT);\
        String aliceLanguage =\
                getResources().getConfiguration().getLocales().get(0).getLanguage();\
        if ("zh".equals(aliceLanguage)) {\
            switchPref.setTitle("搜索框背景渐隐");\
        }\
        switchPref.setChecked(\
                ChromeSharedPreferences.getInstance()\
                        .readBoolean(\
                                "alice_search_page_gradient",\
                                false));\
        switchPref.setOnPreferenceChangeListener(\
                (preference, newValue) -> {\
                    ChromeSharedPreferences.getInstance()\
                            .writeBoolean(\
                                    "alice_search_page_gradient",\
                                    (boolean) newValue);\
                    return true;\
                });\
    }\
    // Alice patch end 0039\
' "$path3"
