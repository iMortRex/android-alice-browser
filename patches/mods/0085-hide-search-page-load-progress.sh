#!/bin/bash
# 搜索页聚焦期间隐藏工具栏加载进度条。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"

# 进度条可见性同时受标签页模式和 URL 焦点控制。
sed -i '/^    private void updateProgressBarVisibility() {$/,/^    }$/c\
    // Alice patch start 0085\
    private void updateProgressBarVisibility() {\
        getProgressBar()\
                .setVisibility(\
                        mTabSwitcherState != STATIC_TAB || urlHasFocus()\
                                ? INVISIBLE\
                                : VISIBLE);\
    }\
    // Alice patch end 0085' "$path1"

# URL 焦点变化时立即同步进度条可见性。
sed -i '/^        super\.onUrlFocusChange(hasFocus);$/a\
        // Alice patch start 0085\
        updateProgressBarVisibility();\
        // Alice patch end 0085\
' "$path1"
