#!/bin/bash
# 地址栏/搜索框里的搜索引擎图标：2dp 圆角

set -e

# 目标文件路径
path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/status/StatusView.java"
path2="chrome/browser/ui/android/omnibox/java/res/values/dimens.xml"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/status/StatusMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0020' "$path1"; then
    exit 100
fi

# 1) 半径 dimen 改成 6dp（只有状态栏图标在用）
sed -i 's|^\( *\)<dimen name="omnibox_search_engine_logo_composed_half_size">12dp</dimen>$|\1<!-- Alice patch start 0020 -->\n\1<dimen name="omnibox_search_engine_logo_composed_half_size">6dp</dimen>\n\1<!-- Alice patch end 0020 -->|' "$path2"

# 2) beginInput 里统一成同一个 dimen
sed -i '/^                OmniboxFeatures\.sPreviewMatchFavicons\.isEnabled()$/,/^                        : R\.dimen\.omnibox_search_engine_logo_composed_half_size;$/c\
                // Alice patch start 0020\
                R.dimen.omnibox_search_engine_logo_composed_half_size;\
                // Alice patch end 0020' "$path3"

# 3) StatusView：启用 outline provider，否则图标是方的
sed -i 's|^        mIconView\.setClipToOutline(true);$|        // Alice patch start 0020\n        // Alice: round-search-engine-icon -- 2dp 圆角（启用 outline provider，否则图标是方的）。\n        mIconView.setOutlineProvider(mIconCornerRadiusProvider);\n        mIconView.setClipToOutline(true);\n        // Alice patch end 0020|' "$path1"
