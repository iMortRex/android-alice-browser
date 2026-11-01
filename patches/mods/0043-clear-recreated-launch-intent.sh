#!/bin/bash
# Activity 重建时清理旧启动 Intent，避免重新打开原始 URL 或主页。

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/init/AsyncInitializationActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start 0043' "$path1"; then
    exit 100
fi

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
