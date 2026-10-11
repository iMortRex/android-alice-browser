// Copyright 2025 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.url_constants;

import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalBookmarksUrl;
import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalHistoryUrl;
import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalNativeBookmarksUrl;
import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalNativeHistoryUrl;
import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalNativeNtpUrl;
import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalNtpUrl;
import static org.chromium.chrome.browser.url_constants.UrlConstantResolver.getOriginalWebUiNtpUrl;
import static org.chromium.chrome.browser.url_constants.UrlOverrideUtils.isBookmarksPageOverrideEnabled;
import static org.chromium.chrome.browser.url_constants.UrlOverrideUtils.isHistoryPageOverrideEnabled;
import static org.chromium.chrome.browser.url_constants.UrlOverrideUtils.isIncognitoBookmarksPageOverrideEnabled;
import static org.chromium.chrome.browser.url_constants.UrlOverrideUtils.isIncognitoNtpOverrideEnabled;
import static org.chromium.chrome.browser.url_constants.UrlOverrideUtils.isNtpOverrideEnabled;
import static org.chromium.chrome.browser.url_constants.UrlOverrideUtils.isWebUiNtpOverrideEnabled;

import androidx.annotation.VisibleForTesting;

import org.chromium.base.ResettersForTesting;
import org.chromium.base.shared_preferences.SharedPreferencesManager;
import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.chrome.browser.preferences.ChromePreferenceKeys;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;
import org.chromium.chrome.browser.profiles.Profile;
import org.chromium.components.embedder_support.util.UrlUtilities;
import org.chromium.url.GURL;

/**
 * Factory class that creates, configures, and caches {@link UrlConstantResolver} instances for
 * standard (non-incognito) and incognito profiles.
 *
 * <p>This factory initializes each resolver with profile-specific overrides (such as bookmarks,
 * NTP, and history overrides).
 */
@NullMarked
public class UrlConstantResolverFactory {
    private static @Nullable UrlConstantResolver sOriginalResolver;
    private static @Nullable UrlConstantResolver sIncognitoResolver;
    private static @Nullable UrlConstantResolver sResolverForTesting;

    // Prevent instantiation.
    private UrlConstantResolverFactory() {}

    public static UrlConstantResolver getForProfile(@Nullable Profile profile) {
        if (sResolverForTesting != null) {
            return sResolverForTesting;
        }

        if (profile == null || !profile.isOffTheRecord()) {
            return getOriginalResolver();
        }

        return getIncognitoResolver();
    }

    /** Returns the resolver associated with the primary profile. */
    public static UrlConstantResolver getOriginalResolver() {
        if (sOriginalResolver == null) {
            sOriginalResolver = buildOriginalResolver();
        }
        return sOriginalResolver;
    }

    /** Returns the resolver associated with the incognito profile. */
    public static UrlConstantResolver getIncognitoResolver() {
        if (sIncognitoResolver == null) {
            sIncognitoResolver = buildIncognitoResolver();
        }
        return sIncognitoResolver;
    }

    private static UrlConstantResolver buildOriginalResolver() {
        UrlConstantResolver resolver = new UrlConstantResolver();
        resolver.registerOverride(
                getOriginalNativeNtpUrl(),
                () -> {
                    // Returns 'chrome://newtab' even when WebUI NTP is enabled in order to respect
                    // extensions/NTP location overrides.
                    if (isNtpOverrideEnabled()) {
                        return getOriginalNtpUrl();
                    } else if (isWebUiNtpOverrideEnabled()) {
                        return getOriginalWebUiNtpUrl();
                    } else {
                        return getHomepageForNewTab();
                    }
                });
        resolver.registerOverride(
                getOriginalNativeBookmarksUrl(),
                () -> isBookmarksPageOverrideEnabled() ? getOriginalBookmarksUrl() : null);
        resolver.registerOverride(
                getOriginalNativeHistoryUrl(),
                () -> isHistoryPageOverrideEnabled() ? getOriginalHistoryUrl() : null);
        return resolver;
    }

    private static UrlConstantResolver buildIncognitoResolver() {
        UrlConstantResolver resolver = new UrlConstantResolver();
        resolver.registerOverride(
                getOriginalNativeNtpUrl(),
                () -> isIncognitoNtpOverrideEnabled() ? getOriginalNtpUrl() : null);
        resolver.registerOverride(
                getOriginalNativeBookmarksUrl(),
                () -> isIncognitoBookmarksPageOverrideEnabled() ? getOriginalBookmarksUrl() : null);
        return resolver;
    }

    /**
     * Alice: Returns the URL a new tab should open when the user set a custom homepage.
     *
     * <p>Mirrors the "Homepage" setting: when a custom URL (neither Chrome's NTP nor the default
     * homepage) is selected, new tabs open that URL instead of the New Tab Page.
     *
     * @return The custom homepage URL, or {@code null} if the New Tab Page should be used.
     */
    public static @Nullable String getHomepageForNewTab() {
        SharedPreferencesManager prefs = ChromeSharedPreferences.getInstance();
        // The "Homepage" switch; a missing value means enabled, matching the non-desktop default.
        if (!prefs.readBoolean(ChromePreferenceKeys.HOMEPAGE_ENABLED, true)) return null;
        if (prefs.readBoolean(ChromePreferenceKeys.HOMEPAGE_USE_CHROME_NTP, false)) return null;
        if (prefs.readBoolean(ChromePreferenceKeys.HOMEPAGE_USE_DEFAULT_URI, true)) return null;

        String serializedHomepage =
                prefs.readString(ChromePreferenceKeys.HOMEPAGE_CUSTOM_GURL, "");
        if (serializedHomepage.isEmpty()) return null;

        GURL customHomepage = GURL.deserialize(serializedHomepage);
        if (!customHomepage.isValid() || customHomepage.isEmpty()) return null;

        return UrlUtilities.isNtpUrl(customHomepage) ? null : customHomepage.getSpec();
    }

    public static void setForTesting(UrlConstantResolver resolver) {
        sResolverForTesting = resolver;
        ResettersForTesting.register(() -> sResolverForTesting = null);
    }

    @VisibleForTesting
    public static void resetResolvers() {
        sOriginalResolver = null;
        sIncognitoResolver = null;
    }
}
