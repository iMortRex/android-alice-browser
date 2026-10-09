#!/bin/bash
# 禁用全屏气泡提示

# 检测是否已应用
if grep -q 'public void show() { if (true) return;' "chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java"; then
    exit 100
fi

sed -i 's|public void show() {|public void show() { if (true) return;|' \
    chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java

sed -i 's|public void update(String text) {|public void update(String text) { if (true) return;|' \
    chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java