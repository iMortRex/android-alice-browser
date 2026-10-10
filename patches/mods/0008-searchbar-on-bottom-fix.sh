#!/bin/bash
# NTP：地址栏在底部时，工具栏留白从顶部挪到底部

set -e

# 检测是否已应用
if grep -q 'BOTTOM_INSET_PX' "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutProperties.java"; then
    exit 100
fi
# 搜索框部分
# 1) 加 BOTTOM_INSET_PX 属性
sed -i '/static final WritableIntPropertyKey TOP_INSET_PX = new WritableIntPropertyKey();/a\
\
    /** The bottom inset (toolbar height) for the NewTabPageLayout. */\
    static final WritableIntPropertyKey BOTTOM_INSET_PX = new WritableIntPropertyKey();' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutProperties.java"

sed -i 's|DELEGATE, ON_LAYOUT_CHANGE_LISTENER, SEARCH_BOX_VIEW, TOP_INSET_PX, TRANSITION_Y,|DELEGATE, ON_LAYOUT_CHANGE_LISTENER, SEARCH_BOX_VIEW, TOP_INSET_PX, BOTTOM_INSET_PX, TRANSITION_Y,|' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutProperties.java"

# 2) binder：写 paddingBottom
sed -i '/import static org.chromium.chrome.browser.ntp.NewTabPageLayoutProperties.DELEGATE;/i\
import static org.chromium.chrome.browser.ntp.NewTabPageLayoutProperties.BOTTOM_INSET_PX;' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutViewBinder.java"

sed -i '/} else if (TRANSITION_Y == key) {/i\
        } else if (BOTTOM_INSET_PX == key) {\
            newTabPageLayout.setPaddingRelative(\
                    newTabPageLayout.getPaddingStart(),\
                    newTabPageLayout.getPaddingTop(),\
                    newTabPageLayout.getPaddingEnd(),\
                    model.get(BOTTOM_INSET_PX));' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageLayoutViewBinder.java"

# 3) Coordinator：按工具栏位置算 top/bottom inset
sed -i '/private int mTopInset;/a\
    private boolean mToolbarOnBottom;' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"

sed -i '/int toolbarHeightNoShadow =/,/mModel.set(NewTabPageLayoutProperties.TOP_INSET_PX, toolbarHeightNoShadow + mTopInset);/c\
        updateToolbarInsets();' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"

sed -i '$i\
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
    }' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"

# 4) NewTabPage：接上工具栏位置
sed -i '/import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider;/a\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPage.java"

sed -i '/\/\*\* Allows clients to listen for updates to the scroll changes of the search box on the NTP\. \*\//i\
    @Override\
    public void onControlsPositionChanged(@ControlsPosition int controlsPosition) {\
        mNewTabPageCoordinator.setToolbarOnBottom(\
                controlsPosition == ControlsPosition.BOTTOM);\
    }\
' \
    "chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPage.java"

# 5) 取消搜索框强制改到顶部
sed -i '/^        if (ntpShowing$/,/^                || doesUserPreferTopToolbar) {$/c\
        if (isFindInPageShowing || doesUserPreferTopToolbar) {' \
    "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"

# 搜索推荐部分
# 1) 接口：import + isToolbarOnBottom() + getAnchorView()
sed -i -e '/^import android.annotation.SuppressLint;$/a\
import android.view.View;' \
    -e '/^    boolean isPhoneStyleWindow();$/a\
\
    /** Returns whether the toolbar is currently at the bottom of the screen. */\
    default boolean isToolbarOnBottom() {\
        return false;\
    }\
\
    /** Returns the view the suggestions dropdown is aligned to. */\
    View getAnchorView();' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdownEmbedder.java"

# 2) 实现
sed -i '/public boolean isPhoneStyleWindow() {/,/^    }$/ s|^    }$|    }\n\n    @Override\n    public boolean isToolbarOnBottom() {\n        return mControlsPositionSupplier.get() == ControlsPosition.BOTTOM;\n    }\n\n    @Override\n    public View getAnchorView() {\n        return mAnchorView;\n    }|' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/OmniboxSuggestionsDropdownEmbedderImpl.java"

# 3) 容器：import
sed -i '/^import android.view.ViewGroup;$/a\
import android.view.ViewTreeObserver;' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"

# 4) 容器：字段
sed -i '/private OmniboxAlignment mOmniboxAlignment = OmniboxAlignment.UNSPECIFIED;/a\
\
    /** Alice: 每帧吸附用的临时数组与监听器。 */\
    private final int[] mStickPosition = new int[2];\
    private final ViewTreeObserver.OnPreDrawListener mStickListener = this::stickToAnchor;' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"

# 5) 容器：吸附方法（目标 = 锚点 view 的实时 Y；非底部时清零位移）
sed -i '/private void installAlignmentObserver() {/i\
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
' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"

# 6) 装上监听器
sed -i '/mOmniboxAlignment = mEmbedder.addAlignmentObserver(mOmniboxAlignmentObserver);/a\
            getViewTreeObserver().addOnPreDrawListener(mStickListener);' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"

# 7) 卸下监听器
sed -i '/mEmbedder.removeAlignmentObserver(mOmniboxAlignmentObserver);/a\
        getViewTreeObserver().removeOnPreDrawListener(mStickListener);' \
    "chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
