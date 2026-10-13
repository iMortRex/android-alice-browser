#!/bin/bash
# 消息气泡（翻译 bubble）居下

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"
path2="chrome/android/java/res_app/layout/main.xml"
path3="chrome/android/java/res_app/layout/main_forked_with_secondary_ui_container.xml"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# 1) 去掉 23dp 的 message_bubble_inset 修正
sed -i 's|^\( *\)final Resources res = mContainer\.getResources();$|\1// Alice patch start\n\1// Alice patch end|' "$path1"
sed -i 's|^\( *\)return contentOffset - res\.getDimensionPixelOffset(R\.dimen\.message_bubble_inset);$|\1// Alice patch start\n\1return contentOffset;\n\1// Alice patch end|' "$path1"

# 2) 气泡停在底部，底部留出工具栏高度（56dp = R.dimen.toolbar_height_no_shadow）
sed -i 's|^\( *\)params\.topMargin = getContainerTopOffset();$|\1// Alice patch start\n\1final Resources res = mContainer.getResources();\n\1params.topMargin = getContainerTopOffset();\n\1params.bottomMargin =\n\1        Math.max(\n\1                getContainerTopOffset(),\n\1                res.getDimensionPixelOffset(R.dimen.toolbar_height_no_shadow));\n\1// Alice patch end|' "$path1"

# 3) 布局里气泡的重力从顶部改成底部（MessageContainer 整个元素用 XML 注释包起来，注释在标签外）
sed -i '/^        <org\.chromium\.components\.messages\.MessageContainer$/i\
        <!-- Alice patch start -->' "$path2"
sed -i '/^        <org\.chromium\.components\.messages\.MessageContainer$/,/^\( *\).*>$/ s|^\( *\)\(.*>\)$|\1\2\n\1<!-- Alice patch end -->|' "$path2"
sed -i '/^            <org\.chromium\.components\.messages\.MessageContainer$/i\
            <!-- Alice patch start -->' "$path3"
sed -i '/^            <org\.chromium\.components\.messages\.MessageContainer$/,/^\( *\).*>$/ s|^\( *\)\(.*>\)$|\1\2\n\1<!-- Alice patch end -->|' "$path3"
sed -i 's#^\( *\)android:layout_gravity="start|top"$#\1android:layout_gravity="start|bottom"#' "$path2" "$path3"
