#!/bin/bash
# 标签页网格：标签居下（LinearLayoutManager.mStackFromEnd）

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/proguard/main.flags"
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListRecyclerView.java"

# 检测是否已应用
if grep -q 'Alice patch start 0007' "$path1"; then
    exit 100
fi

# 反射设置 mStackFromEnd
sed -i '/^                mRecyclerView\.setLayoutManager(gridLayoutManager);$/i\
                // Alice patch start 0007\
                try {\
                    java.lang.reflect.Field stackFromEnd =\
                            androidx.recyclerview.widget.LinearLayoutManager.class\
                                    .getDeclaredField("mStackFromEnd");\
                    stackFromEnd.setAccessible(true);\
                    stackFromEnd.setBoolean(gridLayoutManager, true);\
                    gridLayoutManager.requestLayout();\
                } catch (ReflectiveOperationException e) {\
                    throw new RuntimeException("setStackFromEnd failed", e);\
                }\
                // Alice patch end 0007' "$path1"

# 添加 keep 规则
sed -i '$a\
\
# Alice patch start 0007\
# Alice: 反射设置 LinearLayoutManager.mStackFromEnd，保留字段名不被混淆\
-keepclassmembers class androidx.recyclerview.widget.LinearLayoutManager {\
    boolean mStackFromEnd;\
}\
# Alice patch end 0007' "$path2"

# 冷启动首次布局时，第二排且下方仍有标签的卡片可能暂时停在底部锚定位置。
# 动画会在这轮布局中读取缩略图矩形，因此只修正该 RecyclerView 的第一次
# 动画目标；之后不再按位置判断，避免用户滚动后的第二排卡片被重复修正。
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListRecyclerView.java"
sed -i '/^    private boolean mBlockTouchInput;$/a\
    // Alice patch start 0007\
    private boolean mAliceInitialTabAnimationRectRead;\
    // Alice patch end 0007' "$path3"

sed -i '/^        if (v != null) v\.getGlobalVisibleRect(rect);$/a\
        // Alice patch start 0007\
        boolean aliceInitialTabAnimationRect = !mAliceInitialTabAnimationRectRead;\
        mAliceInitialTabAnimationRectRead = true;\
        if (getLayoutManager() instanceof GridLayoutManager) {\
            GridLayoutManager aliceLayoutManager = (GridLayoutManager) getLayoutManager();\
            int aliceSpanCount = aliceLayoutManager.getSpanCount();\
            boolean aliceSecondRow =\
                    tabIndex >= aliceSpanCount\
                            \&\& tabIndex < aliceSpanCount * 2\
                            \&\& tabIndex + aliceSpanCount < aliceLayoutManager.getItemCount();\
            int aliceCenteredTop = (getHeight() - holder.itemView.getHeight()) / 2;\
            int aliceSearchGap =\
                    getResources().getDimensionPixelSize(R.dimen.hub_search_box_gap);\
            if (aliceInitialTabAnimationRect\
                    \&\& aliceSecondRow\
                    \&\& holder.itemView.getTop() > aliceCenteredTop + aliceSearchGap / 2) {\
                rect.offset(0, -aliceSearchGap);\
            }\
        }\
        // Alice patch end 0007' "$path3"
