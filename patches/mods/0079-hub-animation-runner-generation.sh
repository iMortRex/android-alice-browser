#!/bin/bash
# Hub 动画调度与缩略图捕获：
# 1) 异步 queueAnimation 只能启动创建它时的 runner。
# 2) 同一 Tab 的捕获请求共用一个 native readback，空 bitmap 回退到磁盘缩略图。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/hub/HubLayout.java"
path2="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"
path3="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubAnimationConstants.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start 0079' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# show() 的 next-layout 回调绑定本次 runner。
sed -i 's|^                containerView\.runOnNextLayout(this::queueAnimation);$|                // Alice patch start 0079\
                HubLayoutAnimationRunner aliceShowRunner =\
                        assumeNonNull(mCurrentAnimationRunner);\
                containerView.runOnNextLayout(() -> queueAnimation(aliceShowRunner));\
                // Alice patch end 0079|' "$path1"

# startHiding() 的两条 PostTask 都绑定本次 runner。
sed -i 's|^\( *\)PostTask\.postTask(TaskTraits\.UI_DEFAULT, this::queueAnimation);$|\1// Alice patch start 0079\n\1HubLayoutAnimationRunner aliceHideRunner =\n\1        assumeNonNull(mCurrentAnimationRunner);\n\1PostTask.postTask(\n\1        TaskTraits.UI_DEFAULT, () -> queueAnimation(aliceHideRunner));\n\1// Alice patch end 0079|' "$path1"

# 只允许当前 runner 且仍处于 INITIALIZING 时启动动画。
sed -i '/^    private void queueAnimation() {$/,/^    }$/c\
    // Alice patch start 0079\
    private void queueAnimation() {\
        queueAnimation(mCurrentAnimationRunner);\
    }\
\
    private void queueAnimation(@Nullable HubLayoutAnimationRunner animationRunner) {\
        if (animationRunner == null\
                || animationRunner != mCurrentAnimationRunner\
                || animationRunner.getAnimationState()\
                        != HubLayoutAnimationRunner.AnimationState.INITIALIZING) {\
            return;\
        }\
        animationRunner.runWithWaitForAnimatorTimeout(HUB_LAYOUT_TIMEOUT_MS);\
    }\
    // Alice patch end 0079' "$path1"

# Hub 正在显示或隐藏时忽略标签管理按钮点击，避免下一击强制结束当前动画。
sed -i '/^import org\.chromium\.chrome\.browser\.layouts\.LayoutStateProvider;$/a\
// Alice patch start 0079\
import org.chromium.chrome.browser.layouts.LayoutStateProvider.LayoutStateObserver;\
// Alice patch end 0079' "$path4"
sed -i '/^    private long mIntentHandlingTimeMs;$/i\
    // Alice patch start 0079\
    private static final long ALICE_HUB_BUTTON_GATE_COOLDOWN_MS = 20L;\
    private static final long ALICE_HUB_BUTTON_GATE_STUCK_TIMEOUT_MS = 1500L;\
    private long mAliceHubButtonTransitionStartMs;\
    private boolean mAliceHubButtonTransitionTimedOut;\
    private long mAliceHubButtonCooldownStartMs;\
    private final LayoutStateObserver mAliceHubButtonLayoutObserver =\
            new LayoutStateObserver() {\
                @Override\
                public void onFinishedShowing(@LayoutType int layoutType) {\
                    if (layoutType == LayoutType.HUB) {\
                        mAliceHubButtonCooldownStartMs = SystemClock.elapsedRealtime();\
                        mAliceHubButtonTransitionStartMs = 0;\
                        mAliceHubButtonTransitionTimedOut = false;\
                    }\
                }\
\
                @Override\
                public void onFinishedHiding(@LayoutType int layoutType) {\
                    if (layoutType == LayoutType.HUB) {\
                        mAliceHubButtonCooldownStartMs = SystemClock.elapsedRealtime();\
                        mAliceHubButtonTransitionStartMs = 0;\
                        mAliceHubButtonTransitionTimedOut = false;\
                    }\
                }\
            };\
    // Alice patch end 0079\
\
' "$path4"
sed -i '/^                mLayoutStateProviderSupplier\.set(mLayoutManager);$/a\
                // Alice patch start 0079\
                mLayoutManager.addObserver(mAliceHubButtonLayoutObserver);\
                // Alice patch end 0079' "$path4"
sed -i '/^        boolean isBottomBarEnabledOnGts =$/,/^        }$/c\
        // Alice patch start 0079\
        boolean aliceHubTransitionRunning =\
                mLayoutManager != null\
                        \&\& (mLayoutManager.isLayoutStartingToHide(LayoutType.HUB)\
                                || mLayoutManager.isLayoutStartingToShow(LayoutType.HUB));\
        long aliceNow = SystemClock.elapsedRealtime();\
        if (aliceHubTransitionRunning) {\
            if (mAliceHubButtonTransitionStartMs == 0) {\
                mAliceHubButtonTransitionStartMs = aliceNow;\
                mAliceHubButtonTransitionTimedOut = false;\
            }\
            if (!mAliceHubButtonTransitionTimedOut\
                    \&\& aliceNow - mAliceHubButtonTransitionStartMs\
                            >= ALICE_HUB_BUTTON_GATE_STUCK_TIMEOUT_MS) {\
                mAliceHubButtonTransitionTimedOut = true;\
            }\
            if (!mAliceHubButtonTransitionTimedOut) {\
                return;\
            }\
        }\
        boolean aliceHubCooldownActive =\
                mAliceHubButtonCooldownStartMs != 0\
                        \&\& aliceNow - mAliceHubButtonCooldownStartMs\
                                < ALICE_HUB_BUTTON_GATE_COOLDOWN_MS;\
        if (aliceHubCooldownActive) {\
            return;\
        }\
        // Alice patch end 0079\
\
        boolean isBottomBarEnabledOnGts =\
                BottomBarConfigUtils.shouldShowOnGts()\
                        \&\& BottomBarConfigUtils.isBottomBarEnabled(this);' "$path4"
