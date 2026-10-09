#!/bin/bash
# 修改默认设置值

# 检测是否已应用
if grep -q 'prefs::kCredentialsEnableService, false,' "components/password_manager/core/browser/password_manager.cc"; then
    exit 100
fi

# 地址栏默认底部
sed -i 's|            ToolbarPositionAndSource.TOP_SETTINGS;|            ToolbarPositionAndSource.BOTTOM_SETTINGS;|' \
    chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/settings/AddressBarPreference.java

sed -i 'N;s|if (isInBottomPosition) return ToolbarPositionAndSource.BOTTOM_SETTINGS;\n        return DEFAULT_POSITION_AND_SOURCE;|if (isInBottomPosition) return ToolbarPositionAndSource.BOTTOM_SETTINGS;\n        return ToolbarPositionAndSource.TOP_SETTINGS;|' \
    chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/settings/AddressBarPreference.java

# 密码管理工具
# 保存密码 - 关闭
sed -i 's|prefs::kCredentialsEnableService, true,|prefs::kCredentialsEnableService, false,|' \
    components/password_manager/core/browser/password_manager.cc
# 自动登录 - 关闭
sed -i 's|prefs::kCredentialsEnableAutosignin, true,|prefs::kCredentialsEnableAutosignin, false,|' \
    components/password_manager/core/browser/password_manager.cc

# 支付方式
# 保存并自动填充支付方式 - 关闭
sed -i 's|kAutofillCreditCardEnabled, true,|kAutofillCreditCardEnabled, false,|' \
    components/autofill/core/common/autofill_prefs.cc

# 地址和其他信息
# 保存并自动填充地址 - 关闭
# 自动确认您的邮箱 - 关闭
sed -i 's|kAutofillProfileEnabled, true,|kAutofillProfileEnabled, false,|' \
    components/autofill/core/common/autofill_prefs.cc

# 标签页和标签页分组
# 移植“闲置”部分 - 一律不
sed -i 's|boolean defaultValue = isArchiveDisabledByDefault() ? false : !BuildConfig.IS_FOR_TEST;|boolean defaultValue = false;|' \
    chrome/android/java/src/org/chromium/chrome/browser/tab/TabArchiveSettings.java

# 外观
# 工具栏中的快捷方式
# 工具栏中的快捷方式 - 关闭
sed -i 's|ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED, true|ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED, false|' \
    chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/adaptive/AdaptiveToolbarPrefs.java

# 无障碍
# 强制启用缩放功能 - 打开
sed -i 's|pref_defaults.force_enable_zoom);|true);|' \
    chrome/browser/ui/prefs/prefs_tab_helper.cc

# 搜索引擎
# 添加必应，默认必应
sed -i '/^  "elements": {$/a\    "cnbing": {"name": "必应", "keyword": "cn.bing.com", "favicon_url": "https://cn.bing.com/favicon.ico", "search_url": "https://cn.bing.com/search?q={searchTerms}", "suggest_url": "https://cn.bing.com/osjson.aspx?query={searchTerms}&language={language}", "type": "SEARCH_ENGINE_BING", "id": 118},' \
    third_party/search_engines_data/resources/definitions/prepopulated_engines.json
sed -i 's|"kMaxPrepopulatedEngineID": 117,|"kMaxPrepopulatedEngineID": 118,|' \
    third_party/search_engines_data/resources/definitions/prepopulated_engines.json
sed -i '/^    "CN": {/,/^    },/ s|"search_engines": \[|&\n        "\&cnbing",|' \
    third_party/search_engines_data/resources/definitions/regional_settings.json
