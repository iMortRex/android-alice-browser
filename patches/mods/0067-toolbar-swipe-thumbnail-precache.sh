#!/bin/bash
# 工具栏横滑切换前缓存当前网页缩略图，避免离开后缩略图为空。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0067' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 横滑前缓存当前网页标签缩略图。加载中的页面稍后会再次触发缩略图更新，
# 此处跳过可以避免把未加载完成的内容和错误的工具栏快照写进缓存。
sed -i '/^        if (tab != null [&][&] tab\.isNativePage()) {$/,/^        }$/c\
        // Alice patch start 0067\
        if (tab != null \&\& !tab.isLoading()) {\
            assumeNonNull(mTabContentManager);\
            mTabContentManager.cacheTabThumbnail(tab);\
        }\
        // Alice patch end 0067' "$path1"
