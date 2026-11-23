#!/bin/bash
# 设置-标签页和标签页分组：新增「标签切换器」入口（点击进入子页选择样式），并在入口下方显示当前选项。
#   0 上游标签网格 / 1 竖向（暂未支持，置灰） / 2 横向（类 iOS 横向堆叠卡片，由 0036 实现）
#   3 横向（不重排标签）；未保存设置时默认使用 3
# 取值保存在 ChromeSharedPreferences: alice_tab_switcher_style

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/res/xml/tabs_settings.xml"
path2="alice/chromium_src/chrome/android/chrome_java_ext_sources.gni"
path3="alice/chromium_src/chrome/android/chrome_app_java_resources_ext_sources.gni"
path4="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabsSettings.java"

# 检测是否已应用
if grep -q 'Alice patch start 0035' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# ---------- 新增文件 ----------
mkdir -p "alice/chromium_src/chrome/android/java/res/xml"
cat > "alice/chromium_src/chrome/android/java/res/xml/alice_tab_switcher_style_preferences.xml" << 'ALICE_EOF'
<?xml version="1.0" encoding="utf-8"?>
<!-- Alice: 标签切换器样式设置页 -->
<PreferenceScreen
    xmlns:android="http://schemas.android.com/apk/res/android">

    <org.chromium.chrome.browser.appearance.settings.AliceTabSwitcherStylePreference
        android:key="alice_tab_switcher_style"
        android:order="0"
        android:persistent="false"
        android:title="@string/alice_tab_switcher_style_title" />

</PreferenceScreen>
ALICE_EOF

mkdir -p "alice/chromium_src/chrome/android/java/res/layout"
cat > "alice/chromium_src/chrome/android/java/res/layout/alice_tab_switcher_style_preference.xml" << 'ALICE_EOF'
<?xml version="1.0" encoding="utf-8"?>
<!-- Alice: 标签切换器样式的单选组 -->
<LinearLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical">

    <org.chromium.components.browser_ui.widget.RadioButtonWithDescriptionLayout
        android:id="@+id/alice_style_group"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:focusable="false">

        <org.chromium.components.browser_ui.widget.RadioButtonWithDescription
            android:id="@+id/alice_style_default"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:minHeight="@dimen/min_touch_target_size"
            android:paddingTop="@dimen/settings_item_default_padding"
            android:paddingBottom="@dimen/settings_item_default_padding"
            app:primaryText="@string/alice_tab_switcher_style_default" />

        <org.chromium.components.browser_ui.widget.RadioButtonWithDescription
            android:id="@+id/alice_style_vertical"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:minHeight="@dimen/min_touch_target_size"
            android:paddingTop="@dimen/settings_item_default_padding"
            android:paddingBottom="@dimen/settings_item_default_padding"
            app:primaryText="@string/alice_tab_switcher_style_vertical" />

        <org.chromium.components.browser_ui.widget.RadioButtonWithDescription
            android:id="@+id/alice_style_horizontal"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:minHeight="@dimen/min_touch_target_size"
            android:paddingTop="@dimen/settings_item_default_padding"
            android:paddingBottom="@dimen/settings_item_default_padding"
            app:primaryText="@string/alice_tab_switcher_style_horizontal" />

        <org.chromium.components.browser_ui.widget.RadioButtonWithDescription
            android:id="@+id/alice_style_horizontal_no_reorder"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:minHeight="@dimen/min_touch_target_size"
            android:paddingTop="@dimen/settings_item_default_padding"
            android:paddingBottom="@dimen/settings_item_default_padding"
            app:primaryText="@string/alice_tab_switcher_style_horizontal_no_reorder" />

    </org.chromium.components.browser_ui.widget.RadioButtonWithDescriptionLayout>

</LinearLayout>
ALICE_EOF

mkdir -p "alice/chromium_src/chrome/android/java/res/values"
cat > "alice/chromium_src/chrome/android/java/res/values/alice_tab_switcher_strings.xml" << 'ALICE_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="alice_tab_switcher_title">Tab switcher</string>
    <string name="alice_tab_switcher_style_title">Tab switcher style</string>
    <string name="alice_tab_switcher_style_default">Default (browser tab grid)</string>
    <string name="alice_tab_switcher_style_vertical">Vertical (not supported yet)</string>
    <string name="alice_tab_switcher_style_horizontal">Horizontal (stacked cards)</string>
    <string name="alice_tab_switcher_style_horizontal_no_reorder">Horizontal without tab reordering</string>
    <string name="alice_tab_switcher_style_default_summary">Default</string>
    <string name="alice_tab_switcher_style_vertical_summary">Vertical (not supported yet)</string>
    <string name="alice_tab_switcher_style_horizontal_summary">Horizontal</string>
    <string name="alice_tab_switcher_style_horizontal_no_reorder_summary">Horizontal (no reordering)</string>
