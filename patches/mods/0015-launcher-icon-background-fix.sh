#!/bin/bash
# 桌面图标背景修复

# 目标文件路径
path1="chrome/android/java/res_base/drawable/ic_launcher.xml"

# 检测是否已应用
if grep -q 'Alice patch start 0015' "$path1"; then
    exit 100
fi

sed -i 's|^\( *\)<background android:drawable="@android:color/white"/>$|\1<!-- Alice patch start 0015 -->\n\1<background android:drawable="@mipmap/layered_app_icon_background"/>\n\1<!-- Alice patch end 0015 -->|' "$path1"
