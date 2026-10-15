#!/bin/bash
# 新标签页打开自定义主页（“主页”设置里填了网址时）

set -e

# 目标文件路径
path1="chrome/browser/tabmodel/android/java/src/org/chromium/chrome/browser/tabmodel/TabCreatorUtil.java"
path2="chrome/browser/url_constants/android/java/src/org/chromium/chrome/browser/url_constants/UrlConstantResolverFactory.java"

# 检测是否已应用
if grep -q 'Alice patch start 0024' "$path1"; then
    exit 100
fi

# path1：主页为自定义网址时，新标签页直接打开该网址（无痕等仍沿用原逻辑）
sed -i 's|            tabCreator.launchUrl(urlConstantResolver.getNtpUrl(), type);|            // Alice patch start 0024\n            // Alice: 主页为自定义网址时，新标签页直接打开该网址（无痕等仍沿用原逻辑）。\n            String homepageUrl =\n                    profile.isOffTheRecord()\n                            ? null\n                            : UrlConstantResolverFactory.getHomepageForNewTab();\n            tabCreator.launchUrl(\n                    homepageUrl == null ? urlConstantResolver.getNtpUrl() : homepageUrl, type);\n            // Alice patch end 0024|' "$path1"

# path2：补 import
sed -i '/^import org.chromium.base.ResettersForTesting;$/a\
// Alice patch start 0024\
import org.chromium.base.shared_preferences.SharedPreferencesManager;\
// Alice patch end 0024' "$path2"

sed -i '/^import org.chromium.chrome.browser.profiles.Profile;$/i\
// Alice patch start 0024\
import org.chromium.chrome.browser.preferences.ChromePreferenceKeys;\
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;\
// Alice patch end 0024' "$path2"

sed -i '/^import org.chromium.chrome.browser.profiles.Profile;$/a\
// Alice patch start 0024\
import org.chromium.components.embedder_support.util.UrlUtilities;\
import org.chromium.url.GURL;\
// Alice patch end 0024' "$path2"

# path2：NTP override 未启用时回落到自定义主页
sed -i 's|^                        return null;$|                        // Alice patch start 0024\n                        return getHomepageForNewTab();\n                        // Alice patch end 0024|' "$path2"

# path2：新增 getHomepageForNewTab()
sed -i '/^    public static void setForTesting(UrlConstantResolver resolver) {$/i\
    // Alice patch start 0024\
    /**\
     * Alice: Returns the URL a new tab should open when the user set a custom homepage.\
     *\
     * <p>Mirrors the "Homepage" setting: when a custom URL (neither Chrome'"'"'s NTP nor the default\
     * homepage) is selected, new tabs open that URL instead of the New Tab Page.\
     *\
     * @return The custom homepage URL, or {@code null} if the New Tab Page should be used.\
     */\
    public static @Nullable String getHomepageForNewTab() {\
        SharedPreferencesManager prefs = ChromeSharedPreferences.getInstance();\
        // The "Homepage" switch; a missing value means enabled, matching the non-desktop default.\
        if (!prefs.readBoolean(ChromePreferenceKeys.HOMEPAGE_ENABLED, true)) return null;\
        if (prefs.readBoolean(ChromePreferenceKeys.HOMEPAGE_USE_CHROME_NTP, false)) return null;\
        if (prefs.readBoolean(ChromePreferenceKeys.HOMEPAGE_USE_DEFAULT_URI, true)) return null;\
\
        String serializedHomepage =\
                prefs.readString(ChromePreferenceKeys.HOMEPAGE_CUSTOM_GURL, "");\
        if (serializedHomepage.isEmpty()) return null;\
\
        GURL customHomepage = GURL.deserialize(serializedHomepage);\
        if (!customHomepage.isValid() || customHomepage.isEmpty()) return null;\
\
        return UrlUtilities.isNtpUrl(customHomepage) ? null : customHomepage.getSpec();\
    }\
    // Alice patch end 0024\
' "$path2"