</resources>
ALICE_EOF

mkdir -p "alice/chromium_src/chrome/android/java/res/values-zh"
cat > "alice/chromium_src/chrome/android/java/res/values-zh/alice_tab_switcher_strings.xml" << 'ALICE_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="alice_tab_switcher_title">标签切换器</string>
    <string name="alice_tab_switcher_style_title">标签切换器样式</string>
    <string name="alice_tab_switcher_style_default">默认（浏览器自带的标签网格）</string>
    <string name="alice_tab_switcher_style_vertical">竖向（暂未支持）</string>
    <string name="alice_tab_switcher_style_horizontal">横向（横向堆叠卡片）</string>
    <string name="alice_tab_switcher_style_horizontal_no_reorder">横向（不重排标签）</string>
    <string name="alice_tab_switcher_style_default_summary">默认</string>
    <string name="alice_tab_switcher_style_vertical_summary">竖向（暂未支持）</string>
    <string name="alice_tab_switcher_style_horizontal_summary">横向</string>
    <string name="alice_tab_switcher_style_horizontal_no_reorder_summary">横向（不重排）</string>
</resources>
ALICE_EOF

mkdir -p "alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/appearance/settings"
cat > "alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AliceTabSwitcherStylePreference.java" << 'ALICE_EOF'
// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.appearance.settings;

import android.content.Context;
import android.content.res.Resources;
import android.util.AttributeSet;
import android.widget.RadioGroup;

import androidx.annotation.StringRes;
import androidx.preference.PreferenceViewHolder;

import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.chrome.R;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;
import org.chromium.components.browser_ui.settings.ContainedRadioButtonGroupPreference;
import org.chromium.components.browser_ui.widget.RadioButtonWithDescription;
import org.chromium.components.browser_ui.widget.RadioButtonWithDescriptionLayout;

/**
 * Alice: 标签切换器样式的单选组（默认 / 竖向 / 横向 / 横向不重排）。
 *
 * <p>竖向暂未支持：按钮置灰不可选。
 */
