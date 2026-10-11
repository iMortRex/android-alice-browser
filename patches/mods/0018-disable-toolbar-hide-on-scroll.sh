#!/bin/bash
# 禁用上滑页面隐藏工具栏
#
# 原理：BrowserStateBrowserControlsVisibilityDelegate 在 AndroidToolbarScrollAblation
# 开启时把浏览器控件可见性约束锁定为 SHOWN，页面滚动不再把工具栏滚出屏幕
# （进入全屏时仍可隐藏）。

# 检测是否已应用
if grep -q 'kAndroidToolbarScrollAblation, base::FEATURE_ENABLED_BY_DEFAULT' "chrome/browser/flags/android/chrome_feature_list.cc"; then
    exit 100
fi

# 原生特性默认开启
sed -i 's|BASE_FEATURE(kAndroidToolbarScrollAblation, base::FEATURE_DISABLED_BY_DEFAULT);|BASE_FEATURE(kAndroidToolbarScrollAblation, base::FEATURE_ENABLED_BY_DEFAULT);|' \
    "chrome/browser/flags/android/chrome_feature_list.cc"

# Java 侧安全默认值同步开启
sed -i 's|newMutableFlagWithSafeDefault(TOOLBAR_SCROLL_ABLATION, false);|newMutableFlagWithSafeDefault(TOOLBAR_SCROLL_ABLATION, true);|' \
    "chrome/browser/flags/android/java/src/org/chromium/chrome/browser/flags/ChromeFeatureList.java"
