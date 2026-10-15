#!/bin/bash
# 关闭标签页撤销时长 10000ms -> 3000ms

# 目标文件路径
path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0002' "$path1"; then
    exit 100
fi

sed -i 's|^\( *\)public static final int DEFAULT_TYPE_ACTION_SNACKBAR_DURATION_MS = 10000;$|\1// Alice patch start 0002\n\1public static final int DEFAULT_TYPE_ACTION_SNACKBAR_DURATION_MS = 3000;\n\1// Alice patch end 0002|' "$path1"
