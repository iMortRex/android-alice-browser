#!/bin/bash
set -e

# 关闭标签页撤销和下载完成气泡时长

# 目标文件路径
path1="chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarManager.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/messages/ChromeMessageAutodismissDurationProvider.java"

# 检测是否已应用
if grep -q 'Alice patch start 0002' "$path1"; then
    exit 100
fi

sed -i 's|^\( *\)public static final int DEFAULT_TYPE_ACTION_SNACKBAR_DURATION_MS = 10000;$|\1// Alice patch start 0002\n\1public static final int DEFAULT_TYPE_ACTION_SNACKBAR_DURATION_MS = 3000;\n\1// Alice patch end 0002|' "$path1"

sed -i '/^    public long get(@MessageIdentifier int messageIdentifier, long customDuration) {$/a\
        // Alice patch start 0002\
        if (messageIdentifier == MessageIdentifier.DOWNLOAD_PROGRESS) {\
            return 5 * DateUtils.SECOND_IN_MILLIS;\
        }\
        // Alice patch end 0002\
' "$path2"
