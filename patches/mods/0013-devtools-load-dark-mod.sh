#!/bin/bash
# DevTools 获取浏览器深浅色

set -e

# 检测是否已应用（原来的 flag 已不存在 = 已应用）
if ! grep -q 'FLAG_ACTIVITY_NEW_TASK' "chrome/android/java/src/org/chromium/chrome/browser/devtools/DevToolsActivity.java"; then
    exit 100
fi

sed -i '/^        intent.addFlags($/,/^                        | Intent.FLAG_ACTIVITY_MULTIPLE_TASK);$/d' \
    "chrome/android/java/src/org/chromium/chrome/browser/devtools/DevToolsActivity.java"
