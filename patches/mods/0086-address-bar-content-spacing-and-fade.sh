#!/bin/bash
# 页面地址栏内容增加水平留白，并在右侧截断处渐隐。

set -e

path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/LocationBarLayout.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/UrlBar.java"

# 检测是否已应用
if grep -q 'Alice patch start 0086' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 记录 URL 内容原始 padding，并增加页面地址栏专用留白。
sed -i '/^    private final int mLocationBarIconStartingPadding;$/a\
    // Alice patch start 0086\
    private final int mAliceAddressBarStartPaddingPx;\
    private final int mAliceAddressBarEndPaddingPx;\
    private final int mAliceOriginalUrlBarStartPaddingPx;\
    private final int mAliceOriginalUrlBarEndPaddingPx;\
    // Alice patch end 0086' "$path1"

sed -i '/^        mLocationBarIconStartingPadding =$/,/^                res.getDimensionPixelSize(R.dimen.location_bar_icon_starting_padding);$/c\
        mLocationBarIconStartingPadding =\
                res.getDimensionPixelSize(R.dimen.location_bar_icon_starting_padding);\
        // Alice patch start 0086\
        mAliceAddressBarStartPaddingPx =\
                Math.round(6 * getResources().getDisplayMetrics().density);\
        mAliceAddressBarEndPaddingPx =\
                Math.round(12 * getResources().getDisplayMetrics().density);\
        mAliceOriginalUrlBarStartPaddingPx = mUrlBar.getPaddingStart();\
        mAliceOriginalUrlBarEndPaddingPx = mUrlBar.getPaddingEnd();\
        // Alice patch end 0086' "$path1"

# 每次测量时按当前 URL 更新，避免依赖工具栏是否进入居中分支。
sed -i '/^    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {$/a\
        // Alice patch start 0086\
        updateStartPadding();\
        // Alice patch end 0086
' "$path1"

# 仅网页地址栏使用 6dp 左侧、12dp 右侧留白；NTP/搜索页恢复 UrlBar 原始 padding。
sed -i '/^    \/\* package \*\/ void updateStartPadding() {$/,/^    }$/c\
    // Alice patch start 0086\
    /* package */ void updateStartPadding() {\
        View statusView = findViewById(R.id.location_bar_status);\
        boolean statusVisible = statusView != null && statusView.getVisibility() == VISIBLE;\
        int aliceLayoutStartPadding =\
                (statusVisible || isBackButtonVisible()) ? 0 : mLocationBarIconStartingPadding;\
        if (getPaddingStart() != aliceLayoutStartPadding) {\
            setLocationBarStartPadding(aliceLayoutStartPadding);\
        }\
\
        boolean aliceIsAddressBar =\
                mLocationBarDataProvider != null\
                        && !OmniboxUrlUtils.isNtpUrl(\
                                mLocationBarDataProvider.getCurrentGurl());\
        int aliceStartPadding =\
                aliceIsAddressBar\
                        ? mAliceAddressBarStartPaddingPx\
                        : mAliceOriginalUrlBarStartPaddingPx;\
        int aliceEndPadding =\
                aliceIsAddressBar\
                        ? mAliceAddressBarEndPaddingPx\
                        : mAliceOriginalUrlBarEndPaddingPx;\
        if (mUrlBar.getPaddingStart() != aliceStartPadding\
                || mUrlBar.getPaddingEnd() != aliceEndPadding) {\
            mUrlBar.setPaddingRelative(\
                    aliceStartPadding,\
                    mUrlBar.getPaddingTop(),\
                    aliceEndPadding,\
                    mUrlBar.getPaddingBottom());\
        }\
        mUrlBar.setAliceAddressBarFadeEnabled(aliceIsAddressBar);\
    }\
    // Alice patch end 0086' "$path1"

# UrlBar 增加页面地址栏专用渐隐状态。
sed -i '/^    private boolean mBoundsEllipsisEnabled;$/i\
    // Alice patch start 0086\
    private boolean mAliceAddressBarFadeEnabled;\
    // Alice patch end 0086' "$path2"

# 只在文本实际溢出时显示右侧渐隐，避免短 URL 和搜索框出现边缘阴影。
sed -i '/^    protected float getRightFadingEdgeStrength() {$/,/^    }$/c\
    // Alice patch start 0086\
    protected float getRightFadingEdgeStrength() {\
        int aliceViewportWidth = getVisibleMeasuredViewportWidth();\
        return mAliceAddressBarFadeEnabled\
                        && aliceViewportWidth > 0\
                        && getTextWidth() > aliceViewportWidth\
                ? 1.0f\
                : 0.0f;\
    }\
\
    void setAliceAddressBarFadeEnabled(boolean enabled) {\
        if (mAliceAddressBarFadeEnabled == enabled) return;\
        mAliceAddressBarFadeEnabled = enabled;\
        if (enabled) {\
            setFadingEdgeLength(\
                    Math.round(24 * getResources().getDisplayMetrics().density));\
        }\
        invalidate();\
    }\
    // Alice patch end 0086' "$path2"
