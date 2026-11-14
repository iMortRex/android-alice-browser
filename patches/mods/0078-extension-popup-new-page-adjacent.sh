#!/bin/bash
# 扩展 popup 打开的选项页：在预览背后的当前标签页之后打开。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/browser_navigator_android.cc"

# 检测是否已应用
if grep -q 'Alice patch start 0078' "$path1"; then
    exit 100
fi

# 扩展 URL 未指定位置时，插到当前活动标签页的下一位。
sed -i '\|^  TabModel::TabLaunchType launch_type = GetTabLaunchType(params);$|i\
  // Alice patch start 0078\
  if (params->tabstrip_index == -1 \&\&\
      params->url.SchemeIs("chrome-extension")) {\
    params->tabstrip_index = tab_model->GetActiveIndex() + 1;\
    params->tabstrip_add_types |= AddTabTypes::ADD_FORCE_INDEX;\
  }\
  // Alice patch end 0078\
\
' "$path1"
