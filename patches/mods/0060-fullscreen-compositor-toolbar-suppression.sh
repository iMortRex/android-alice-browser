#!/bin/bash
# 全屏 compositor 工具栏抑制：进入/退出全屏时隐藏残留层并刷新工具栏。

set -e

path1="chrome/browser/fullscreen/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenManager.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/FullscreenHtmlApiHandlerBase.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/tab/TabBrowserControlsConstraintsHelper.java"
path4="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarOverlayMediator.java"
path6="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/TopToolbarOverlayCoordinator.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path8="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"

# 检测是否已应用
if grep -q 'Alice patch start 0060' "$path1"; then
    exit 100
fi

# 增加全屏过渡共享状态：退出、持久全屏、进入动画和视口同步。
sed -i '/^public interface FullscreenManager {$/a\
    // Alice patch start 0060\
    final class FullscreenTransitionState {\
        private static volatile boolean sAliceExitingFullscreen;\
        private static volatile boolean sAlicePersistentFullscreen;\
        private static volatile boolean sAliceViewportSyncEnabled;\
        private static volatile boolean sAliceEnteringFullscreen;\
\
        public static void setExitingFullscreen(boolean exiting) {\
            sAliceExitingFullscreen = exiting;\
        }\
\
        public static boolean isExitingFullscreen() {\
            return sAliceExitingFullscreen;\
        }\
\
        public static void setPersistentFullscreen(boolean fullscreen) {\
            sAlicePersistentFullscreen = fullscreen;\
        }\
\
        public static boolean isPersistentFullscreen() {\
            return sAlicePersistentFullscreen;\
        }\
\
        public static void setViewportSyncEnabled(boolean enabled) {\
            sAliceViewportSyncEnabled = enabled;\
        }\
\
        public static boolean isViewportSyncEnabled() {\
            return sAliceViewportSyncEnabled;\
        }\
\
        public static void setEnteringFullscreen(boolean entering) {\
            sAliceEnteringFullscreen = entering;\
        }\
\
        public static boolean isEnteringFullscreen() {\
            return sAliceEnteringFullscreen;\
        }\
    }\
    // Alice patch end 0060\
\
' "$path1"

# 进入全屏时清除退出状态。
sed -i '/^                    enterPersistentFullscreenMode(options);$/i\
                    // Alice patch start 0060\
                    FullscreenManager.FullscreenTransitionState\
                            .setExitingFullscreen(false);\
                    // Alice patch end 0060\
' "$path2"

# 真正退出全屏时标记退出状态。
sed -i '/^        if (wasInPersistentFullscreenMode || mNotifyOnNextExit) {$/a\
            // Alice patch start 0060\
            FullscreenManager.FullscreenTransitionState.setExitingFullscreen(true);\
            // Alice patch end 0060\
' "$path2"

# 退出全屏时直接设置 SHOWN 且禁止动画。
sed -i '/^    private void resetExitFullscreenLayoutChangeListener(View contentView) {$/,/^    }$/s@^                            mTab, BrowserControlsState.SHOWN, true);$@                            // Alice patch start 0060\n                            mTab, BrowserControlsState.SHOWN, false);\n                            // Alice patch end 0060@' "$path2"

# 约束辅助器在全屏退出时使用 SHOWN 无动画。
sed -i '/^import org\.chromium\.chrome\.browser\.flags\.ChromeFeatureList;$/a\
// Alice patch start 0060\
import org.chromium.chrome.browser.fullscreen.FullscreenManager;\
// Alice patch end 0060\
' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^        int constraints = getConstraints();$/a\
        // Alice patch start 0060\
        if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()\
                \&\& current == BrowserControlsState.BOTH) {\
            constraints = BrowserControlsState.BOTH;\
        }\
        // Alice patch end 0060\
' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private void updateEnabledState() {$/,/^    }$/s@^        update(BrowserControlsState.BOTH, getConstraints() != BrowserControlsState.HIDDEN);$@        // Alice patch start 0060\n        if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\n            update(BrowserControlsState.SHOWN, false);\n        } else {\n            update(\n                    BrowserControlsState.BOTH,\n                    getConstraints() != BrowserControlsState.HIDDEN);\n        }\n        // Alice patch end 0060@' "$path3"

# BrowserControlsManager 在退出和隐藏时刷新可见性。
sed -i '/^        if (constraints == BrowserControlsState.SHOWN) {$/i\
            // Alice patch start 0060\
            if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
                scheduleVisibilityUpdate();\
                return;\
            }\
            if (constraints == BrowserControlsState.HIDDEN) {\
                scheduleVisibilityUpdate();\
            }\
            // Alice patch end 0060' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^        if (offsetOverridden()) return true;$/i\
        // Alice patch start 0060\
        if (getFullscreenManager() != null\
                \&\& getFullscreenManager().getPersistentFullscreenMode()) {\
            return false;\
        }\
        // Alice patch end 0060\
' "$path4"

