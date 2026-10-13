#!/bin/bash
# 修改默认设置值

set -e

# 目标文件路径
path1="components/password_manager/core/browser/password_manager.cc"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/settings/AddressBarPreference.java"
path3="components/autofill/core/common/autofill_prefs.cc"
path4="chrome/android/java/src/org/chromium/chrome/browser/tab/TabArchiveSettings.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/adaptive/AdaptiveToolbarPrefs.java"
path6="chrome/browser/ui/prefs/prefs_tab_helper.cc"
path7="third_party/search_engines_data/resources/definitions/prepopulated_engines.json"
path8="third_party/search_engines_data/resources/definitions/regional_settings.json"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# --- 密码管理工具：保存密码 / 自动登录 关闭 ---
sed -i 's|^\( *\)prefs::kCredentialsEnableService, true,$|\1// Alice patch start\n\1prefs::kCredentialsEnableService, false,\n\1// Alice patch end|' "$path1"
sed -i 's|^\( *\)prefs::kCredentialsEnableAutosignin, true,$|\1// Alice patch start\n\1prefs::kCredentialsEnableAutosignin, false,\n\1// Alice patch end|' "$path1"

# --- 支付方式 / 地址信息：自动填充关闭 ---
sed -i 's|^\( *\)kAutofillCreditCardEnabled, true,$|\1// Alice patch start\n\1kAutofillCreditCardEnabled, false,\n\1// Alice patch end|' "$path3"
sed -i 's|^\( *\)kAutofillProfileEnabled, true,$|\1// Alice patch start\n\1kAutofillProfileEnabled, false,\n\1// Alice patch end|' "$path3"

# --- 标签页和标签页分组：移植「闲置」部分 - 一律不 ---
sed -i 's|^\( *\)boolean defaultValue = isArchiveDisabledByDefault() ? false : !BuildConfig.IS_FOR_TEST;$|\1// Alice patch start\n\1boolean defaultValue = false;\n\1// Alice patch end|' "$path4"

# --- 外观 - 工具栏中的快捷方式：关闭 ---
sed -i 's|^\( *\)\(\.readBoolean(ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED, true);\)$|\1// Alice patch start\n\1.readBoolean(ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED, false);\n\1// Alice patch end|' "$path5"

# --- 无障碍 - 强制启用缩放功能：打开 ---
# TODO(marker): 这里的目标串 pref_defaults.force_enable_zoom 应用后已被替换掉，
# 需要先 grep kForceEnableZoom 拿到整行原文才能改成整行锚点 + marker。
sed -i '/^  registry->RegisterBooleanPref(prefs::kAccessibilityForceEnableZoom,$/{n;s|^\( *\)pref_defaults\.force_enable_zoom);$|\1// Alice patch start\n\1true);\n\1// Alice patch end|}' "$path6"

# --- 搜索引擎：添加必应并设为默认 ---
sed -i '/^  "elements": {$/a\
// Alice patch start\
    "cnbing": {"name": "必应", "keyword": "cn.bing.com", "favicon_url": "https://cn.bing.com/favicon.ico", "search_url": "https://cn.bing.com/search?q={searchTerms}", "suggest_url": "https://cn.bing.com/osjson.aspx?query={searchTerms}\&language={language}", "type": "SEARCH_ENGINE_BING", "id": 118},\
// Alice patch end' "$path7"

sed -i 's|^\( *\)"kMaxPrepopulatedEngineID": 117,$|\1// Alice patch start\n\1"kMaxPrepopulatedEngineID": 118,\n\1// Alice patch end|' "$path7"

sed -i '/^    "CN": {/,/^    },/ s|^\( *\)"search_engines": \[$|\1// Alice patch start\n\1"search_engines": [\n\1"\&cnbing",\n\1// Alice patch end|' "$path8"

# --- 地址栏默认底部（这里有两条互相牵制的替换，保持原样加 TODO 注释） ---
sed -i '0,/^            ToolbarPositionAndSource\.TOP_SETTINGS;$/{s|^\( *\)ToolbarPositionAndSource\.TOP_SETTINGS;$|\1// Alice patch start\n\1ToolbarPositionAndSource.BOTTOM_SETTINGS;\n\1// Alice patch end|}' "$path2"
sed -i 'N;s|if (isInBottomPosition) return ToolbarPositionAndSource.BOTTOM_SETTINGS;\n        return DEFAULT_POSITION_AND_SOURCE;|if (isInBottomPosition) return ToolbarPositionAndSource.BOTTOM_SETTINGS;\n        return ToolbarPositionAndSource.TOP_SETTINGS;|' "$path2"
