#!/bin/bash
# 标签页关闭撤销：批量关闭或连续关闭时只记录最后一个关闭的标签页。
# 与 0072 兼容：开关关闭时 0072 会在本补丁逻辑之前提交并返回。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/undo_tab_close_snackbar/TabUndoBarController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0083' "$path1"; then
    exit 100
fi

# 在替换当前关闭事件之前，提交上一轮可见及排队中的关闭项。
sed -i '/^    private static class ClosureMetadata {$/i\
    // Alice patch start 0083\
    private void commitAlicePreviousClosures() {\
        mSnackbarManageable.getSnackbarManager().dismissSnackbars(this);\
        while (!mEventQueue.isEmpty()) {\
            TabClosureEvent event = mEventQueue.poll();\
            for (Tab tab : event.tabs) {\
                commitAliceTabClosure(tab);\
            }\
        }\
    }\
\
    private void commitAliceTabClosure(Tab tab) {\
        TabModel model = mTabModelSelector.getModelForTabId(tab.getId());\
        if (model != null) model.commitTabClosure(tab.getId());\
    }\
    // Alice patch end 0083\
' "$path1"

# 一次关闭多个标签页时，只把最后一个加入撤销队列，其余立即提交。
# 连续关闭时先清掉上一轮待撤销项，因此始终只保留最近一次关闭。
sed -i 's|^                        queueUndoBar(new TabClosureEvent(tabs, isAllTabs));$|                        // Alice patch start 0083\
                        commitAlicePreviousClosures();\
                        List<Tab> alicePendingTabs = tabs;\
                        if (tabs.size() > 1) {\
                            for (int aliceIndex = 0;\
                                    aliceIndex < tabs.size() - 1;\
                                    aliceIndex++) {\
                                commitAliceTabClosure(tabs.get(aliceIndex));\
                            }\
                            alicePendingTabs = List.of(tabs.get(tabs.size() - 1));\
                        }\
                        queueUndoBar(\
                                new TabClosureEvent(\
                                        alicePendingTabs, /* isAllTabs= */ false));\
                        // Alice patch end 0083|' "$path1"
