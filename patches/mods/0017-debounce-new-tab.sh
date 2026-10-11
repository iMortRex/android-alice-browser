#!/bin/bash
# 新建标签页连点节流

# 检测是否已应用
if grep -q 'Alice: debounce repeated taps' "chrome/android/java/src/org/chromium/chrome/browser/tabmodel/ChromeTabCreator.java"; then
    exit 100
fi

# 1) 加静态时间戳字段（锚点是唯一的 UNKNOWN_APP_ID）
sed -i '/^    private static final String UNKNOWN_APP_ID = /a\
\
    // Alice: debounce repeated taps -- 连点节流用的时间戳（uptimeMillis）\
    private static long sAliceLastNtpMs;' \
    "chrome/android/java/src/org/chromium/chrome/browser/tabmodel/ChromeTabCreator.java"

# 2) 在 launchNtp 方法体开头插入节流
sed -i '/^    public void launchNtp(@TabLaunchType int type) {$/a\
        // Alice: debounce repeated taps -- 1000ms 内只放行一次（不管点的是哪个界面的 +）\
        {\
            long aliceNow = android.os.SystemClock.uptimeMillis();\
            if (aliceNow - sAliceLastNtpMs < 1000) return;\
            sAliceLastNtpMs = aliceNow;\
        }' \
    "chrome/android/java/src/org/chromium/chrome/browser/tabmodel/ChromeTabCreator.java"
