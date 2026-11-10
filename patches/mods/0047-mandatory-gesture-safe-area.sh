#!/bin/bash
# 全屏时底部安全区至少包含 mandatorySystemGestures 手势热区。

set -e

path1="ui/android/java/src/org/chromium/ui/insets/InsetObserver.java"

# 检测是否已应用
if grep -q 'Alice patch start 0047' "$path1"; then
    exit 100
fi

# 将手势热区纳入 bottom safe-area，避免可见但不可点击的底部窄条。
sed -i 's|^        newSafeArea.bottom += mBottomInsetsForEdgeToEdge;$|        // Alice patch start 0047\
        int aliceMandatoryGestureBottom = 0;\
        if (getLastRawWindowInsets() != null) {\
            aliceMandatoryGestureBottom =\
                    getLastRawWindowInsets()\
                            .getInsets(mandatorySystemGestures())\
                            .bottom;\
        }\
        newSafeArea.bottom +=\
                Math.max(mBottomInsetsForEdgeToEdge, aliceMandatoryGestureBottom);\
        // Alice patch end 0047|' "$path1"
