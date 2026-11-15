#!/bin/bash
# Hub 入口闸门：用纯 Java 捕获计数暂缓快速重入；1000ms 后放行。

set -e

path1="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/LayoutManagerChrome.java"

# 检测是否已应用
if grep -q 'Alice patch start 0079' "$path1"; then
    exit 100
fi

# 依赖 0040 已引入的 java.util.Map/HashMap import。
# 记录每个标签正在进行的捕获数量，避免调用可能缺失的 native 测试接口。
sed -i '/^    private final Set<Integer> mAliceCompositingTabIds = new HashSet<>();$/a\
    // Alice patch start 0079\
    private final Map<Integer, Integer> mAliceCaptureInFlightCounts =\
            new HashMap<>();\
    // Alice patch end 0079' "$path1"

# WebContents 捕获发起前增加 Java 计数。
sed -i '/^            Callback<@Nullable Bitmap> wrappedCallback =$/i\
            // Alice patch start 0079\
            int aliceCaptureTabId = tab.getId();\
            aliceBeginCapture(aliceCaptureTabId);\
            // Alice patch end 0079\
' "$path1"

# 捕获回调进入时立即减少 Java 计数。
sed -i '/^                    (@Nullable Bitmap bitmap) -> {$/a\
                        // Alice patch start 0079\
                        aliceFinishCapture(aliceCaptureTabId);\
                        // Alice patch end 0079
' "$path1"

# 标签缩略图被移除时清掉对应计数。
sed -i '/^        mAliceCompositingTabIds\.remove(tabId);$/{N;s|^        mAliceCompositingTabIds\.remove(tabId);\n        if (mAliceRecentCompositedTabId == tabId) {$|        mAliceCompositingTabIds.remove(tabId);\n        // Alice patch start 0079\n        mAliceCaptureInFlightCounts.remove(tabId);\n        // Alice patch end 0079\n        if (mAliceRecentCompositedTabId == tabId) {|}' "$path1"

# 销毁时清空捕获计数。
sed -i '/^        mAliceCompositingTabIds\.clear();$/a\
        // Alice patch start 0079\
        mAliceCaptureInFlightCounts.clear();\
        // Alice patch end 0079' "$path1"

# 暴露纯 Java 捕获状态，供 Hub 入口判断是否已经可以安全播放动画。
sed -i '/^    \/\*\* Returns whether a thumbnail capture for a tab is in flight for testing\. \*\/$/i\
    // Alice patch start 0079\
    /** Returns whether a thumbnail capture for a tab is in flight. */\
    public boolean isTabCaptureInFlight(int tabId) {\
        return mAliceCaptureInFlightCounts.containsKey(tabId);\
    }\
\
    private void aliceBeginCapture(int tabId) {\
        Integer count = mAliceCaptureInFlightCounts.get(tabId);\
        mAliceCaptureInFlightCounts.put(tabId, count == null ? 1 : count + 1);\
    }\
\
    private void aliceFinishCapture(int tabId) {\
        Integer count = mAliceCaptureInFlightCounts.get(tabId);\
        if (count == null) return;\
        if (count <= 1) {\
            mAliceCaptureInFlightCounts.remove(tabId);\
        } else {\
            mAliceCaptureInFlightCounts.put(tabId, count - 1);\
        }\
    }\
    // Alice patch end 0079\
\
' "$path1"

# 为 Hub 缩略图捕获闸门增加计时所需的 import。
sed -i '/^import android\.content\.Context;$/a\
// Alice patch start 0079\
import android.os.SystemClock;\
// Alice patch end 0079' "$path2"

# 缩略图捕获尚未完成时暂不允许进入 Hub；超时后放行，避免无限阻塞。
sed -i '/^public class LayoutManagerChrome extends LayoutManagerImpl implements AccessibilityUtil\.Observer {$/a\
    // Alice patch start 0079\
    private static final long ALICE_HUB_CAPTURE_GATE_TIMEOUT_MS = 1000L;\
    // Alice patch end 0079\
' "$path2"
sed -i '/^    private @Nullable TabContentManager mTabContentManager;$/a\
    // Alice patch start 0079\
    private int mAliceHubCaptureGateTabId = Tab.INVALID_TAB_ID;\
    private long mAliceHubCaptureGateDeadlineMs;\
    private int mAliceHubLastShowTabId = Tab.INVALID_TAB_ID;\
    private long mAliceHubLastShowAttemptMs;\
    // Alice patch end 0079' "$path2"

sed -i '/^    public void showLayout(int layoutType, boolean animate) {$/a\
        // Alice patch start 0079\
        if (layoutType == LayoutType.HUB\
                \&\& animate\
                \&\& aliceShouldBlockHubShowForThumbnailCapture()) {\
            return;\
        }\
        // Alice patch end 0079\
' "$path2"

sed -i '/^    private void initHubLayout() {$/i\
    // Alice patch start 0079\
    private boolean aliceShouldBlockHubShowForThumbnailCapture() {\
        TabModelSelector selector = mTabModelSelectorSupplier.get();\
        Tab tab = selector != null ? selector.getCurrentTab() : null;\
        int tabId = tab != null ? tab.getId() : Tab.INVALID_TAB_ID;\
        if (mTabContentManager == null || tabId == Tab.INVALID_TAB_ID) {\
            mAliceHubCaptureGateTabId = Tab.INVALID_TAB_ID;\
            mAliceHubCaptureGateDeadlineMs = 0;\
            return false;\
        }\
\
        long now = SystemClock.elapsedRealtime();\
        boolean capturePending = mTabContentManager.isTabCaptureInFlight(tabId);\
        boolean hubTransitionRunning =\
                mHubLayout != null\
                        \&\& (mHubLayout.isStartingToShow()\
                                || mHubLayout.isStartingToHide());\
        boolean rapidReentry =\
                tabId == mAliceHubLastShowTabId\
                        \&\& mAliceHubLastShowAttemptMs != 0\
                        \&\& now - mAliceHubLastShowAttemptMs\
                                < ALICE_HUB_CAPTURE_GATE_TIMEOUT_MS;\
        if (!capturePending \&\& !hubTransitionRunning \&\& !rapidReentry) {\
            mAliceHubCaptureGateTabId = Tab.INVALID_TAB_ID;\
            mAliceHubCaptureGateDeadlineMs = 0;\
            mAliceHubLastShowTabId = tabId;\
            mAliceHubLastShowAttemptMs = now;\
            return false;\
        }\
\
        if (tabId != mAliceHubCaptureGateTabId) {\
            mAliceHubCaptureGateTabId = tabId;\
            mAliceHubCaptureGateDeadlineMs = now + ALICE_HUB_CAPTURE_GATE_TIMEOUT_MS;\
            return true;\
        }\
        if (now < mAliceHubCaptureGateDeadlineMs) return true;\
\
        mAliceHubLastShowTabId = tabId;\
        mAliceHubLastShowAttemptMs = now;\
        return false;\
    }\
    // Alice patch end 0079\
\
' "$path2"
