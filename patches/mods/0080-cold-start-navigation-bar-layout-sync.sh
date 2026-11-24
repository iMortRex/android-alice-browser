#!/bin/bash
# 导航栏运行时布局同步：系统导航栏 inset 或工具栏容器布局变化时，
# 同步模拟导航栏、底置工具栏偏移和 WebContents viewport。

set -e

path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"

if grep -q 'Alice patch start 0080' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 系统导航栏不可见时不能继续使用 chin 的缓存高度，否则隐藏后的旧导航栏
# 区域仍会覆盖底置工具栏。
sed -i '/^    private int getNavigationBarHeight() {$/,/^    }$/ s|^        \/\/ Alice patch end 0057$|&\
        // Alice patch start 0080\
        WindowInsetsCompat aliceNavigationBarVisibilityInsets =\
                androidx.core.view.ViewCompat.getRootWindowInsets(aliceRoot);\
        if (aliceNavigationBarVisibilityInsets != null\
                \&\& !aliceNavigationBarVisibilityInsets.isVisible(\
                        WindowInsetsCompat.Type.navigationBars())\
                \&\& !mKeyboardVisibilityDelegate.isKeyboardShowing(aliceRoot)\
                \&\& !FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()) {\
            return 0;\
        }\
        // Alice patch end 0080|' "$path1"

sed -i '/^    private int mNavigationBarBackgroundColor = Integer.MIN_VALUE;$/a\
    // Alice patch start 0080\
    private boolean mAliceNavigationBarLayoutSyncPosted;\
    private boolean mAliceDestroyed;\
    private int mAliceLastObservedNavigationBarInset = Integer.MIN_VALUE;\
    private boolean mAliceLastNavigationBarsVisible;\
    private final InsetObserver.WindowInsetObserver mAliceNavigationBarInsetObserver =\
            new InsetObserver.WindowInsetObserver() {\
                @Override\
                public void onInsetChanged() {\
                    onAliceNavigationBarInsetsChanged();\
                }\
            };\
    private final View.OnLayoutChangeListener mAliceNavigationBarLayoutListener =\
            new View.OnLayoutChangeListener() {\
                @Override\
                public void onLayoutChange(\
                        View view,\
                        int left,\
                        int top,\
                        int right,\
                        int bottom,\
                        int oldLeft,\
                        int oldTop,\
                        int oldRight,\
                        int oldBottom) {\
                    scheduleAliceNavigationBarLayoutSync();\
                }\
            };\
    // Alice patch end 0080' "$path1"

sed -i '/^            updateCurrentPosition(\/\* prefStateChanged= \*\/ true);$/a\
            // Alice patch start 0080\
            scheduleAliceNavigationBarLayoutSync();\
            // Alice patch end 0080' "$path1"

sed -i '/^                \.postOnAnimation(ToolbarPositionController.this::updateNavigationBarBackground);$/a\
        // Alice patch start 0080\
        InsetObserver aliceNavigationBarInsetObserver =\
                mWindowAndroid.getInsetObserver();\
        if (aliceNavigationBarInsetObserver != null) {\
            aliceNavigationBarInsetObserver.addObserver(\
                    mAliceNavigationBarInsetObserver);\
        }\
        mControlContainer\
                .getView()\
                .addOnLayoutChangeListener(mAliceNavigationBarLayoutListener);\
        scheduleAliceNavigationBarLayoutSync();\
        // Alice patch end 0080' "$path1"

sed -i '/^        mControlContainer.removeTouchEventObserver(mToolbarTouchObserver);$/a\
        // Alice patch start 0080\
        mAliceDestroyed = true;\
        mControlContainer\
                .getView()\
                .removeOnLayoutChangeListener(mAliceNavigationBarLayoutListener);\
        InsetObserver aliceNavigationBarInsetObserver =\
                mWindowAndroid.getInsetObserver();\
        if (aliceNavigationBarInsetObserver != null) {\
            aliceNavigationBarInsetObserver.removeObserver(\
                    mAliceNavigationBarInsetObserver);\
        }\
        // Alice patch end 0080' "$path1"

