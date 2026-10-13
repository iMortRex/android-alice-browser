#!/bin/bash
# 关闭最后一个标签时：不退出浏览器，改成自动开一个新标签页
# 对应 smali: Lpl2;->c(ZZ)V（ChromeTabbedActivity 的 TabModelSelectorTabModelObserver）
#
# 跟 smali 版的三处区别（smali 版会闪退 / 会多开）：
#   1) API 是 ChromeTabCreator.launchNtp(@TabLaunchType int)，不是 launchNTP()
#   2) 这段跑在 tab 变化通知里，同步建标签 -> ConcurrentModificationException（闪退）
#   3) 同一个关闭动作会来多次通知，每通知一次就 post 一个建标签任务 ->
#      会一次开 2 个、下次 4 个（翻倍），所以任务里必须再复查一次

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

sed -i '/private void closeIfNoTabsAndHomepageEnabled($/,/^                        }$/c\
                        // Alice patch start\
                        private void closeIfNoTabsAndHomepageEnabled(\
                                boolean isPendingClosure, boolean shouldRemoveWindowWithZeroTabs) {\
                            if (getTabModelSelector().getTotalTabCount() != 0) return;\
\
                            // Alice: keep a tab alive -- 主页是 URL 时不再退出浏览器（原来是 finish()）\
                            if (!shouldRemoveWindowWithZeroTabs\
                                    && !isPendingClosure\
                                    && HomepageManager.getInstance().shouldCloseAppWithZeroTabs()) {\
                                return;\
                            }\
\
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
                        // Alice patch end' "$path1"
