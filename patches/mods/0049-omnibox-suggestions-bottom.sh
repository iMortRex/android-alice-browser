#!/bin/bash
# 地址栏位于底部时，让 Omnibox 建议列表每帧吸附到地址栏上沿。

set -e

path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdownEmbedder.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/OmniboxSuggestionsDropdownEmbedderImpl.java"
path3="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"

# 检测是否已应用
if grep -q 'Alice patch start 0049' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 在 Embedder 接口中暴露工具栏位置和锚点 View。
sed -i '/^import android\.annotation\.SuppressLint;$/a\
    // Alice patch start 0049\
import android.view.View;\
    // Alice patch end 0049' "$path1"

sed -i '/^    boolean isPhoneStyleWindow();$/a\
    // Alice patch start 0049\
\
    /** 返回工具栏当前是否位于屏幕底部。 */\
    default boolean isToolbarOnBottom() {\
        return false;\
    }\
\
    /** 返回建议列表需要对齐的锚点 View。 */\
    View getAnchorView();\
    // Alice patch end 0049' "$path1"

# 在 Embedder 实现中提供工具栏位置和锚点 View。
sed -i '/^    public boolean isPhoneStyleWindow() {$/,/^    }$/ s|^    }$|    }\n    // Alice patch start 0049\n\n    @Override\n    public boolean isToolbarOnBottom() {\n        return mControlsPositionSupplier.get() == ControlsPosition.BOTTOM;\n    }\n\n    @Override\n    public View getAnchorView() {\n        return mAnchorView;\n    }\n    // Alice patch end 0049|' "$path2"

# 为建议容器增加每帧吸附所需的监听器字段。
sed -i '/^import android\.view\.ViewGroup;$/a\
    // Alice patch start 0049\
import android.view.ViewTreeObserver;\
    // Alice patch end 0049' "$path3"

sed -i '/^    private OmniboxAlignment mOmniboxAlignment = OmniboxAlignment\.UNSPECIFIED;$/a\
    // Alice patch start 0049\
\
    /** 每帧吸附使用的临时数组和监听器。 */\
    private final int[] mStickPosition = new int[2];\
    private final ViewTreeObserver.OnPreDrawListener mStickListener = this::stickToAnchor;\
    // Alice patch end 0049' "$path3"

# 每帧把建议列表底边吸附到地址栏上沿，必要时关闭沿途裁剪。
sed -i '/^    private void installAlignmentObserver() {$/i\
    // Alice patch start 0049\
    /** 每帧把下拉底边吸附到地址栏上沿，仅地址栏位于底部时生效。 */\
    private boolean stickToAnchor() {\
        if (mDropdown == null) return true;\
        if (mEmbedder == null || !mEmbedder.isToolbarOnBottom()) {\
            mDropdown.setTranslationY(0);\
            return true;\
        }\
        if (mDropdown.getVisibility() != View.VISIBLE) return true;\
        int aliceBottomPadding = mDropdown.getBaseBottomPadding();\
        if (mDropdown.getPaddingBottom() != aliceBottomPadding) {\
            mDropdown.setPaddingRelative(\
                    mDropdown.getPaddingStart(),\
                    mDropdown.getPaddingTop(),\
                    mDropdown.getPaddingEnd(),\
                    aliceBottomPadding);\
        }\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int target = mStickPosition[1];\
        if (target <= 0) return true;\
\
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
\
        getLocationInWindow(mStickPosition);\
        int containerBottom = mStickPosition[1] + getHeight();\
        int containerDelta = target - containerBottom;\
        if (containerDelta != 0) {\
            setTranslationY(getTranslationY() + containerDelta);\
            mDropdown.setTranslationY(mDropdown.getTranslationY() - containerDelta);\
        }\
        return true;\
    }\
    // Alice patch end 0049\
' "$path3"

# 安装对齐观察器时同时注册逐帧吸附监听器。
sed -i '/^            mOmniboxAlignment = mEmbedder\.addAlignmentObserver(mOmniboxAlignmentObserver);$/a\
            // Alice patch start 0049\
            getViewTreeObserver().addOnPreDrawListener(mStickListener);\
            // Alice patch end 0049' "$path3"

# 移除对齐观察器时注销吸附监听器并清理位移。
sed -i '/^            mEmbedder\.removeAlignmentObserver(mOmniboxAlignmentObserver);$/a\
        // Alice patch start 0049\
        getViewTreeObserver().removeOnPreDrawListener(mStickListener);\
        mDropdown.setTranslationY(0);\
        setTranslationY(0);\
        // Alice patch end 0049' "$path3"
