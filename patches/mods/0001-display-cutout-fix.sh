#!/bin/bash
# Display Cutout 模式固定为 1

# 目标文件路径
path1="components/browser_ui/display_cutout/android/java/src/org/chromium/components/browser_ui/display_cutout/DisplayCutoutController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0001' "$path1"; then
    exit 100
fi

# 比较与设置都写死 1，不跟随系统 displayCutoutMode
sed -i 's|^\( *\)if (attributes.layoutInDisplayCutoutMode == displayCutoutMode) return;$|\1// Alice patch start 0001\n\1if (attributes.layoutInDisplayCutoutMode == 1) return;\n\1// Alice patch end 0001|' "$path1"

sed -i 's|^\( *\)attributes.layoutInDisplayCutoutMode = displayCutoutMode;$|\1// Alice patch start 0001\n\1attributes.layoutInDisplayCutoutMode = 1;\n\1// Alice patch end 0001|' "$path1"
