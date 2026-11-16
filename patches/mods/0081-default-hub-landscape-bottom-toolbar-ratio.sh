#!/bin/bash
# 默认 Hub：横屏且地址栏位于底部时，卡片比例使用底部控制栏高度。

set -e

path1="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabCardThemeUtil.java"

if grep -q 'Alice patch start 0081' "$path1"; then
    exit 100
fi

sed -i '/^            int browserControlsHeightDp =$/,/^                                            \/ context\.getResources()\.getDisplayMetrics()\.density);$/c\
            // Alice patch start 0081\
            int browserControlsHeightPx = 0;\
            if (browserControlsStateProvider != null) {\
                browserControlsHeightPx =\
                        browserControlsStateProvider.getControlsPosition()\
                                        == BrowserControlsStateProvider.ControlsPosition.BOTTOM\
                                ? browserControlsStateProvider.getBottomControlsHeight()\
                                : browserControlsStateProvider.getTopControlsHeight();\
            }\
            int browserControlsHeightDp =\
                    Math.round(\
                            (float) browserControlsHeightPx\
                                    / context.getResources().getDisplayMetrics().density);\
            // Alice patch end 0081' "$path1"
