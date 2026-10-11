#!/bin/bash
# 桌面图标背景修复

# 检测是否已应用
if grep -q 'layered_app_icon_background' "chrome/android/java/res_base/drawable/ic_launcher.xml"; then
    exit 100
fi

sed -i 's|<background android:drawable="@android:color/white"/>|<background android:drawable="@mipmap/layered_app_icon_background"/>|' \
    "chrome/android/java/res_base/drawable/ic_launcher.xml"
