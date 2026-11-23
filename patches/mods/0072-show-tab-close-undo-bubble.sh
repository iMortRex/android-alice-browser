#!/bin/bash
# 设置-标签页和标签页分组：显示或隐藏标签页关闭、标签组关闭及标签组合并的撤销气泡，默认开。
# 与 0002/0029/0034 兼容：只阻止撤销 Snackbar 创建，不改变其时长、层级、位置和动画。

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/res/xml/tabs_settings.xml"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabsSettings.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/undo_tab_close_snackbar/TabUndoBarController.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/undo_tab_close_snackbar/SavedTabGroupUndoBarController.java"
path5="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/UndoGroupSnackbarController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0072' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 设置页只保留标题和开关。
sed -i 's|^</PreferenceScreen>$|    <!-- Alice patch start 0072 -->\
    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\
        android:key="alice_show_tab_close_undo_bar_switch"\
        android:title="Show undo bubble" />\
    <!-- Alice patch end 0072 -->\
\
</PreferenceScreen>|' "$path1"

# 偏好键：设置页使用独立 key，行为读取持久化值。
sed -i '/^    static final String PREF_CCT_ALWAYS_OPEN_IN_BROWSER = "cct_always_open_in_browser";$/a\
\
    // Alice patch start 0072\
    public static final String PREF_ALICE_SHOW_TAB_CLOSE_UNDO_BAR_SWITCH =\
            "alice_show_tab_close_undo_bar_switch";\
    public static final String ALICE_SHOW_TAB_CLOSE_UNDO_BAR =\
            "alice_show_tab_close_undo_bar";\
    // Alice patch end 0072' "$path2"

# 初始化设置页开关。
sed -i '/^        configureCctAlwaysOpenInBrowserSwitch();$/a\
        // Alice patch start 0072\
        configureAliceShowTabCloseUndoBarSwitch();\
        // Alice patch end 0072' "$path2"

# 开关默认开，中文界面显示中文标题，不设置说明文字。
sed -i '/^    private static boolean isTabGroupSyncAutoOpenConfigurable(Profile profile) {$/i\
    // Alice patch start 0072\
    private void configureAliceShowTabCloseUndoBarSwitch() {\
        ChromeSwitchPreference switchPref =\
                assertNonNull(\
                        findPreference(\
                                PREF_ALICE_SHOW_TAB_CLOSE_UNDO_BAR_SWITCH));\
        String aliceLanguage =\
                getResources().getConfiguration().getLocales().get(0).getLanguage();\
        if ("zh".equals(aliceLanguage)) {\
            switchPref.setTitle("显示撤销气泡");\
        }\
        switchPref.setChecked(\
                ChromeSharedPreferences.getInstance()\
                        .readBoolean(\
                                ALICE_SHOW_TAB_CLOSE_UNDO_BAR,\
                                true));\
        switchPref.setOnPreferenceChangeListener(\
                (preference, newValue) -> {\
                    ChromeSharedPreferences.getInstance()\
                            .writeBoolean(\
                                    ALICE_SHOW_TAB_CLOSE_UNDO_BAR,\
                                    (boolean) newValue);\
                    return true;\
                });\
    }\
    // Alice patch end 0072\
' "$path2"

# 普通标签页关闭：开关关闭时不显示气泡，并在当前事件结束后立即提交关闭。
sed -i '/^import org\.chromium\.base\.Token;$/i\
// Alice patch start 0072\
import org.chromium.base.ThreadUtils;\
// Alice patch end 0072' "$path3"
sed -i '/^import org\.chromium\.chrome\.browser\.profiles\.Profile;$/i\
// Alice patch start 0072\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0072' "$path3"
sed -i '/^    private final TabModelObserver mTabModelObserver;$/i\
    // Alice patch start 0072\
    private static final String ALICE_SHOW_TAB_CLOSE_UNDO_BAR =\
            "alice_show_tab_close_undo_bar";\
    // Alice patch end 0072' "$path3"
sed -i '/^                        if (disableUndo(true)) return;$/a\
                        // Alice patch start 0072\
                        if (!ChromeSharedPreferences.getInstance()\
                                .readBoolean(\
                                        ALICE_SHOW_TAB_CLOSE_UNDO_BAR,\
                                        true)) {\
                            ThreadUtils.postOnUiThread(\
                                    () -> {\
                                        for (Tab tab : tabs) {\
                                            TabModel model =\
                                                    mTabModelSelector.getModelForTabId(\
                                                            tab.getId());\
                                            if (model != null) {\
                                                model.commitTabClosure(tab.getId());\
                                            }\
                                        }\
                                    });\
                            return;\
                        }\
                        // Alice patch end 0072' "$path3"

# 已保存标签组关闭：关闭时只提交关联标签页，不创建撤销气泡和租约。
sed -i '/^import org\.chromium\.chrome\.browser\.tab\.Tab;$/i\
// Alice patch start 0072\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0072' "$path4"
sed -i '/^    private final ArchivedTabModelOrchestrator mArchivedTabModelOrchestrator;$/i\
    // Alice patch start 0072\
    private static final String ALICE_SHOW_TAB_CLOSE_UNDO_BAR =\
            "alice_show_tab_close_undo_bar";\
    // Alice patch end 0072' "$path4"
sed -i '/^        if (tabs\.isEmpty() \&\& savedTabGroupSyncIds\.isEmpty()) return;$/a\
        // Alice patch start 0072\
        if (!ChromeSharedPreferences.getInstance()\
                .readBoolean(ALICE_SHOW_TAB_CLOSE_UNDO_BAR, true)) {\
            for (Tab tab : tabs) {\
                TabModel model = mTabModelSelector.getModelForTabId(tab.getId());\
                if (model != null) {\
                    model.commitTabClosure(tab.getId());\
                }\
            }\
            return;\
        }\
        // Alice patch end 0072' "$path4"

# 标签组合并：关闭时让待撤销的标签组操作立即过期，不显示气泡。
sed -i '/^import org\.chromium\.chrome\.browser\.tab\.Tab;$/i\
// Alice patch start 0072\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0072' "$path5"
sed -i '/^        int mergedGroupSize = tabModel\.getTabCountForGroup(undoGroupMetadata\.getTabGroupId());$/i\
        // Alice patch start 0072\
        if (!ChromeSharedPreferences.getInstance()\
                .readBoolean(\
                        "alice_show_tab_close_undo_bar",\
                        true)) {\
            tabModel.undoGroupOperationExpired(undoGroupMetadata);\
            return;\
        }\
        // Alice patch end 0072' "$path5"
