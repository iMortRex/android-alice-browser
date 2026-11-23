#!/bin/bash
# Activity 重建或长时间后台恢复时，避免重新打开原始 URL、主页或 NTP。

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/init/AsyncInitializationActivity.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start 0043' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 不依赖默认关闭的 ClearIntentWhenRecreated 功能开关，重建时始终规范化 Intent。
sed -i '/^        if (ChromeFeatureList\.sClearIntentWhenRecreated\.isEnabled()) {$/,/^        }$/c\
        // Alice patch start 0043\
        setIntent(IntentHandler.rewriteFromHistoryIntent(getIntent(), savedInstanceState));\
        // Alice patch end 0043' "$path1"

# 较晚的旧逻辑只处理从最近任务启动；Intent 已在上一步统一清理，因此移除。
sed -i '/^        if (!ChromeFeatureList\.sClearIntentWhenRecreated\.isEnabled()) {$/,/^        }$/c\
        // Alice patch start 0043\
        // Launch intent was normalized before onCreateInternal().\
        // Alice patch end 0043' "$path1"

# 长时间后台后返回时保持原标签页，不按后台时长创建或切换到 NTP。
sed -i '/^    private boolean shouldShowNtpHomeSurfaceOnStartup() {$/,/^    }$/c\
    // Alice patch start 0043\
    private boolean shouldShowNtpHomeSurfaceOnStartup() {\
        // Alice: 从后台返回时继续显示原标签页，不创建 NTP 首页。\
        return false;\
    }\
    // Alice patch end 0043' "$path2"
