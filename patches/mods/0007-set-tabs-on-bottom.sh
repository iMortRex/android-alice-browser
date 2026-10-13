#!/bin/bash
# 标签页网格：标签居下（LinearLayoutManager.mStackFromEnd）

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/proguard/main.flags"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# 反射设置 mStackFromEnd
sed -i '/^                mRecyclerView\.setLayoutManager(gridLayoutManager);$/i\
                // Alice patch start\
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
                // Alice patch end' "$path1"

# 添加 keep 规则
sed -i '$a\
\
# Alice patch start\
# Alice: 反射设置 LinearLayoutManager.mStackFromEnd，保留字段名不被混淆\
-keepclassmembers class androidx.recyclerview.widget.LinearLayoutManager {\
    boolean mStackFromEnd;\
}\
# Alice patch end' "$path2"