sed -i '/^    private void updateNavigationBarBackground() {$/i\
    // Alice patch start 0080\
    private void onAliceNavigationBarInsetsChanged() {\
        WindowInsetsCompat aliceInsets =\
                androidx.core.view.ViewCompat.getRootWindowInsets(\
                        mControlContainer.getView());\
        if (aliceInsets == null) return;\
        int aliceNavigationBarInset =\
                aliceInsets\
                        .getInsets(\
                                WindowInsetsCompat.Type.navigationBars())\
                        .bottom;\
        boolean aliceNavigationBarsVisible =\
                aliceInsets.isVisible(\
                        WindowInsetsCompat.Type.navigationBars());\
        if (aliceNavigationBarInset\
                        == mAliceLastObservedNavigationBarInset\
                \&\& aliceNavigationBarsVisible\
                        == mAliceLastNavigationBarsVisible) {\
            return;\
        }\
        mAliceLastObservedNavigationBarInset =\
                aliceNavigationBarInset;\
        mAliceLastNavigationBarsVisible =\
                aliceNavigationBarsVisible;\
        mControlContainer.getView().requestApplyInsets();\
        mControlContainer.getView().requestLayout();\
        scheduleAliceNavigationBarLayoutSync();\
    }\
\
    private void scheduleAliceNavigationBarLayoutSync() {\
        if (mAliceDestroyed || mAliceNavigationBarLayoutSyncPosted) return;\
        View aliceToolbarView = mControlContainer.getView();\
        mAliceNavigationBarLayoutSyncPosted = true;\
        aliceToolbarView.postOnAnimation(\
                () -> {\
                    mAliceNavigationBarLayoutSyncPosted = false;\
                    if (mAliceDestroyed) return;\
                    updateNavigationBarBackground();\
                    mBottomControlsStacker.requestLayerUpdate(false);\
                    updateImeLayerOffsets();\
                });\
    }\
    // Alice patch end 0080\
\
' "$path1"

sed -i '/^import org\.chromium\.ui\.base\.WindowAndroid;$/a\
// Alice patch start 0080\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0080' "$path2"

sed -i '/^    private boolean mControlsResizeView;$/a\
    // Alice patch start 0080\
    private @Nullable InsetObserver mAliceViewportInsetObserver;\
    private int mAliceLastObservedNavigationBarInset = Integer.MIN_VALUE;\
    private boolean mAliceLastNavigationBarsVisible;\
    private boolean mAliceNavigationBarViewportSyncPosted;\
    private boolean mAliceShutDown;\
    private final InsetObserver.WindowInsetObserver mAliceViewportInsetObserverCallback =\
            new InsetObserver.WindowInsetObserver() {\
                @Override\
                public void onInsetChanged() {\
                    onAliceViewportWindowInsetsChanged();\
                }\
            };\
    // Alice patch end 0080' "$path2"

sed -i '/^    private void handleWindowInsetChanged() {$/i\
    // Alice patch start 0080\
    private void onAliceViewportWindowInsetsChanged() {\
        WindowInsetsCompat aliceInsets =\
                ViewCompat.getRootWindowInsets(getRootView());\
        if (aliceInsets == null) return;\
        int aliceNavigationBarInset =\
                aliceInsets\
                        .getInsets(\
                                WindowInsetsCompat.Type.navigationBars())\
                        .bottom;\
        boolean aliceNavigationBarsVisible =\
                aliceInsets.isVisible(\
                        WindowInsetsCompat.Type.navigationBars());\
        if (aliceNavigationBarInset\
                        == mAliceLastObservedNavigationBarInset\
                \&\& aliceNavigationBarsVisible\
                        == mAliceLastNavigationBarsVisible) {\
            return;\
        }\
        mAliceLastObservedNavigationBarInset =\
                aliceNavigationBarInset;\
        mAliceLastNavigationBarsVisible =\
                aliceNavigationBarsVisible;\
        if (mAliceShutDown || mAliceNavigationBarViewportSyncPosted) return;\
        mAliceNavigationBarViewportSyncPosted = true;\
        postOnAnimation(\
                () -> {\
                    mAliceNavigationBarViewportSyncPosted = false;\
                    if (mAliceShutDown) return;\
                    onViewportChanged();\
                    tryUpdateControlsAndWebContentsSizing();\
                    updateWebContentsSize(getCurrentTab());\
                    requestRender();\
                });\
    }\
    // Alice patch end 0080\
\
' "$path2"

sed -i '/^        mCompositorView\.initNativeCompositor(windowAndroid, tabContentManager);$/a\
        // Alice patch start 0080\
        mAliceShutDown = false;\
        mAliceViewportInsetObserver = windowAndroid.getInsetObserver();\
        if (mAliceViewportInsetObserver != null) {\
            mAliceViewportInsetObserver.addObserver(\
                    mAliceViewportInsetObserverCallback);\
        }\
        // Alice patch end 0080' "$path2"

sed -i '/^        mCompositorView\.shutDown();$/i\
        // Alice patch start 0080\
        mAliceShutDown = true;\
        if (mAliceViewportInsetObserver != null) {\
            mAliceViewportInsetObserver.removeObserver(\
                    mAliceViewportInsetObserverCallback);\
            mAliceViewportInsetObserver = null;\
        }\
        // Alice patch end 0080' "$path2"
