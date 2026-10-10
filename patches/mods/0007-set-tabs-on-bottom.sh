#!/bin/bash
# 标签页网格：标签居下（LinearLayoutManager.mStackFromEnd）

set -e

# 检测是否已应用
if grep -q 'mStackFromEnd' "chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"; then
    exit 100
fi

# 反射
sed -i '/mRecyclerView\.setLayoutManager(gridLayoutManager);/i\
                try {\
                    java.lang.reflect.Field stackFromEnd =\
                            androidx.recyclerview.widget.LinearLayoutManager.class\
                                    .getDeclaredField("mStackFromEnd");\
                    stackFromEnd.setAccessible(true);\
                    stackFromEnd.setBoolean(gridLayoutManager, true);\
                    gridLayoutManager.requestLayout();\
                } catch (ReflectiveOperationException e) {\
                    throw new RuntimeException("setStackFromEnd failed", e);\
                }' \
    "chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"

# 添加keep规则
sed -i '$a\
\
# Alice: 反射设置 LinearLayoutManager.mStackFromEnd，保留字段名不被混淆\
-keepclassmembers class androidx.recyclerview.widget.LinearLayoutManager {\
    boolean mStackFromEnd;\
}' \
    "chrome/android/proguard/main.flags"