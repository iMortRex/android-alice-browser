#!/bin/bash
# 地址栏建议的「修改搜索查询」(refine) 按钮：填入搜索框的文本末尾是否补空格
# 开关在 设置 - 外观，默认开（= 上游行为）

set -e

# 目标文件路径
path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"
path2="chrome/android/java/res/xml/appearance_preferences.xml"
path3="chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# 1) 行为：末尾是否补空格由 设置-外观 的开关决定（默认补）
sed -i 's|^import org.chromium.chrome.browser.omnibox.R;$|// Alice patch start\nimport org.chromium.chrome.browser.omnibox.R;\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\n// Alice patch end|' "$path1"

sed -i 's|^        if (isSearchSuggestion) refineText = TextUtils.concat(refineText, " ").toString();$|        // Alice patch start\n        // Alice: no-refine-trailing-space -- 末尾是否补空格由 设置-外观 里的开关决定（默认补）。\n        if (isSearchSuggestion\n                \&\& ChromeSharedPreferences.getInstance()\n                        .readBoolean("alice_refine_trailing_space", true)) {\n            refineText = TextUtils.concat(refineText, " ").toString();\n        }\n        // Alice patch end|' "$path1"

# 2) 外观设置页加开关（标题/摘要直接写在 XML 里，不新建资源文件、不动资源列表）
sed -i 's|^        android:summary="@string/bookmark_bar_setting_subtitle" />$|&\n\n    <!-- Alice patch start -->\n    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\n        android:key="alice_refine_trailing_space_switch"\n        android:order="3"\n        android:title="修改搜索查询时在末尾补空格"\n        android:summary="在地址栏建议里点“修改搜索查询”后，填入搜索框的内容末尾补一个空格" />\n    <!-- Alice patch end -->|' "$path2"

# 3) fragment：读/写开关（默认开，与行为默认值一致）
sed -i 's|^import org.chromium.chrome.browser.preferences.Pref;$|// Alice patch start\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\nimport org.chromium.chrome.browser.preferences.Pref;\n// Alice patch end|' "$path3"

sed -i 's|^    public static final String PREF_UI_THEME = "ui_theme";$|&\n    // Alice patch start\n    public static final String PREF_ALICE_REFINE_TRAILING_SPACE =\n            "alice_refine_trailing_space_switch";\n    // Alice patch end|' "$path3"

sed -i 's|^        initUiThemePref();$|        // Alice patch start\n        initUiThemePref();\n        initAliceRefinePref();\n        // Alice patch end|' "$path3"

sed -i '/^    private void initUiThemePref() {$/i\
    // Alice patch start\
    /** Alice: 地址栏建议 refine 后是否补空格的开关。 */\
    private void initAliceRefinePref() {\
        ChromeSwitchPreference switchPref =\
                (ChromeSwitchPreference) findPreference(PREF_ALICE_REFINE_TRAILING_SPACE);\
        switchPref.setChecked(\
                ChromeSharedPreferences.getInstance()\
                        .readBoolean("alice_refine_trailing_space", true));\
        switchPref.setOnPreferenceChangeListener(\
                (preference, newValue) -> {\
                    ChromeSharedPreferences.getInstance()\
                            .writeBoolean("alice_refine_trailing_space", (boolean) newValue);\
                    return true;\
                });\
    }\
    // Alice patch end\
' "$path3"
