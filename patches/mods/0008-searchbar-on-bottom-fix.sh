#!/bin/bash
# NTP：地址栏在底部时，工具栏留白从顶部挪到底部

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutProperties.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutViewBinder.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPage.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path6="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdownEmbedder.java"
path7="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/OmniboxSuggestionsDropdownEmbedderImpl.java"
path8="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# --- 1) NewTabPageLayoutProperties：新增 BOTTOM_INSET_PX 属性 ---
sed -i '/^    static final WritableIntPropertyKey TOP_INSET_PX = new WritableIntPropertyKey();$/a\
    // Alice patch start\
\
    /** The bottom inset (toolbar height) for the NewTabPageLayout. */\
    static final WritableIntPropertyKey BOTTOM_INSET_PX = new WritableIntPropertyKey();\
    // Alice patch end' "$path1"

sed -i 's|^\( *\)DELEGATE, ON_LAYOUT_CHANGE_LISTENER, SEARCH_BOX_VIEW, TOP_INSET_PX, TRANSITION_Y,$|\1// Alice patch start\n\1DELEGATE, ON_LAYOUT_CHANGE_LISTENER, SEARCH_BOX_VIEW, TOP_INSET_PX, BOTTOM_INSET_PX, TRANSITION_Y,\n\1// Alice patch end|' "$path1"

# --- 2) ViewBinder：新增分支写 paddingBottom ---
sed -i '/^import static org\.chromium\.chrome\.browser\.ntp\.NewTabPageLayoutProperties\.DELEGATE;$/i\
    // Alice patch start\
import static org.chromium.chrome.browser.ntp.NewTabPageLayoutProperties.BOTTOM_INSET_PX;\
    // Alice patch end' "$path2"

sed -i '/^        } else if (TRANSITION_Y == key) {$/i\
        // Alice patch start\
        } else if (BOTTOM_INSET_PX == key) {\
            newTabPageLayout.setPaddingRelative(\
                    newTabPageLayout.getPaddingStart(),\
                    newTabPageLayout.getPaddingTop(),\
                    newTabPageLayout.getPaddingEnd(),\
                    model.get(BOTTOM_INSET_PX));\
        // Alice patch end' "$path2"

# --- 3) Coordinator：按工具栏位置算 top/bottom inset ---
sed -i '/^    private int mTopInset;$/a\
    // Alice patch start\
    private boolean mToolbarOnBottom;\
    // Alice patch end' "$path3"

sed -i '/^        int toolbarHeightNoShadow =$/,/^        mModel.set(NewTabPageLayoutProperties.TOP_INSET_PX, toolbarHeightNoShadow + mTopInset);$/c\
        // Alice patch start\
        updateToolbarInsets();\
        // Alice patch end' "$path3"

sed -i '$i\
    // Alice patch start\
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
                mToolbarOnBottom ? mTopInset : toolbarHeightNoShadow + mTopInset);\
        mModel.set(\
                NewTabPageLayoutProperties.BOTTOM_INSET_PX,\
                mToolbarOnBottom ? toolbarHeightNoShadow : 0);\
    }\
    // Alice patch end' "$path3"

# --- 4) NewTabPage：接上工具栏位置变化 ---
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsStateProvider;$/a\
    // Alice patch start\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
    // Alice patch end' "$path4"

sed -i '/^    \/\*\* Allows clients to listen for updates to the scroll changes of the search box on the NTP\. \*\/$/i\
    // Alice patch start\
    @Override\
    public void onControlsPositionChanged(@ControlsPosition int controlsPosition) {\
        mNewTabPageCoordinator.setToolbarOnBottom(\
                controlsPosition == ControlsPosition.BOTTOM);\
    }\
    // Alice patch end\
' "$path4"

# --- 5) ToolbarPositionController：不再强制把搜索框改到顶部 ---
sed -i '/^        if (ntpShowing$/,/^                || doesUserPreferTopToolbar) {$/c\
        // Alice patch start\
        if (isFindInPageShowing || doesUserPreferTopToolbar) {\
        // Alice patch end' "$path5"

