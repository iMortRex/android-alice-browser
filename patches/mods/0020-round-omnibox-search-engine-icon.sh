#!/bin/bash
# 地址栏/搜索框里的搜索引擎图标：2dp 圆角

# 检测是否已应用
if grep -q 'Alice: round-search-engine-icon' "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/status/StatusView.java"; then
    exit 100
fi

# 1) 半径 dimen 改成 6dp。这个 dimen 只有状态栏图标在用（StatusView 的初始值，
#    以及 StatusMediator 的 beginInput/endInput），不影响别处。
sed -i 's|<dimen name="omnibox_search_engine_logo_composed_half_size">12dp</dimen>|<dimen name="omnibox_search_engine_logo_composed_half_size">6dp</dimen>|' \
    "chrome/browser/ui/android/omnibox/java/res/values/dimens.xml"

# 2) beginInput 里原本会按 preview-match-favicons 切成 4dp，这里统一成同一个 2dp dimen
sed -i '/^                OmniboxFeatures.sPreviewMatchFavicons.isEnabled()$/,/^                        : R.dimen.omnibox_search_engine_logo_composed_half_size;$/c\
                R.dimen.omnibox_search_engine_logo_composed_half_size;' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/status/StatusMediator.java"

# 3) StatusView：把已经建好的圆角 provider（半径来自上面的 dimen）装到图标上，
#    否则 outline 一直是矩形、图标一直是方的（上游漏了 setOutlineProvider）。
sed -i 's|^        mIconView.setClipToOutline(true);$|        // Alice: round-search-engine-icon -- 2dp 圆角（启用 outline provider，否则图标是方的）。\n        mIconView.setOutlineProvider(mIconCornerRadiusProvider);\n        mIconView.setClipToOutline(true);|' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/status/StatusView.java"
