#!/bin/bash
# 禁用全屏气泡提示

# 检测是否以应用
if grep -q 'public void show() { if (true) return;' "chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java"; then
    echo "已应用，跳过: $(basename "$0")"
    exit 0
fi

sed -i 's|public void show() {|public void show() { if (true) return;|' \
    chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java

sed -i 's|public void update(String text) {|public void update(String text) { if (true) return;|' \
    chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java