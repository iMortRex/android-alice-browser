#!/bin/bash
# 地址栏建议的「修改搜索查询」(refine) 按钮：填入搜索框的文本末尾是否补空格
# 开关在 设置 - 外观，默认开（= 上游行为）

# 检测是否已应用
if grep -q 'Alice: no-refine-trailing-space' "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"; then
    exit 100
fi

# 1) 行为：末尾是否补空格改由 设置-外观 的开关决定（默认补）
sed -i 's|^import org.chromium.chrome.browser.omnibox.R;$|&\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;|' \
    chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java

sed -i 's|^        if (isSearchSuggestion) refineText = TextUtils.concat(refineText, " ").toString();$|        // Alice: no-refine-trailing-space -- 末尾是否补空格由 设置-外观 里的开关决定（默认补）。\n        if (isSearchSuggestion\n                \&\& ChromeSharedPreferences.getInstance()\n                        .readBoolean("alice_refine_trailing_space", true)) {\n            refineText = TextUtils.concat(refineText, " ").toString();\n        }|' \
    chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java

# 2) 外观设置页加开关（标题/摘要直接写在 XML 里，不新建资源文件、不动资源列表）
sed -i 's|^        android:summary="@string/bookmark_bar_setting_subtitle" />$|&\n\n    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\n        android:key="alice_refine_trailing_space_switch"\n        android:order="3"\n        android:title="修改搜索查询时在末尾补空格"\n        android:summary="在地址栏建议里点“修改搜索查询”后，填入搜索框的内容末尾补一个空格" />|' \
    chrome/android/java/res/xml/appearance_preferences.xml

# 3) fragment：读/写开关（默认开，与行为默认值一致）
sed -i 's|^import org.chromium.chrome.browser.preferences.Pref;$|import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\n&|' \
    chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java

sed -i 's|^    public static final String PREF_UI_THEME = "ui_theme";$|&\n    public static final String PREF_ALICE_REFINE_TRAILING_SPACE =\n            "alice_refine_trailing_space_switch";|' \
    chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java

sed -i 's|^        initUiThemePref();$|&\n        initAliceRefinePref();|' \
    chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java

sed -i '/^    private void initUiThemePref() {$/i\
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
' \
    chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java
