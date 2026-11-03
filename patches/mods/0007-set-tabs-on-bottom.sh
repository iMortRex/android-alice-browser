#!/bin/bash
# 标签页网格：竖屏标签居下，横屏从顶部正常排列

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/proguard/main.flags"
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListContainerViewBinder.java"

# 检测是否已应用
if grep -q 'Alice patch start 0007' "$path1"; then
    exit 100
fi

# 恢复原有的列表末尾锚定方式，避免改变横竖屏布局初始化路径。
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

# 反射读取 mStackFromEnd，保留字段名不被混淆。
sed -i '$a\
\
# Alice patch start 0007\
# Alice: 反射设置 LinearLayoutManager.mStackFromEnd，保留字段名不被混淆\
-keepclassmembers class androidx.recyclerview.widget.LinearLayoutManager {\
    boolean mStackFromEnd;\
}\
# Alice patch end 0007' "$path2"

# 首次打开时 RecyclerView 尚未布局，不能用窗口尺寸兜底计算初始滚动位置。
# 等真实尺寸可用后再滚动；动画几何最多额外等待这次滚动引起的一轮布局。
sed -i '/^        } else if (INITIAL_SCROLL_INDEX == propertyKey) {$/,/^        } else if (FOCUS_TAB_INDEX_FOR_ACCESSIBILITY == propertyKey) {$/c\
        } else if (INITIAL_SCROLL_INDEX == propertyKey) {\
            int index = model.get(INITIAL_SCROLL_INDEX);\
            // Alice patch start 0007\
            LinearLayoutManager layoutManager =\
                    assumeNonNull((LinearLayoutManager) recyclerView.getLayoutManager());\
            if (recyclerView.isLaidOut()\
                    \&\& recyclerView.getWidth() > 0\
                    \&\& recyclerView.getHeight() > 0) {\
                layoutManager.scrollToPositionWithOffset(\
                        index, computeOffset(recyclerView, model));\
            } else {\
                recyclerView.addOnLayoutChangeListener(\
                        new View.OnLayoutChangeListener() {\
                            @Override\
                            public void onLayoutChange(\
                                    View v,\
                                    int left,\
                                    int top,\
                                    int right,\
                                    int bottom,\
                                    int oldLeft,\
                                    int oldTop,\
                                    int oldRight,\
                                    int oldBottom) {\
                                if (recyclerView.getWidth() <= 0\
                                        || recyclerView.getHeight() <= 0) {\
                                    return;\
                                }\
                                recyclerView.removeOnLayoutChangeListener(this);\
                                assumeNonNull(\
                                                (LinearLayoutManager)\
                                                        recyclerView.getLayoutManager())\
                                        .scrollToPositionWithOffset(\
                                                index, computeOffset(recyclerView, model));\
                            }\
                        });\
                recyclerView.requestLayout();\
            }\
            // Alice patch end 0007\
        } else if (FOCUS_TAB_INDEX_FOR_ACCESSIBILITY == propertyKey) {' "$path3"

sed -i '/^    private @Nullable Runnable mAwaitingLayoutRunnable;$/a\
    // Alice patch start 0007\
    private boolean mAwaitingLayoutDeferredForScroll;\
    // Alice patch end 0007' "$path1"

sed -i '/^        mAwaitingLayoutRunnable = r;$/a\
        // Alice patch start 0007\
        mAwaitingLayoutDeferredForScroll = false;\
        // Alice patch end 0007' "$path1"

sed -i 's|^        mRecyclerView\.runOnNextLayout(this::checkAwaitingLayout);$|        // Alice patch start 0007\n        mRecyclerView.runOnNextLayout(\n                () -> mRecyclerView.post(this::checkAwaitingLayout));\n        // Alice patch end 0007|' "$path1"

sed -i '/^    private void checkAwaitingLayout() {$/,/^        if (mAwaitingLayoutRunnable != null) {$/ s#^        if (mAwaitingLayoutRunnable != null) {$#        if (mAwaitingLayoutRunnable != null) {\
            // Alice patch start 0007\
            if (!mRecyclerView.isLaidOut()) {\
                mRecyclerView.runOnNextLayout(\
                        () -> mRecyclerView.post(this::checkAwaitingLayout));\
                return;\
            }\
            if (mRecyclerView.isLayoutRequested() \&\& !mAwaitingLayoutDeferredForScroll) {\
                mAwaitingLayoutDeferredForScroll = true;\
                mRecyclerView.runOnNextLayout(\
                        () -> mRecyclerView.post(this::checkAwaitingLayout));\
                return;\
            }\
            // Alice patch end 0007#' "$path1"
