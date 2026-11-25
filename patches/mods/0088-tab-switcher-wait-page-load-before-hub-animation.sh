#!/bin/bash
# 横向牌堆点击非当前标签时，让标签切换的布局和绘制先完成，再启动 Hub 收起动画。
# 只延后动画启动，不等待网页加载；当前标签和默认标签网格样式保持原时序。
# 依赖 0036-tab-switcher-horizontal.sh。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0088' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 延迟约一帧启动收起动画，供标签切换产生的布局和绘制任务先落地。
sed -i '/^public class HubLayout extends Layout implements HubLayoutController, AppHeaderObserver {$/a\
    // Alice patch start 0088\
    private static final long ALICE_TAB_SWITCH_ANIMATION_DELAY_MS = 16L;\
    private final Runnable mAliceDeferredHubHide = this::startHiding;\
    // Alice patch end 0088
' "$path1"

# 横向样式选择非当前标签时延后动画；连续点击会取消上一条待启动任务。
sed -i '/^    public void selectTabAndHideHubLayout(@TabId int tabId) {$/,/^    }$/c\
    // Alice patch start 0088\
    public void selectTabAndHideHubLayout(@TabId int tabId) {\
        assumeNonNull(mTabModelSelector);\
        int alicePreviousTabId = mTabModelSelector.getCurrentTabId();\
        TabModelUtils.selectTabById(\
                mTabModelSelector, tabId, TabSelectionType.FROM_USER);\
        if (HubAnimationConstants.isAliceHorizontalStyle()\
                \&\& tabId != alicePreviousTabId) {\
            mRootView.removeCallbacks(mAliceDeferredHubHide);\
            mRootView.postOnAnimationDelayed(\
                    mAliceDeferredHubHide,\
                    ALICE_TAB_SWITCH_ANIMATION_DELAY_MS);\
            return;\
        }\
        startHiding();\
    }\
    // Alice patch end 0088
' "$path1"

# 其他路径主动开始收起时取消待启动任务，避免重复播放。
sed -i '/^    public void startHiding() {$/a\
        // Alice patch start 0088\
        mRootView.removeCallbacks(mAliceDeferredHubHide);\
        // Alice patch end 0088
' "$path1"

# 销毁时清除待执行动画。
sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0088\
        mRootView.removeCallbacks(mAliceDeferredHubHide);\
        // Alice patch end 0088
' "$path1"
