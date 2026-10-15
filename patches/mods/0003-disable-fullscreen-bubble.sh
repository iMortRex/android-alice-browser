#!/bin/bash
# 禁用全屏气泡提示

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java"

# 检测是否已应用
if grep -q 'Alice patch start 0003' "$path1"; then
    exit 100
fi

sed -i 's|^\( *\)public void show() {$|\1// Alice patch start 0003\n\1public void show() { if (true) return;\n\1// Alice patch end 0003|' "$path1"

sed -i 's|^\( *\)public void update(String text) {$|\1// Alice patch start 0003\n\1public void update(String text) { if (true) return;\n\1// Alice patch end 0003|' "$path1"
