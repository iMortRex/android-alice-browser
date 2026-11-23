#!/bin/bash
# 设置页搜索栏：默认隐藏，可在 设置 - 外观 开启。
# 开启后仅在设置主页显示顶部搜索框，进入子页、搜索输入页和结果页时隐藏。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/settings/search/SettingsSearchCoordinator.java"
path2="chrome/android/java/res/xml/appearance_preferences.xml"
path3="chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AppearanceSettingsFragment.java"

# 检测是否已应用
if grep -q 'Alice patch start 0084' "$path1"; then
    exit 100
fi

# 搜索控制器增加偏好依赖和稳定的偏好键。
sed -i '/^import org\.chromium\.chrome\.browser\.profiles\.Profile;$/i\
// Alice patch start 0084\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0084\
' "$path1"

sed -i '/^    private static final String TAG = "SettingsSearch";$/a\
    // Alice patch start 0084\
    private static final String ALICE_SHOW_SETTINGS_SEARCH_BOX =\
            "alice_show_settings_search_box";\
    // Alice patch end 0084\
' "$path1"

# 只有开关开启且当前位于设置主页时才允许显示搜索框。
sed -i '/^    private @Nullable View getHelpMenuView() {$/i\
    // Alice patch start 0084\
    /** Whether the settings search box is enabled in 设置 - 外观. */\
    private boolean isAliceSettingsSearchBoxEnabled() {\
        return ChromeSharedPreferences.getInstance()\
                .readBoolean(ALICE_SHOW_SETTINGS_SEARCH_BOX, false);\
    }\
    \
    /** Whether the search box should be shown for the current settings page. */\
    private boolean shouldShowAliceSearchBox(boolean showOnMainSettings) {\
        return showOnMainSettings\
                \&\& mFragmentState == FS_SETTINGS\
                \&\& isAliceSettingsSearchBoxEnabled();\
    }\
    // Alice patch end 0084\
' "$path1"

# 初始化时先隐藏搜索框，后续根据开关和当前页面决定是否显示。
sed -i '/^        View searchBox = requireViewById(R.id.search_box);$/a\
        // Alice patch start 0084\
        searchBox.setVisibility(View.GONE);\
        // Alice patch end 0084\
' "$path1"

# 单栏布局重新计算可见性时同时检查开关和设置主页状态。
sed -i 's|^        searchBox.setVisibility(isShowingMainSettings() ? View.VISIBLE : View.GONE);$|        // Alice patch start 0084\
        searchBox.setVisibility(\
                shouldShowAliceSearchBox(isShowingMainSettings())\
                        ? View.VISIBLE\
                        : View.GONE);\
        // Alice patch end 0084|' "$path1"

# 多栏容器初始化时按同一规则决定搜索框是否可见。
sed -i 's|^                    searchBox.setVisibility(showingMain ? View.VISIBLE : View.GONE);$|                    // Alice patch start 0084\
                    searchBox.setVisibility(\
                            shouldShowAliceSearchBox(showingMain)\
                                    ? View.VISIBLE\
                                    : View.GONE);\
                    // Alice patch end 0084|' "$path1"

sed -i 's|^                    if (showingMain \&\& shouldAutoFocusSearchBox()) {$|                    // Alice patch start 0084\
                    if (shouldShowAliceSearchBox(showingMain)\
                            \&\& shouldAutoFocusSearchBox()) {\
                    // Alice patch end 0084|' "$path1"

# 单栏页面初始显示和无障碍焦点都受开关控制。
sed -i 's|^        searchBox.setVisibility(View.VISIBLE);$|        // Alice patch start 0084\
        searchBox.setVisibility(\
                shouldShowAliceSearchBox(/* showOnMainSettings= */ true)\
                        ? View.VISIBLE\
                        : View.GONE);\
        // Alice patch end 0084|' "$path1"

sed -i 's|^        if (shouldAutoFocusSearchBox()) {$|        // Alice patch start 0084\
        if (shouldShowAliceSearchBox(/* showOnMainSettings= */ true)\
                \&\& shouldAutoFocusSearchBox()) {\
        // Alice patch end 0084|' "$path1"

# 单栏切换统一经过显示函数，确保关闭开关后不会被页面回调重新显示。
sed -i '/^    private void showUiInSingleColumn(View searchBox, boolean show) {$/a\
        // Alice patch start 0084\
        show = shouldShowAliceSearchBox(show);\
        // Alice patch end 0084\
' "$path1"

