#!/bin/bash
# 工具栏横滑切换前缓存当前网页缩略图，避免离开后缩略图为空。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0067' "$path1"; then
    exit 100
fi

# 横滑前缓存当前网页标签缩略图。
sed -i '/^        if (tab != null [&][&] tab\.isNativePage()) {$/,/^        }$/c\
        // Alice patch start 0067\
        if (tab != null) {\
            assumeNonNull(mTabContentManager);\
            mTabContentManager.cacheTabThumbnail(tab);\
        }\
        // Alice patch end 0067' "$path1"
