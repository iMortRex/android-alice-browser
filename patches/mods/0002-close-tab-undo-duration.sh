#!/bin/bash
# 关闭标签页撤销时长

sed -i 's|public static final int DEFAULT_TYPE_ACTION_SNACKBAR_DURATION_MS = 10000;|public static final int DEFAULT_TYPE_ACTION_SNACKBAR_DURATION_MS = 3000;|' \
    chrome/browser/ui/messages/android/java/src/org/chromium/chrome/browser/ui/messages/snackbar/SnackbarManager.java