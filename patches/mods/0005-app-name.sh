#!/bin/bash
# 改应用名称

# 检测是否已应用
if grep -q '>Alice Browser<' "chrome/android/java/res_alice_base/values/channel_constants.xml"; then
    exit 100
fi

sed -i 's|<string name="app_name" translatable="false">.*</string>|<string name="app_name" translatable="false">Alice Browser</string>|' \
    chrome/android/java/res_alice_base/values/channel_constants.xml