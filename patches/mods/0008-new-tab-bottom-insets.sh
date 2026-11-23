#!/bin/bash
# NTP：记录工具栏位置，并在工具栏位于底部时增加底部 inset

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutProperties.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutViewBinder.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPage.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"

# 检测是否已应用
if grep -q 'Alice patch start 0008' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# --- 1) NewTabPageLayoutProperties：新增 BOTTOM_INSET_PX 属性 ---
sed -i '/^    static final WritableIntPropertyKey TOP_INSET_PX = new WritableIntPropertyKey();$/a\
    // Alice patch start 0008\
\
    /** The bottom inset (toolbar height) for the NewTabPageLayout. */\
    static final WritableIntPropertyKey BOTTOM_INSET_PX = new WritableIntPropertyKey();\
    // Alice patch end 0008' "$path1"

sed -i 's|^        TOP_INSET_PX,$|        // Alice patch start 0008\n        TOP_INSET_PX,\n        BOTTOM_INSET_PX,\n        // Alice patch end 0008|' "$path1"

# --- 2) ViewBinder：新增分支写 paddingBottom ---
sed -i '/^import static org\.chromium\.chrome\.browser\.ntp\.NewTabPageLayoutProperties\.DELEGATE;$/i\
    // Alice patch start 0008\
import static org.chromium.chrome.browser.ntp.NewTabPageLayoutProperties.BOTTOM_INSET_PX;\
    // Alice patch end 0008' "$path2"

sed -i '/^        } else if (TRANSITION_Y == key) {$/i\
        // Alice patch start 0008\
        } else if (BOTTOM_INSET_PX == key) {\
            newTabPageLayout.setPaddingRelative(\
                    newTabPageLayout.getPaddingStart(),\
                    newTabPageLayout.getPaddingTop(),\
                    newTabPageLayout.getPaddingEnd(),\
                    model.get(BOTTOM_INSET_PX));\
        // Alice patch end 0008' "$path2"

# --- 3) Coordinator：按工具栏位置算 top/bottom inset ---
sed -i '/^    private int mTopInset;$/a\
    // Alice patch start 0008\
    private boolean mToolbarOnBottom;\
    // Alice patch end 0008' "$path3"

sed -i '/^        int toolbarHeightNoShadow =$/,/^        mModel.set(NewTabPageLayoutProperties.TOP_INSET_PX, toolbarHeightNoShadow + mTopInset);$/c\
        // Alice patch start 0008\
        updateToolbarInsets();\
        // Alice patch end 0008' "$path3"

sed -i '$i\
    // Alice patch start 0008\
    void setToolbarOnBottom(boolean toolbarOnBottom) {\
        if (mToolbarOnBottom == toolbarOnBottom) return;\
        mToolbarOnBottom = toolbarOnBottom;\
        updateToolbarInsets();\
    }\
\
    private void updateToolbarInsets() {\
        int toolbarHeightNoShadow =\
                mActivity.getResources().getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
        mModel.set(\
                NewTabPageLayoutProperties.TOP_INSET_PX,\
                toolbarHeightNoShadow + mTopInset);\
        mModel.set(\
                NewTabPageLayoutProperties.BOTTOM_INSET_PX,\
                mToolbarOnBottom ? toolbarHeightNoShadow : 0);\
    }\
    // Alice patch end 0008' "$path3"

# --- 4) NewTabPage：接上工具栏位置变化 ---
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsStateProvider;$/a\
    // Alice patch start 0008\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
    // Alice patch end 0008' "$path4"

sed -i '/^    \/\*\* Allows clients to listen for updates to the scroll changes of the search box on the NTP\. \*\/$/i\
    // Alice patch start 0008\
    @Override\
    public void onControlsPositionChanged(@ControlsPosition int controlsPosition) {\
        mNewTabPageCoordinator.setToolbarOnBottom(\
                controlsPosition == ControlsPosition.BOTTOM);\
    }\
    // Alice patch end 0008\
' "$path4"

# 地址栏位于底部时，不再把 NTP 搜索框强制改回顶部。
sed -i '/^        if (ntpShowing$/,/^                || doesUserPreferTopToolbar) {$/c\
        // Alice patch start 0008\
        if (isFindInPageShowing || doesUserPreferTopToolbar) {\
        // Alice patch end 0008' "$path5"
