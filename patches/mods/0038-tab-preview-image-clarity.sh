#!/bin/bash
set -e

# 提升标签预览图清晰度

# 目标文件路径
path1="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0038' "$path1"; then
    exit 100
fi

sed -i 's|^\( *\)thumbnailScale = 1.5f / deviceDensity;$|\1// Alice patch start 0038\n\1thumbnailScale = 2.5f / deviceDensity;\n\1// Alice patch end 0038|' "$path1"

