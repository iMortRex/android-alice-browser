#!/bin/bash
# Display Cutout 模式固定为 1

# 检测是否已应用
if grep -q 'gridLayoutManager.setStackFromEnd(true);' "chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"; then
    exit 100
fi

sed -i '/mRecyclerView.setLayoutManager(gridLayoutManager);/i\                gridLayoutManager.setStackFromEnd(true);' \
    chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java