#!/bin/bash
# 标签管理页横向牌堆：保留进入页面时的激活卡片配色。
# 点击其他卡片只切换实际标签，不把激活色移动到点击的卡片上。
# 依赖 0036-tab-switcher-horizontal.sh。

set -e

path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0087' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 记录进入横向牌堆时真正处于激活状态的标签。
sed -i '/^    private boolean mAliceStackStyle;$/a\
    // Alice patch start 0087\
    /** 横向牌堆本次显示期间固定的视觉激活标签。 */\
    private int mAliceVisualSelectedTabId = Tab.INVALID_TAB_ID;\
    // Alice patch end 0087
' "$path1"

# 每次重建标签列表时重新记录当前标签，使首次加载能够正常显示激活色。
sed -i '/^    public void resetWithListOfTabs($/,/^    }$/ s|^        TabModel tabModel = mCurrentTabModelSupplier.get();$|&\
        // Alice patch start 0087\
        if (mAliceStackStyle) {\
            @Nullable Tab currentTab =\
                    tabModel == null ? null : tabModel.getCurrentTabSupplier().get();\
            mAliceVisualSelectedTabId =\
                    currentTab == null ? Tab.INVALID_TAB_ID : currentTab.getId();\
        }\
        // Alice patch end 0087|' "$path1"

# 普通浏览状态下按进入页面时记录的标签决定激活色，而不是跟随点击后的真实当前标签。
sed -i 's|^        model.set(TabProperties.IS_SELECTED, isTabSelected(tab, model, tabActionState));$|        // Alice patch start 0087\
        boolean isSelected = isTabSelected(tab, model, tabActionState);\
        if (mAliceStackStyle \&\& tabActionState != TabActionState.SELECTABLE) {\
            isSelected =\
                    TabProperties.getTabId(model) == mAliceVisualSelectedTabId;\
        }\
        model.set(TabProperties.IS_SELECTED, isSelected);\
        // Alice patch end 0087|' "$path1"

# 横向样式下不取消进入页面时当前卡片的选中视觉。
sed -i '/^            oldModel.set(TabProperties.IS_SELECTED, false);$/c\
            // Alice patch start 0087\
            // 横向牌堆保留进入页面时的激活卡片，点击切换不迁移激活色。\
            if (!mAliceStackStyle) {\
                oldModel.set(TabProperties.IS_SELECTED, false);\
            }\
            // Alice patch end 0087
' "$path1"

# 横向样式下不把点击的卡片切换为新的选中视觉。
sed -i '/^            newModel.set(TabProperties.IS_SELECTED, true);$/c\
            // Alice patch start 0087\
            // 横向牌堆保留进入页面时的激活卡片，点击切换不迁移激活色。\
            if (!mAliceStackStyle) {\
                newModel.set(TabProperties.IS_SELECTED, true);\
            }\
            // Alice patch end 0087
' "$path1"
