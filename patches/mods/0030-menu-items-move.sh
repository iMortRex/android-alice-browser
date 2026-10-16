#!/bin/bash
# 菜单条目调整：
#   1) 「开发者工具」：「更多工具」子菜单 → 一级菜单，并给条目加上图标
#   2) 「删除浏览数据」：一级菜单 → 「更多工具」子菜单
#   3) 「密码和自动填充」：一级菜单 → 「更多工具」子菜单
#   4) 「保存并分享」：一级菜单 → 「更多工具」子菜单
#
# 「更多工具」子菜单的条目是惰性构建的（Supplier），所以「保存并分享」用到的
# url / isNativePage / isFileScheme / isContentScheme 要一并传进 buildMoreToolsItem()。

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedAppMenuPropertiesDelegate.java"

# 检测是否已应用
if grep -q 'Alice patch start 0030' "$path1"; then
    exit 100
fi

# 1) 一级菜单：在「更多工具」之前插入「开发者工具」
sed -i 's|^        // More tools|        // Alice patch start 0030\n        // 开发者工具：从「更多工具」子菜单提升到一级菜单\n        if (mMoreToolsItemBuilder.shouldShowDevToolsItem(currentTab)) {\n            modelList.add(mMoreToolsItemBuilder.buildDevToolsItem());\n        }\n        // Alice patch end 0030\n\n        // More tools|' "$path1"

# 2) 「更多工具」子菜单里要构建「保存并分享」，把页面上下文参数传进去
sed -i 's|^            modelList\.add(buildMoreToolsItem(currentTab));|            modelList.add(\n                    buildMoreToolsItem(\n                            currentTab, isNativePage, isFileScheme, isContentScheme, url));|' "$path1"
sed -i 's|^    private ListItem buildMoreToolsItem(@Nullable Tab currentTab) {|    private ListItem buildMoreToolsItem(\n            @Nullable Tab currentTab,\n            boolean isNativePage,\n            boolean isFileScheme,\n            boolean isContentScheme,\n            GURL url) {|' "$path1"

# 3) 一级菜单：移除「删除浏览数据」
sed -i '/^        \/\/ Delete browsing data/{N;N;N;d}' "$path1"

# 4) 一级菜单：移除「密码和自动填充」
sed -i '/^        \/\/ Passwords and autofill/{N;N;N;d}' "$path1"

# 5) 一级菜单：移除「保存并分享」
sed -i '/^        \/\/ Save and share/,/^        }/d' "$path1"

# 6) 「更多工具」子菜单：移除「开发者工具」
sed -i '/^                    if (mMoreToolsItemBuilder\.shouldShowDevToolsItem(currentTab)) {/,/^                    }/d' "$path1"

# 7) 「更多工具」子菜单：加入挪过来的三个条目
sed -i 's|^                    if (!submenuItems\.isEmpty()|                    // Alice patch start 0030\n                    AppMenuItemUtils.maybeAddDividerLine(submenuItems, R.id.divider_line_id);\n                    // 「删除浏览数据」：原来在一级菜单\n                    if (shouldShowQuickDeleteItem()) {\n                        submenuItems.add(buildQuickDeleteItem());\n                    }\n                    // 「密码和自动填充」：原来在一级菜单\n                    if (shouldShowPasswordsAndAutofillParentItem()) {\n                        submenuItems.add(buildPasswordsAndAutofillParentItem());\n                    }\n                    // 「保存并分享」：原来在一级菜单\n                    if (shouldShowSaveAndShareItem(\n                            currentTab, isNativePage, isFileScheme, isContentScheme, url)) {\n                        submenuItems.add(\n                                buildSaveAndShareItem(\n                                        currentTab,\n                                        isNativePage,\n                                        isFileScheme,\n                                        isContentScheme,\n                                        url));\n                    }\n                    // Alice patch end 0030\n                    if (!submenuItems.isEmpty()|' "$path1"

# 8) 收尾：把删除条目后留下的连续空行合成一行
sed -i '/^$/{N;/^\n$/D}' "$path1"

# === 「开发者工具」的图标 ===

# 9) 新建 24dp 矢量图标（</> 造型，和桌面版开发者工具的 code 图标一致）
icon1="chrome/android/java/res/drawable/ic_dev_tools_24dp.xml"
if [ ! -f "$icon1" ]; then
    cat > "$icon1" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!--
Copyright 2026 The Chromium Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file.
-->

<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorControlNormal">
  <path android:fillColor="@android:color/white"
    android:pathData="M9.4,16.6 L4.8,12 L9.4,7.4 L8,6 L2,12 L8,18 Z M14.6,16.6 L19.2,12 L14.6,7.4 L16,6 L22,12 L16,18 Z"/>
</vector>
EOF
fi

# 10) 把图标注册进 chrome 的资源列表（插在 ic_dock_to_right 之前，保持字母序）
path3="chrome/android/chrome_java_resources.gni"
if ! grep -q 'ic_dev_tools_24dp\.xml' "$path3"; then
    sed -i 's|^  "java/res/drawable/ic_dock_to_right_24dp\.xml",$|  "java/res/drawable/ic_dev_tools_24dp.xml",\n&|' "$path3"
fi

# 11) MoreToolsItemBuilder：Dev tools 条目支持图标
path2="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/MoreToolsItemBuilder.java"
sed -i '/^    \/\*\* Builds the "Dev tools" menu item\. \*\/$/,$d' "$path2"
cat >> "$path2" <<'EOF'
    /**
     * Builds the "Dev tools" menu item.
     *
     * @param showIcon Whether to display an icon next to the item.
     */
    public ListItem buildDevToolsItem(boolean showIcon) {
        return AppMenuItemUtils.createStandardListItem(
                AppMenuItemUtils.buildModelForStandardMenuItem(
                        mContext,
                        mAppMenuItemTheme,
                        R.id.dev_tools,
                        R.string.menu_dev_tools,
                        showIcon ? R.drawable.ic_dev_tools_24dp : Resources.ID_NULL,
                        mIsMenuIconAtStart),
                showIcon);
    }
}
EOF

# 12) 一级菜单里调用时带上 showIcon（当前 tabbed 菜单始终为 true）
sed -i 's|^            modelList\.add(mMoreToolsItemBuilder\.buildDevToolsItem());$|            modelList.add(\n                    mMoreToolsItemBuilder.buildDevToolsItem(shouldShowIconBeforeItem()));|' "$path1"
