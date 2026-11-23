#!/bin/bash
# 标签页网格：通过 StackFromEnd 让竖屏标签从底部开始排列。

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/proguard/main.flags"

# 检测是否已应用
if grep -q 'Alice patch start 0007' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 反射设置 LinearLayoutManager.mStackFromEnd，让网格从底部开始排列。
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

# 保留反射字段名，避免 R8 混淆 mStackFromEnd。
sed -i '$a\
\
# Alice patch start 0007\
# Alice: 反射设置 LinearLayoutManager.mStackFromEnd，保留字段名不被混淆\
-keepclassmembers class androidx.recyclerview.widget.LinearLayoutManager {\
    boolean mStackFromEnd;\
}\
# Alice patch end 0007' "$path2"
