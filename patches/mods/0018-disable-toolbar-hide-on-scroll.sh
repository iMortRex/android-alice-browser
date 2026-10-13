#!/bin/bash
# 禁用上滑页面隐藏工具栏

set -e

# 目标文件路径
path1="chrome/browser/flags/android/chrome_feature_list.cc"
path2="chrome/browser/flags/android/java/src/org/chromium/chrome/browser/flags/ChromeFeatureList.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# 原理：BrowserStateBrowserControlsVisibilityDelegate 在 AndroidToolbarScrollAblation
# 开启时把浏览器控件可见性约束锁定为 SHOWN，页面滚动不再把工具栏滚出屏幕
# （进入全屏时仍可隐藏）。

# 原生特性默认开启
sed -i 's|^\( *\)BASE_FEATURE(kAndroidToolbarScrollAblation, base::FEATURE_DISABLED_BY_DEFAULT);$|\1// Alice patch start\n\1BASE_FEATURE(kAndroidToolbarScrollAblation, base::FEATURE_ENABLED_BY_DEFAULT);\n\1// Alice patch end|' "$path1"

# Java 侧安全默认值同步开启
sed -i 's|^\( *\)newMutableFlagWithSafeDefault(TOOLBAR_SCROLL_ABLATION, false);$|\1// Alice patch start\n\1newMutableFlagWithSafeDefault(TOOLBAR_SCROLL_ABLATION, true);\n\1// Alice patch end|' "$path2"
