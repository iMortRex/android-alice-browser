#!/bin/bash
# Display Cutout 模式固定为 1

# 检测是否以应用
if grep -q 'gridLayoutManager.setStackFromEnd(true);' "chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"; then
    echo "已应用，跳过: $(basename "$0")"
    exit 0
fi

sed -i '/mRecyclerView.setLayoutManager(gridLayoutManager);/i\                gridLayoutManager.setStackFromEnd(true);' \
    chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java