# TopToolbarOverlay 在底置工具栏或全屏时保持隐藏。
sed -i '/^import org\.chromium\.chrome\.browser\.browser_controls\.BrowserControlsVisibilityManager;$/a\
// Alice patch start 0060\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0060\
' "$path5"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private void updateVisibility() {$/a\
        // Alice patch start 0060\
        if (mBrowserControlsVisibilityManager.getControlsPosition()\
                        == ControlsPosition.BOTTOM\
                || !AddressBarPreference.isToolbarConfiguredToShowOnTop()) {\
            mModel.set(TopToolbarOverlayProperties.VISIBLE, false);\
            return;\
        }\
        // Alice patch end 0060\
' "$path5"
# 修改对应源码以完成本补丁功能。
sed -i '/^    boolean shouldBeAttachedToTree() {$/a\
        // Alice patch start 0060\
        if (mBrowserControlsVisibilityManager.getControlsPosition()\
                == ControlsPosition.BOTTOM) {\
            return false;\
        }\
        // Alice patch end 0060\
' "$path5"
# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.chrome\.browser\.toolbar\.ToolbarProgressBar;$/a\
// Alice patch start 0060\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0060\
' "$path6"
# 修改对应源码以完成本补丁功能。
sed -i '/^                        \.with(TopToolbarOverlayProperties\.VISIBLE, true)$/c\
                        // Alice patch start 0060\
                        .with(TopToolbarOverlayProperties.VISIBLE, false)\
                        // Alice patch end 0060' "$path6"
# 修改对应源码以完成本补丁功能。
sed -i '/^    public boolean isSceneOverlayTreeShowing() {$/a\
        // Alice patch start 0060\
        if (!AddressBarPreference.isToolbarConfiguredToShowOnTop()) {\
            return false;\
        }\
        // Alice patch end 0060\
' "$path6"

# ToolbarManager 在全屏、Hub、底栏和焦点状态下同步 scene layer 抑制。
sed -i '/^                mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow || mIsUrlBarFocusedForSceneLayer);$/c\
                mIsXrFsm\
                        || mIsVerticalTabsHiddenDueToNarrow\
                        // Alice patch start 0060\
                        || (mIsUrlBarFocusedForSceneLayer\
                                \&\& !isAliceDefaultNtpBottomOmniboxFocused())\
                        || mFullscreenManager.getPersistentFullscreenMode()\
                        || FullscreenManager.FullscreenTransitionState\
                                .isExitingFullscreen()\
                        || mInTabSwitcherTransition\
                        || (mLayoutStateProvider != null\
                                \&\& mLayoutStateProvider.getActiveLayoutType()\
                                        == LayoutType.HUB));\
                        // Alice patch end 0060' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^                        mToolbar\.onTransitionEnd();$/a\
                        // Alice patch start 0060\
                        updateToolbarSceneLayerSuppression();\
                        if (mToolbarPositionController != null) {\
                            mToolbarPositionController.requestSearchToolbarSnapshotCapture();\
                        }\
                        // Alice patch end 0060' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^        mToolbar\.setContentAttached(layoutType == LayoutType\.BROWSING);$/a\
        // Alice patch start 0060\
        updateToolbarSceneLayerSuppression();\
        if (mToolbarPositionController != null) {\
            mToolbarPositionController.requestSearchToolbarSnapshotCapture();\
        }\
        // Alice patch end 0060' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^                                        false, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0060\
                        FullscreenManager.FullscreenTransitionState\
                                .setExitingFullscreen(false);\
                        updateToolbarSceneLayerSuppression();\
                        // Alice patch start 0042\
                        FullscreenManager.FullscreenTransitionState.setPersistentFullscreen(true);\
                        if (mToolbarPositionController != null) {\
                            mToolbarPositionController.refreshAliceNavigationBarBackground();\
                        }\
                        if (mToolbarPositionController != null) {\
                            mToolbarPositionController\
                                    .captureFullscreenNavigationBarHeight();\
                            mToolbarPositionController.setAliceFullscreenExitLayout(false);\
                        }\
                        if (FullscreenManager.FullscreenTransitionState\
                                .isEnteringFullscreen()) {\
                            mCompositorViewHolder.applyAliceFullscreenEntryViewport();\
                        }\
                        // Alice patch end 0042\
                        // Alice patch end 0060' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^                                        true, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0060\
                        FullscreenManager.FullscreenTransitionState\
                                .setExitingFullscreen(true);\
                        // Alice patch start 0042\
                        FullscreenManager.FullscreenTransitionState.setPersistentFullscreen(false);\
                        mAliceFullscreenExitReadyFrames = 0;\
                        if (mToolbarPositionController != null) {\
                            mToolbarPositionController.refreshAliceNavigationBarBackground();\
                        }\
                        if (mToolbarPositionController != null) {\
                            mCompositorViewHolder.setAliceFullscreenExitNavigationBarHeight(\
                                    mToolbarPositionController\
                                            .getAliceFullscreenCapturedNavigationBarHeight());\
                            mToolbarPositionController.setAliceFullscreenExitLayout(true);\
                        }\
                        mControlContainer.getView().post(\
                                () -> {\
                                    mBottomControlsStacker.requestLayerUpdate(false);\
                                    mCompositorViewHolder.applyAliceFullscreenExitViewport();\
                                });\
                        updateToolbarSceneLayerSuppression();\
                        // Alice patch end 0042\
                        refreshToolbarAfterFullscreen();\
                        // Alice patch end 0060' "$path7"

# 修改对应源码以完成本补丁功能。
sed -i '/^            applyMarginToFullscreenChildViews(view, topViewsTranslation, bottomMargin);$/{
n
c\
            // Alice patch start 0060\
            if (FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
                onViewportChanged();\
                requestRender();\
            } else {\
                tryUpdateControlsAndWebContentsSizing();\
            }\
            // Alice patch end 0060
}' "$path8"
