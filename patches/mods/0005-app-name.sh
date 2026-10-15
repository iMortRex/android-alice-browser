#!/bin/bash
# 改应用名称

# 目标文件路径
path1="chrome/android/java/res_alice_base/values/channel_constants.xml"

# 检测是否已应用
if grep -q 'Alice patch start 0005' "$path1"; then
    exit 100
fi

sed -i 's|^\( *\)<string name="app_name" translatable="false">.*</string>$|\1<!-- Alice patch start 0005 -->\n\1<string name="app_name" translatable="false">Alice Browser</string>\n\1<!-- Alice patch end 0005 -->|' "$path1"