# 异步重试使用 final 副本，避免被重新赋值的参数无法被 Lambda 捕获。
sed -i 's|^            mHandler.post(() -> showUiInSingleColumn(searchBox, show));$|            // Alice patch start 0084\
            final boolean pendingAliceShow = show;\
            mHandler.post(() -> showUiInSingleColumn(searchBox, pendingAliceShow));\
            // Alice patch end 0084|' "$path1"

# 退出搜索状态时，只有开启开关才恢复多栏布局中的搜索框。
sed -i 's|^            searchBox.setVisibility(View.VISIBLE);$|            // Alice patch start 0084\
            searchBox.setVisibility(\
                    isAliceSettingsSearchBoxEnabled() ? View.VISIBLE : View.GONE);\
            // Alice patch end 0084|' "$path1"

sed -i 's|^            if (shouldAutoFocusSearchBox()) {$|            // Alice patch start 0084\
            if (isAliceSettingsSearchBoxEnabled() \&\& shouldAutoFocusSearchBox()) {\
            // Alice patch end 0084|' "$path1"

# 局部搜索结束时，不越过“设置页搜索栏”开关重新显示搜索框。
sed -i 's|^        searchBox.setVisibility(show ? View.VISIBLE : View.GONE);$|        // Alice patch start 0084\
        searchBox.setVisibility(\
                show \&\& isAliceSettingsSearchBoxEnabled() ? View.VISIBLE : View.GONE);\
        // Alice patch end 0084|' "$path1"

# 多栏布局的普通设置页同样默认隐藏搜索框。
sed -i '0,/^                if (mSuppressUi) {$/s|^                if (mSuppressUi) {$|                // Alice patch start 0084\
                if (mSuppressUi || !isAliceSettingsSearchBoxEnabled()) {\
                // Alice patch end 0084|' "$path1"

# 单栏布局切换时保留原有“主页显示、子页隐藏”的语义，并叠加开关判断。
sed -i '/^            if (showingMain) {$/,/^            }$/c\
            // Alice patch start 0084\
            if (shouldShowAliceSearchBox(showingMain)) {\
                searchBox.setVisibility(View.VISIBLE);\
            } else {\
                searchBox.setVisibility(View.GONE);\
                query.setVisibility(View.GONE);\
            }\
            // Alice patch end 0084' "$path1"

# 外观设置页增加开关，默认关闭。
sed -i 's|^        android:summary="@string/bookmark_bar_setting_subtitle" />$|&\
\
    <!-- Alice patch start 0084 -->\
    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\
        android:key="alice_show_settings_search_box_switch"\
        android:order="5"\
        android:title="Show settings search bar"\
        android:summary="Show the search box only on the main settings page. It stays hidden on subpages." />\
    <!-- Alice patch end 0084 -->|' "$path2"

sed -i '/^    public static final String PREF_UI_THEME = "ui_theme";$/a\
    // Alice patch start 0084\
    public static final String PREF_ALICE_SHOW_SETTINGS_SEARCH_BOX =\
            "alice_show_settings_search_box_switch";\
    // Alice patch end 0084\
' "$path3"

sed -i '/^        initTabPositionPref();$/a\
        // Alice patch start 0084\
        initAliceShowSettingsSearchBoxPref();\
        // Alice patch end 0084\
' "$path3"

sed -i '/^    private void updateUiThemePref() {$/i\
    // Alice patch start 0084\
    /** Alice: 设置页搜索栏开关。 */\
    private void initAliceShowSettingsSearchBoxPref() {\
        ChromeSwitchPreference switchPref =\
                (ChromeSwitchPreference)\
                        findPreference(PREF_ALICE_SHOW_SETTINGS_SEARCH_BOX);\
        String aliceLanguage =\
                getResources().getConfiguration().getLocales().get(0).getLanguage();\
        if ("zh".equals(aliceLanguage)) {\
            switchPref.setTitle("开启设置页搜索栏");\
            switchPref.setSummary("仅在设置主页显示顶部搜索框，进入子页后隐藏。");\
        }\
        switchPref.setChecked(\
                org.chromium.chrome.browser.preferences.ChromeSharedPreferences.getInstance()\
                        .readBoolean(\
                                "alice_show_settings_search_box",\
                                false));\
        switchPref.setOnPreferenceChangeListener(\
                (preference, newValue) -> {\
                    org.chromium.chrome.browser.preferences.ChromeSharedPreferences.getInstance()\
                            .writeBoolean(\
                                    "alice_show_settings_search_box",\
                                    (boolean) newValue);\
                    return true;\
                });\
    }\
    // Alice patch end 0084\
' "$path3"