# --- 6) 建议下拉的 embedder 接口：新增 isToolbarOnBottom()/getAnchorView() ---
sed -i '/^import android\.annotation\.SuppressLint;$/a\
    // Alice patch start\
import android.view.View;\
    // Alice patch end' "$path6"

sed -i '/^    boolean isPhoneStyleWindow();$/a\
    // Alice patch start\
\
    /** Returns whether the toolbar is currently at the bottom of the screen. */\
    default boolean isToolbarOnBottom() {\
        return false;\
    }\
\
    /** Returns the view the suggestions dropdown is aligned to. */\
    View getAnchorView();\
    // Alice patch end' "$path6"

# --- 7) embedder 实现：实现上面两个方法 ---
sed -i '/^    public boolean isPhoneStyleWindow() {$/,/^    }$/ s|^    }$|    }\n    // Alice patch start\n\n    @Override\n    public boolean isToolbarOnBottom() {\n        return mControlsPositionSupplier.get() == ControlsPosition.BOTTOM;\n    }\n\n    @Override\n    public View getAnchorView() {\n        return mAnchorView;\n    }\n    // Alice patch end|' "$path7"

# --- 8) 建议下拉容器：每帧吸附到地址栏上沿 ---
sed -i '/^import android\.view\.ViewGroup;$/a\
    // Alice patch start\
import android.view.ViewTreeObserver;\
    // Alice patch end' "$path8"

sed -i '/^    private OmniboxAlignment mOmniboxAlignment = OmniboxAlignment\.UNSPECIFIED;$/a\
    // Alice patch start\
\
    /** Alice: 每帧吸附用的临时数组与监听器。 */\
    private final int[] mStickPosition = new int[2];\
    private final ViewTreeObserver.OnPreDrawListener mStickListener = this::stickToAnchor;\
    // Alice patch end' "$path8"

sed -i '/^    private void installAlignmentObserver() {$/i\
    // Alice patch start\
    /** Alice: 每帧把下拉底边吸附到地址栏上沿（仅地址栏在底部时）。 */\
    private boolean stickToAnchor() {\
        if (mDropdown == null) return true;\
        if (mEmbedder == null || !mEmbedder.isToolbarOnBottom()) {\
            // 非底部时清掉之前的位移，否则切回顶部还停在下面\
            mDropdown.setTranslationY(0);\
            return true;\
        }\
        if (mDropdown.getVisibility() != View.VISIBLE) return true;\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int target = mStickPosition[1];\
        if (target <= 0) return true;\
\
        // 沿途关掉裁剪，否则下移的部分会被父容器切掉\
        View parent = mDropdown.getParent() instanceof View ? (View) mDropdown.getParent() : null;\
        while (parent instanceof ViewGroup) {\
            ((ViewGroup) parent).setClipChildren(false);\
            parent = parent.getParent() instanceof View ? (View) parent.getParent() : null;\
        }\
\
        mDropdown.getLocationInWindow(mStickPosition);\
        int bottom = mStickPosition[1] + mDropdown.getHeight();\
        int delta = target - bottom;\
        if (delta != 0) {\
            mDropdown.setTranslationY(mDropdown.getTranslationY() + delta);\
        }\
        return true;\
    }\
    // Alice patch end\
' "$path8"

sed -i '/^            mOmniboxAlignment = mEmbedder\.addAlignmentObserver(mOmniboxAlignmentObserver);$/a\
            // Alice patch start\
            getViewTreeObserver().addOnPreDrawListener(mStickListener);\
            // Alice patch end' "$path8"

sed -i '/^            mEmbedder\.removeAlignmentObserver(mOmniboxAlignmentObserver);$/a\
        // Alice patch start\
        getViewTreeObserver().removeOnPreDrawListener(mStickListener);\
        // Alice patch end' "$path8"
