#!/bin/bash
# 工具栏滑动（按住工具栏左右滑 / 上滑）时让工具栏保持显示 —— 手势完全保留。
#
# 为什么会消失（两条独立路径，必须同时堵）：
#   A. LayoutManagerImpl:863 发现 ToolbarSwipeLayout.forceHideBrowserControlsAndroidView() == true
#      -> 拿 hiding token -> BrowserControlsManager.shouldShowAndroidControls() 的 hasHidingTokens()
#         直接把 Android 工具栏设成 INVISIBLE。（上游行为，只有 ControlsInBrowserToolbarSwipeMock 打开才不拿 token）
#   B. 即使没有 token，BrowserControlsManager.shouldShowAndroidControls() 最后一行
#      return !BrowserControlsUtils.drawControlsAsTexture(this); 在滑动（hiddenRatio > 0）时也返回 false
#      -> 一样设成 INVISIBLE。
# 所以：打开 A 的开关（顺带让工具栏跟着手势平移，这是官方实现），同时把 B 改成不再因 hiddenRatio 隐藏。
# 注意：hiding token 的强制隐藏（全屏、HUB 标签页管理）在 hasHidingTokens() 那步，仍然优先，不受影响。

# 检测是否已应用（B 的标记）
if grep -q 'Alice: keep-toolbar-visible -- 滑动时也保持 Android 工具栏可见' "chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"; then
    exit 100
fi

# 1) 撤销更早那版对 DeviceClassManager（手势开关）的改动，把手势恢复回来
sed -i -e '/^        \/\/ Alice: keep-toolbar-visible -- 关掉工具栏滑动/d' \
    -e '/public static boolean enableToolbarSwipe()/,/^    }$/ s|^        return false;$|        return getInstance().mEnableToolbarSwipe;|' \
    "chrome/browser/device/android/java/src/org/chromium/chrome/browser/device/DeviceClassManager.java"

# 2) A：打开 ControlsInBrowserToolbarSwipeMock（原生默认值 + Java 安全默认值）
sed -i 's|BASE_FEATURE(kControlsInBrowserToolbarSwipeMock, base::FEATURE_DISABLED_BY_DEFAULT);|BASE_FEATURE(kControlsInBrowserToolbarSwipeMock, base::FEATURE_ENABLED_BY_DEFAULT);|' \
    "chrome/browser/flags/android/chrome_feature_list.cc"

sed -i 's|newCachedFlag(CONTROLS_IN_BROWSER_TOOLBAR_SWIPE_MOCK, false);|newCachedFlag(CONTROLS_IN_BROWSER_TOOLBAR_SWIPE_MOCK, true);|' \
    "chrome/browser/flags/android/java/src/org/chromium/chrome/browser/flags/ChromeFeatureList.java"

# 3) B：不再因为"控件由 compositor 画"(hiddenRatio > .0) 把 Android 工具栏设成 INVISIBLE
sed -i 's|^        return !BrowserControlsUtils.drawControlsAsTexture(this);$|        // Alice: keep-toolbar-visible -- 滑动时也保持 Android 工具栏可见（强制隐藏 token 仍然优先）。\n        return true;|' \
    "chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"