@NullMarked
public class AliceTabSwitcherStylePreference extends ContainedRadioButtonGroupPreference
        implements RadioGroup.OnCheckedChangeListener {

    /** SharedPreferences key（与 tab_ui 侧读取的 key 一致）。 */
    public static final String PREF_TAB_SWITCHER_STYLE = "alice_tab_switcher_style";

    /** 默认样式（上游标签网格）。 */
    public static final int STYLE_DEFAULT = 0;

    /** 竖向堆叠（暂未支持）。 */
    public static final int STYLE_VERTICAL = 1;

    /** 横向堆叠。 */
    public static final int STYLE_HORIZONTAL = 2;

    /** 横向堆叠，但不重排标签顺序。 */
    public static final int STYLE_HORIZONTAL_NO_REORDER = 3;

    /** 未保存设置时使用的默认样式：横向（不重排标签）。 */
    public static final int STYLE_APP_DEFAULT = STYLE_HORIZONTAL_NO_REORDER;

    private int mStyle = STYLE_APP_DEFAULT;
    private @Nullable RadioButtonWithDescriptionLayout mGroup;
    private @Nullable RadioButtonWithDescription mDefaultButton;
    private @Nullable RadioButtonWithDescription mVerticalButton;
    private @Nullable RadioButtonWithDescription mHorizontalButton;
    private @Nullable RadioButtonWithDescription mHorizontalNoReorderButton;

    public AliceTabSwitcherStylePreference(Context context, AttributeSet attrs) {
        super(context, attrs);
        setLayoutResource(R.layout.alice_tab_switcher_style_preference);
    }

    @Override
    public void onBindViewHolder(PreferenceViewHolder holder) {
        super.onBindViewHolder(holder);
        mGroup = (RadioButtonWithDescriptionLayout) holder.findViewById(R.id.alice_style_group);
        mDefaultButton =
                (RadioButtonWithDescription) holder.findViewById(R.id.alice_style_default);
        mVerticalButton =
                (RadioButtonWithDescription) holder.findViewById(R.id.alice_style_vertical);
        mHorizontalButton =
                (RadioButtonWithDescription) holder.findViewById(R.id.alice_style_horizontal);
        mHorizontalNoReorderButton =
                (RadioButtonWithDescription)
                        holder.findViewById(R.id.alice_style_horizontal_no_reorder);

        // 竖向暂未支持：置灰不可选。
        if (mVerticalButton != null) {
            mVerticalButton.setEnabled(false);
            mVerticalButton.setAlpha(0.5f);
        }

        if (mGroup == null) return;
        mGroup.setOnCheckedChangeListener(this);
        setCheckedState(mStyle);
    }

    @Override
    public void onCheckedChanged(RadioGroup group, int checkedId) {
        if (mHorizontalNoReorderButton != null
                && mHorizontalNoReorderButton.isChecked()) {
            mStyle = STYLE_HORIZONTAL_NO_REORDER;
        } else if (mHorizontalButton != null && mHorizontalButton.isChecked()) {
            mStyle = STYLE_HORIZONTAL;
        } else if (mVerticalButton != null && mVerticalButton.isChecked()) {
            mStyle = STYLE_VERTICAL;
        } else {
            mStyle = STYLE_DEFAULT;
        }
        callChangeListener(mStyle);
    }

    /** 设置当前选中的样式。 */
    public void setCheckedState(int style) {
        mStyle = style;
        if (mDefaultButton != null) mDefaultButton.setChecked(style == STYLE_DEFAULT);
        if (mVerticalButton != null) mVerticalButton.setChecked(style == STYLE_VERTICAL);
        if (mHorizontalButton != null) mHorizontalButton.setChecked(style == STYLE_HORIZONTAL);
        if (mHorizontalNoReorderButton != null) {
            mHorizontalNoReorderButton.setChecked(style == STYLE_HORIZONTAL_NO_REORDER);
        }
    }

    /** @return 已保存的样式，未保存或非法值回退为应用默认样式。 */
    public static int getCurrentStyle() {
        int style =
                ChromeSharedPreferences.getInstance()
                        .readInt(PREF_TAB_SWITCHER_STYLE, STYLE_APP_DEFAULT);
        if (style == STYLE_DEFAULT
                || style == STYLE_VERTICAL
                || style == STYLE_HORIZONTAL
                || style == STYLE_HORIZONTAL_NO_REORDER) {
            return style;
        }
        return STYLE_APP_DEFAULT;
    }

    /** @return 样式的短名称，用于「标签页和标签页分组」入口下方的摘要。 */
    public static String getStyleTitle(Resources resources, int style) {
        @StringRes int titleRes = R.string.alice_tab_switcher_style_default_summary;
        if (style == STYLE_VERTICAL) {
            titleRes = R.string.alice_tab_switcher_style_vertical_summary;
        } else if (style == STYLE_HORIZONTAL) {
            titleRes = R.string.alice_tab_switcher_style_horizontal_summary;
        } else if (style == STYLE_HORIZONTAL_NO_REORDER) {
            titleRes = R.string.alice_tab_switcher_style_horizontal_no_reorder_summary;
        }
        return resources.getString(titleRes);
    }

    /** 供测试使用。 */
    public int getStyleForTesting() {
        return mStyle;
    }
}
ALICE_EOF

mkdir -p "alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/appearance/settings"
cat > "alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AliceTabSwitcherStyleSettingsFragment.java" << 'ALICE_EOF'
// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.appearance.settings;

import android.os.Bundle;

import org.chromium.base.supplier.MonotonicObservableSupplier;
import org.chromium.base.supplier.ObservableSuppliers;
import org.chromium.base.supplier.SettableMonotonicObservableSupplier;
import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.chrome.R;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;
import org.chromium.chrome.browser.settings.ChromeBaseSettingsFragment;
import org.chromium.chrome.browser.settings.search.ChromeBaseSearchIndexProvider;
import org.chromium.components.browser_ui.settings.SettingsUtils;

/** Alice: 标签切换器样式设置页（默认 / 竖向 / 横向 / 横向不重排）。 */
@NullMarked
public class AliceTabSwitcherStyleSettingsFragment extends ChromeBaseSettingsFragment {
    /** 与 tab_ui 侧读取的 key 保持一致。 */
    public static final String PREF_ALICE_TAB_SWITCHER_STYLE =
            AliceTabSwitcherStylePreference.PREF_TAB_SWITCHER_STYLE;

    private final SettableMonotonicObservableSupplier<String> mPageTitle =
            ObservableSuppliers.createMonotonic();
    private @Nullable AliceTabSwitcherStylePreference mStylePref;

    @Override
    public void onCreatePreferences(@Nullable Bundle savedInstanceState, @Nullable String rootKey) {
        mPageTitle.set(getString(R.string.alice_tab_switcher_title));
        SettingsUtils.addPreferencesFromResource(this, R.xml.alice_tab_switcher_style_preferences);
        initStylePref();
    }

