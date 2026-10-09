#!/bin/bash
# 改应用名称

# 检测是否以应用
if grep -q '>Alice Browser<' "chrome/android/java/res_alice_base/values/channel_constants.xml"; then
    echo "已应用，跳过: $(basename "$0")"
    exit 0
fi

sed -i 's|<string name="app_name" translatable="false">.*</string>|<string name="app_name" translatable="false">Alice Browser</string>|' \
    chrome/android/java/res_alice_base/values/channel_constants.xml