sed -i '/^        ChromeAccessibilityUtil\.get()\.removeObserver(mLayoutManager);$/a\
        // Alice patch start 0079\
        mLayoutManager.removeObserver(mAliceHubButtonLayoutObserver);\
        // Alice patch end 0079' "$path4"

# 同一 Tab 的所有捕获请求共用一个 native readback。
sed -i '/^    private @Nullable Bitmap copyAliceCompositedThumbnail(Bitmap bitmap) {$/i\
    // Alice patch start 0079\
    private static class AliceCaptureWaiter {\
        final boolean returnBitmap;\
        final @Nullable Callback<@Nullable Bitmap> callback;\
\
        AliceCaptureWaiter(\
                boolean returnBitmap, @Nullable Callback<@Nullable Bitmap> callback) {\
            this.returnBitmap = returnBitmap;\
            this.callback = callback;\
        }\
    }\
    // Alice patch end 0079\
\
' "$path2"
sed -i '/^            mAlicePendingThumbnailRequests = new HashMap<>();$/a\
    // Alice patch start 0079\
    private final Map<Integer, List<AliceCaptureWaiter>> mAliceCaptureWaiters =\
            new HashMap<>();\
    // Alice patch end 0079' "$path2"

sed -i '/^    public void cacheTabThumbnailWithCallback($/,/^    }$/c\
    // Alice patch start 0079\
    public void cacheTabThumbnailWithCallback(\
            final Tab tab, boolean returnBitmap, @Nullable Callback<@Nullable Bitmap> callback) {\
        if (mNativeTabContentManager == 0 || !mSnapshotsEnabled) {\
            Callback.runNullSafe(callback, null);\
            return;\
        }\
\
        int tabId = tab.getId();\
        List<AliceCaptureWaiter> aliceWaiters = mAliceCaptureWaiters.get(tabId);\
        if (aliceWaiters != null) {\
            aliceWaiters.add(new AliceCaptureWaiter(returnBitmap, callback));\
            return;\
        }\
\
        aliceWaiters = new ArrayList<>();\
        aliceWaiters.add(new AliceCaptureWaiter(returnBitmap, callback));\
        mAliceCaptureWaiters.put(tabId, aliceWaiters);\
        captureTabThumbnailForAliceWaiters(tab, returnBitmap);\
    }\
\
    private void captureTabThumbnailForAliceWaiters(Tab tab, boolean returnBitmap) {\
        int tabId = tab.getId();\
        captureThumbnail(\
                tab,\
                returnBitmap,\
                (bitmap) -> {\
                    List<AliceCaptureWaiter> aliceWaiters =\
                            mAliceCaptureWaiters.remove(tabId);\
                    if (aliceWaiters == null) return;\
\
                    boolean aliceNeedsBitmap = false;\
                    for (AliceCaptureWaiter aliceWaiter : aliceWaiters) {\
                        if (aliceWaiter.returnBitmap \&\& aliceWaiter.callback != null) {\
                            aliceNeedsBitmap = true;\
                            break;\
                        }\
                    }\
                    if (bitmap == null \&\& aliceNeedsBitmap) {\
                        if (!returnBitmap) {\
                            mAliceCaptureWaiters.put(tabId, aliceWaiters);\
                            captureTabThumbnailForAliceWaiters(\
                                    tab, /* returnBitmap= */ true);\
                            return;\
                        }\
                        getEtc1TabThumbnailWithCallback(\
                                tabId,\
                                (cachedBitmap) ->\
                                        deliverAliceCaptureWaiters(\
                                                aliceWaiters, cachedBitmap));\
                        return;\
                    }\
\
                    deliverAliceCaptureWaiters(aliceWaiters, bitmap);\
                });\
    }\
\
    private void deliverAliceCaptureWaiters(\
            List<AliceCaptureWaiter> aliceWaiters, @Nullable Bitmap bitmap) {\
        for (AliceCaptureWaiter aliceWaiter : aliceWaiters) {\
            Callback.runNullSafe(\
                    aliceWaiter.callback,\
                    aliceWaiter.returnBitmap ? bitmap : null);\
        }\
    }\
    // Alice patch end 0079' "$path2"

# 标签移除时完成等待者；销毁时清空。
sed -i '/^    public void removeTabThumbnail(int tabId, boolean forceRemoval) {$/,/^    }$/s#^        mAliceCompositingTabIds\.remove(tabId);$#        mAliceCompositingTabIds.remove(tabId);\n        // Alice patch start 0079\n        List<AliceCaptureWaiter> aliceCaptureWaiters =\n                mAliceCaptureWaiters.remove(tabId);\n        if (aliceCaptureWaiters != null) {\n            deliverAliceCaptureWaiters(aliceCaptureWaiters, null);\n        }\n        // Alice patch end 0079#' "$path2"
sed -i '/^        mAliceCompositingTabIds.clear();$/a\
        // Alice patch start 0079\
        mAliceCaptureWaiters.clear();\
        // Alice patch end 0079' "$path2"

# 时间只作为异常兜底上限，不承担正常动画等待。
sed -i 's|^    public static final long HUB_LAYOUT_TIMEOUT_MS = 300L;$|    // Alice patch start 0079\
    public static final long HUB_LAYOUT_TIMEOUT_MS = 1000L;\
    // Alice patch end 0079|' "$path3"