    @Override
    public MonotonicObservableSupplier<String> getPageTitle() {
        return mPageTitle;
    }

    @Override
    public @AnimationType int getAnimationType() {
        return AnimationType.PROPERTY;
    }

    @Override
    public @Nullable String getMainMenuKey() {
        // Alice patch start 0035
        return "tabs";
        // Alice patch end 0035
    }

    private void initStylePref() {
        mStylePref = findPreference(PREF_ALICE_TAB_SWITCHER_STYLE);
        if (mStylePref == null) return;

        mStylePref.setCheckedState(AliceTabSwitcherStylePreference.getCurrentStyle());
        mStylePref.setOnPreferenceChangeListener(
                (preference, newValue) -> {
                    writeStyle((int) newValue);
                    return true;
                });
    }

    private static void writeStyle(int style) {
        ChromeSharedPreferences.getInstance().writeInt(PREF_ALICE_TAB_SWITCHER_STYLE, style);
    }

    public static final ChromeBaseSearchIndexProvider SEARCH_INDEX_DATA_PROVIDER =
            new ChromeBaseSearchIndexProvider(
                    AliceTabSwitcherStyleSettingsFragment.class.getName(),
                    ChromeBaseSearchIndexProvider.INDEX_OPT_OUT);
}
ALICE_EOF

# ---------- 注册新增文件 ----------
sed -i '/^chrome_java_ext_sources = \[$/a\
  # Alice patch start 0035\
  "//alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AliceTabSwitcherStylePreference.java",\
  "//alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/appearance/settings/AliceTabSwitcherStyleSettingsFragment.java",\
  # Alice patch end 0035\
' "$path2"

sed -i '/^chrome_app_java_resources_ext_sources = \[$/a\
  # Alice patch start 0035\
  "//alice/chromium_src/chrome/android/java/res/xml/alice_tab_switcher_style_preferences.xml",\
  "//alice/chromium_src/chrome/android/java/res/layout/alice_tab_switcher_style_preference.xml",\
  "//alice/chromium_src/chrome/android/java/res/values/alice_tab_switcher_strings.xml",\
  "//alice/chromium_src/chrome/android/java/res/values-zh/alice_tab_switcher_strings.xml",\
  # Alice patch end 0035\
' "$path3"

# ---------- 设置-标签页和标签页分组 新增入口 ----------
sed -i 's|^</PreferenceScreen>$|    <!-- Alice patch start 0035 -->\n    <org.chromium.components.browser_ui.settings.ChromeBasePreference\n        android:fragment="org.chromium.chrome.browser.appearance.settings.AliceTabSwitcherStyleSettingsFragment"\n        android:key="alice_tab_switcher_style_entry"\n        android:persistent="false"\n        android:title="@string/alice_tab_switcher_title" />\n    <!-- Alice patch end 0035 -->\n</PreferenceScreen>|' "$path1"

# ---------- 设置-标签页和标签页分组 入口下方显示当前选项 ----------
sed -i 's|^import org.chromium.chrome.R;$|&\n// Alice patch start 0035\nimport org.chromium.chrome.browser.appearance.settings.AliceTabSwitcherStylePreference;\n// Alice patch end 0035|' "$path4"

sed -i 's|^    static final String PREF_CCT_ALWAYS_OPEN_IN_BROWSER = "cct_always_open_in_browser";$|&\n\n    // Alice patch start 0035\n    public static final String PREF_ALICE_TAB_SWITCHER_STYLE_ENTRY =\n            "alice_tab_switcher_style_entry";\n    // Alice patch end 0035|' "$path4"

sed -i 's|^        configureTabArchiveSettings();$|&\n        // Alice patch start 0035\n        updateAliceTabSwitcherStylePref();\n        // Alice patch end 0035|' "$path4"

sed -i '/^    private void configureAutoOpenSyncedTabGroupsSwitch() {$/i\
    // Alice patch start 0035\
    /** 标签切换器入口下方显示当前选中的样式。 */\
    private void updateAliceTabSwitcherStylePref() {\
        Preference pref = findPreference(PREF_ALICE_TAB_SWITCHER_STYLE_ENTRY);\
        if (pref == null) return;\
        pref.setSummary(\
                AliceTabSwitcherStylePreference.getStyleTitle(\
                        getResources(),\
                        AliceTabSwitcherStylePreference.getCurrentStyle()));\
    }\
    // Alice patch end 0035\
' "$path4"
