#!/bin/bash
# 地址栏建议的「修改搜索查询」(refine) 按钮：填入搜索框的文本末尾是否补空格
# 开关在 设置 - 标签页和标签页分组，默认开（= 上游行为）

set -e

# 目标文件路径
path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"
path2="chrome/android/features/tab_ui/java/res/xml/tabs_settings.xml"
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabsSettings.java"

# 检测是否已应用
if grep -q 'Alice patch start 0021' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 1) 行为：末尾是否补空格由 设置-标签页和标签页分组 的开关决定（默认补）
sed -i 's|^import org.chromium.chrome.browser.omnibox.R;$|// Alice patch start 0021\nimport org.chromium.chrome.browser.omnibox.R;\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\n// Alice patch end 0021|' "$path1"

sed -i 's|^        if (isSearchSuggestion) refineText = TextUtils.concat(refineText, " ").toString();$|        // Alice patch start 0021\n        // Alice: no-refine-trailing-space -- 末尾是否补空格由 设置-标签页和标签页分组 里的开关决定（默认补）。\n        if (isSearchSuggestion\n                \&\& ChromeSharedPreferences.getInstance()\n                        .readBoolean("alice_refine_trailing_space", true)) {\n            refineText = TextUtils.concat(refineText, " ").toString();\n        }\n        // Alice patch end 0021|' "$path1"

# 2) 标签页和标签页分组设置页加开关（默认英文，简体中文由 Fragment 覆盖）
sed -i 's|^</PreferenceScreen>$|    <!-- Alice patch start 0021 -->\n    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\n        android:key="alice_refine_trailing_space_switch"\n        android:order="1"\n        android:title="Add a trailing space to refined search queries"\n        android:summary="Adds a trailing space after you choose to refine a search query" />\n    <!-- Alice patch end 0021 -->\n</PreferenceScreen>|' "$path2"

# 3) fragment：读/写开关（默认开，与行为默认值一致）
sed -i 's|^    static final String PREF_CCT_ALWAYS_OPEN_IN_BROWSER = "cct_always_open_in_browser";$|&\n    // Alice patch start 0021\n    static final String PREF_ALICE_REFINE_TRAILING_SPACE =\n            "alice_refine_trailing_space_switch";\n    // Alice patch end 0021|' "$path3"

sed -i 's|^        configureCctAlwaysOpenInBrowserSwitch();$|&\n        // Alice patch start 0021\n        configureAliceRefineTrailingSpaceSwitch();\n        // Alice patch end 0021|' "$path3"

# 在唯一的 CCT 配置方法前插入，避免匹配到类内所有 @Override。
sed -i '/^    private void configureCctAlwaysOpenInBrowserSwitch() {$/i\
    // Alice patch start 0021\
    /** Alice: 地址栏建议 refine 后是否补空格的开关。 */\
    private void configureAliceRefineTrailingSpaceSwitch() {\
        ChromeSwitchPreference switchPref =\
                (ChromeSwitchPreference) findPreference(PREF_ALICE_REFINE_TRAILING_SPACE);\
        String aliceLanguage =\
                getResources().getConfiguration().getLocales().get(0).getLanguage();\
        if ("zh".equals(aliceLanguage)) {\
            switchPref.setTitle("修改搜索查询时在末尾补空格");\
            switchPref.setSummary(\
                    "在地址栏建议里点“修改搜索查询”后，填入搜索框的内容末尾补一个空格");\
        }\
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
    // Alice patch end 0021\
' "$path3"
