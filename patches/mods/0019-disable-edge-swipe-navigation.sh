#!/bin/bash
# 禁用边缘左右滑动前进/后退

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/SwipeRefreshHandler.java"

# 检测是否已应用
if grep -q 'Alice patch start 0019' "$path1"; then
    exit 100
fi

# 边缘左右滑动 = overscroll 的 HISTORY_NAVIGATION。
# SwipeRefreshHandler.start() 返回 false 时，native 会执行默认的前进/后退；
# 返回 true 表示"这个 overscroll 序列由我消费"。这里直接消费掉并且什么都不做，
# 于是边缘滑动不再前进/后退（也不再有滑动动画）。
sed -i '/^        } else if (type == OverscrollAction.HISTORY_NAVIGATION) {$/,/^        } else if (type == OverscrollAction.PULL_FROM_BOTTOM_EDGE) {$/c\
        } else if (type == OverscrollAction.HISTORY_NAVIGATION) {\
            // Alice patch start 0019\
            // Alice: disable-swipe-nav -- 禁用边缘左右滑动前进/后退：消费掉这个 overscroll，\
            // 不做任何导航（返回 true = 已消费，native 不会再执行默认的前进/后退）。\
            mSwipeType = OverscrollAction.NONE;\
            return true;\
            // Alice patch end 0019\
        } else if (type == OverscrollAction.PULL_FROM_BOTTOM_EDGE) {' "$path1"
