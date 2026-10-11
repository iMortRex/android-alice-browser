#!/bin/bash
# 新建标签页连点节流（放在唯一入口 ChromeTabCreator.launchNtp）
# 所有界面的 + 最后都会走到 ChromeTabCreator.launchNtp(int)：
#   bottom bar / 标签管理页 / 垂直标签栏 -> TabCreatorUtil.launchNtp -> tabCreator.launchNtp(...)
#   所以在这里节流，不管按钮在哪个界面都生效（600ms 内只放行一次）。

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
        // Alice: debounce repeated taps -- 600ms 内只放行一次（不管点的是哪个界面的 +）\
        {\
            long aliceNow = android.os.SystemClock.uptimeMillis();\
            if (aliceNow - sAliceLastNtpMs < 600) return;\
            sAliceLastNtpMs = aliceNow;\
        }' \
    "chrome/android/java/src/org/chromium/chrome/browser/tabmodel/ChromeTabCreator.java"
