#!/bin/bash
# 关闭最后一个标签时：不退出浏览器；设置中可控制是否自动开一个新标签页，默认开。

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridDialogMediator.java"
path3="chrome/android/features/tab_ui/java/res/xml/tabs_settings.xml"
path4="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabsSettings.java"

# 检测是否已应用
if grep -q 'Alice patch start 0016' "$path1"; then
    exit 100
fi

# 标签组页面需要读取开关状态。
sed -i '/^import org\.chromium\.chrome\.browser\.profiles\.Profile;$/i\
// Alice patch start 0016\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0016\
' "$path2"

sed -i '/private void closeIfNoTabsAndHomepageEnabled($/,/^                        }$/c\
                        // Alice patch start 0016\
                        private void closeIfNoTabsAndHomepageEnabled(\
                                boolean isPendingClosure, boolean shouldRemoveWindowWithZeroTabs) {\
                            if (getTabModelSelector().getTotalTabCount() != 0) return;\
\
                            // Alice: 主页是自定义网址时也走同一套保活逻辑。\
                            // Alice: 不退出浏览器是基础功能，不受设置开关影响。\
                            // Alice: 开关只控制关掉最后一个标签后是否新建一个标签页。\
                            // 1) 这段跑在 tab 变化通知里，同步建标签会 ConcurrentModificationException，\
                            //    所以必须 post 到下一帧；\
                            // 2) 同一个关闭动作会来好几次通知（onTabClosePending / onFinishingTabClosure\
                            //    / tabRemoved），每次都会 post 一个任务，所以任务里要再复查一次，\
                            //    否则一次会建出多个标签（2 个、4 个、8 个…）。\
                            if (isFinishing()) return;\
                            PostTask.postTask(\
                                    TaskTraits.UI_DEFAULT,\
                                    () -> {\
                                        if (isFinishing()) return;\
                                        if (getTabModelSelector().getTotalTabCount() != 0) return;\
                                        if (!ChromeSharedPreferences.getInstance()\
                                                .readBoolean(\
                                                        TabsSettings\
                                                                .ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE,\
                                                        true)) {\
                                            return;\
                                        }\
                                        getTabCreator(/* incognito= */ false)\
                                                .launchNtp(TabLaunchType.FROM_CHROME_UI);\
                                    });\
                        }\
                        // Alice patch end 0016' "$path1"

# --- 标签组页面：关掉最后一个标签时按开关补一个 NTP ---
sed -i '/^                            @TabClosingSource int closingSource) {$/a\
\
                        // Alice patch start 0016\
                        // 标签组页面里关掉最后一个标签时兜底补一个 NTP。\
                        {\
                            TabModel aliceModel = mCurrentTabModelSupplier.get();\
                            if (aliceModel != null) {\
                                PostTask.postTask(\
                                        TaskTraits.UI_DEFAULT,\
                                        () -> {\
                                            if (aliceModel.getCount() != 0) return;\
                                            if (!ChromeSharedPreferences.getInstance()\
                                                    .readBoolean(\
                                                            TabsSettings\
                                                                    .ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE,\
                                                            true)) {\
                                                return;\
                                            }\
                                            TabCreatorUtil.launchNtp(aliceModel.getTabCreator());\
                                        });\
                            }\
                        }\
                        // Alice patch end 0016' "$path2"

# --- 设置页：只有标题和开关，不带底部说明。 ---
sed -i 's|^</PreferenceScreen>$|    <!-- Alice patch start 0016 -->\
    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\
        android:key="alice_open_new_tab_on_last_close_switch"\
        android:title="Open a new tab after closing the last tab" />\
    <!-- Alice patch end 0016 -->\
\
</PreferenceScreen>|' "$path3"

# 设置页偏好键，以及行为读取用的键。
sed -i '/^    static final String PREF_CCT_ALWAYS_OPEN_IN_BROWSER = "cct_always_open_in_browser";$/a\
\
    // Alice patch start 0016\
    public static final String PREF_ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE_SWITCH =\
            "alice_open_new_tab_on_last_close_switch";\
    public static final String ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE =\
            "alice_open_new_tab_on_last_close";\
    // Alice patch end 0016' "$path4"

# 初始化设置页开关。
sed -i '/^        configureCctAlwaysOpenInBrowserSwitch();$/a\
        // Alice patch start 0016\
        configureAliceOpenNewTabOnLastCloseSwitch();\
        // Alice patch end 0016' "$path4"

sed -i '/^    private static boolean isTabGroupSyncAutoOpenConfigurable(Profile profile) {$/i\
    // Alice patch start 0016\
    private void configureAliceOpenNewTabOnLastCloseSwitch() {\
        ChromeSwitchPreference switchPref =\
                assertNonNull(\
                        findPreference(\
                                PREF_ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE_SWITCH));\
        String aliceLanguage =\
                getResources().getConfiguration().getLocales().get(0).getLanguage();\
        if ("zh".equals(aliceLanguage)) {\
            switchPref.setTitle("关闭最后一个标签页后新建标签页");\
        }\
        switchPref.setChecked(\
                ChromeSharedPreferences.getInstance()\
                        .readBoolean(ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE, true));\
        switchPref.setOnPreferenceChangeListener(\
                (preference, newValue) -> {\
                    ChromeSharedPreferences.getInstance()\
                            .writeBoolean(\
                                    ALICE_OPEN_NEW_TAB_ON_LAST_CLOSE,\
                                    (boolean) newValue);\
                    return true;\
                });\
    }\
    // Alice patch end 0016\
' "$path4"
