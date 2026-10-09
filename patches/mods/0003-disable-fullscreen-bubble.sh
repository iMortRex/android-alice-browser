#!/bin/bash
# 禁用全屏气泡提示

sed -i 's|public void show() {|public void show() { if (true) return;|' \
    chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java

sed -i 's|public void update(String text) {|public void update(String text) { if (true) return;|' \
    chrome/android/java/src/org/chromium/chrome/browser/ui/ExclusiveAccessBubble.java