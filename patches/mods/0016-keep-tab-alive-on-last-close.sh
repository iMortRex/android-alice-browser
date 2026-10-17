#!/bin/bash
# 关闭最后一个标签时：不退出浏览器，改成自动开一个新标签页

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridDialogMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0016' "$path1"; then
    exit 100
fi

sed -i '/private void closeIfNoTabsAndHomepageEnabled($/,/^                        }$/c\
                        // Alice patch start 0016\
                        private void closeIfNoTabsAndHomepageEnabled(\
                                boolean isPendingClosure, boolean shouldRemoveWindowWithZeroTabs) {\
                            if (getTabModelSelector().getTotalTabCount() != 0) return;\
\
                            // Alice: 主页是自定义网址时也不要在这里 return，统一补一个新标签页。\
                            // Alice: keep a tab alive -- 关掉最后一个标签后自动开一个新标签页。\
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
                                        getTabCreator(/* incognito= */ false)\
                                                .launchNtp(TabLaunchType.FROM_CHROME_UI);\
                                    });\
                        }\
                        // Alice patch end 0016' "$path1"

# --- 标签组页面：关掉最后一个标签时补一个 NTP ---
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
                                            TabCreatorUtil.launchNtp(aliceModel.getTabCreator());\
                                        });\
                            }\
                        }\
                        // Alice patch end 0016' "$path2"
