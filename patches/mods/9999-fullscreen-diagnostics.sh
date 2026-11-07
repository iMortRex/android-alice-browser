#!/bin/bash
# 全屏退出与导航栏避让诊断日志。
# 日志 tag: Alice9999

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"
path2="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/compositor/CompositorViewHolder.java"
path4="chrome/browser/browser_controls/android/java/src/org/chromium/chrome/browser/browser_controls/BottomControlsStacker.java"

if grep -q 'Alice patch start 9999' "$path1"; then
    exit 100
fi

# ToolbarManager: 全屏进入、退出、退出完成回调。
sed -i '/^    public void onEnterFullscreen(Tab tab, FullscreenOptions options) {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "enterFullscreen persistent=" + FullscreenManager.FullscreenTransitionState\
                        .isPersistentFullscreen()\
                        + " entering=" + FullscreenManager.FullscreenTransitionState\
                                .isEnteringFullscreen()\
                        + " exiting=" + FullscreenManager.FullscreenTransitionState\
                                .isExitingFullscreen()\
                        + " viewportSync=" + FullscreenManager.FullscreenTransitionState\
                                .isViewportSyncEnabled()\
                        + " controlsH=" + mControlContainer.getView().getHeight()\
                        + " controlsTransY=" + mControlContainer.getView().getTranslationY()\
                        + " bottomControlsH=" + mBottomControlsStacker\
                                .getBrowserControls().getBottomControlsHeight());\
        // Alice patch end 9999' "$path1"

sed -i '/^    public void onExitFullscreen(Tab tab) {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "exitFullscreen persistent=" + FullscreenManager.FullscreenTransitionState\
                        .isPersistentFullscreen()\
                        + " entering=" + FullscreenManager.FullscreenTransitionState\
                                .isEnteringFullscreen()\
                        + " exiting=" + FullscreenManager.FullscreenTransitionState\
                                .isExitingFullscreen()\
                        + " viewportSync=" + FullscreenManager.FullscreenTransitionState\
                                .isViewportSyncEnabled()\
                        + " controlsH=" + mControlContainer.getView().getHeight()\
                        + " controlsTransY=" + mControlContainer.getView().getTranslationY()\
                        + " bottomControlsH=" + mBottomControlsStacker\
                                .getBrowserControls().getBottomControlsHeight());\
        // Alice patch end 9999' "$path1"

sed -i '/^    private void finishAliceFullscreenToolbarExit() {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "finishExit persistent=" + FullscreenManager.FullscreenTransitionState\
                        .isPersistentFullscreen()\
                        + " entering=" + FullscreenManager.FullscreenTransitionState\
                                .isEnteringFullscreen()\
                        + " exiting=" + FullscreenManager.FullscreenTransitionState\
                                .isExitingFullscreen()\
                        + " controlsH=" + mControlContainer.getView().getHeight()\
                        + " controlsTransY=" + mControlContainer.getView().getTranslationY());\
        // Alice patch end 9999' "$path1"

sed -i '/^    private void refreshToolbarAfterFullscreen() {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "refreshAfterFullscreen exiting=" + FullscreenManager.FullscreenTransitionState\
                        .isExitingFullscreen()\
                        + " viewportSync=" + FullscreenManager.FullscreenTransitionState\
                                .isViewportSyncEnabled()\
                        + " controlsH=" + mControlContainer.getView().getHeight()\
                        + " controlsTransY=" + mControlContainer.getView().getTranslationY());\
        // Alice patch end 9999' "$path1"

# ToolbarPositionController: 退出布局、背景显隐和图层 offset。
sed -i '/^    void setAliceFullscreenExitLayout(boolean exiting) {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "setExitLayout requested=" + exiting\
                        + " position=" + mCurrentPosition.get()\
                        + " navH=" + getNavigationBarHeight()\
                        + " navIgnoringVisibility=" + getFullscreenSnapshotNavigationBarHeight());\
        // Alice patch end 9999' "$path2"

sed -i '/^    void setAliceFullscreenExitLayout(boolean exiting) {$/,/^    }$/s|^        mBottomControlsStacker.requestLayerUpdate(false);$|        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "setExitLayout applied bottomMargin=" + aliceLayoutParams.bottomMargin\
                        + " controlsTransY=" + mControlContainer.getView().getTranslationY()\
                        + " controlsVisibility=" + mControlContainer.getView().getVisibility());\
        // Alice patch end 9999\
        mBottomControlsStacker.requestLayerUpdate(false);|' "$path2"

sed -i '/^    private void updateNavigationBarBackground() {$/a\
        // Alice patch start 9999\
        if (FullscreenManager.FullscreenTransitionState.isPersistentFullscreen()\
                || FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
            View alice9999Background = mNavigationBarBackground;\
            View alice9999Container = mNavigationBarBackgroundContainer;\
            View alice9999Toolbar =\
                    mControlContainer.getView().findViewById(R.id.toolbar_container);\
            org.chromium.base.Log.i(\
                    "Alice9999",\
                    "navBackground persistent=" + FullscreenManager.FullscreenTransitionState\
                            .isPersistentFullscreen()\
                            + " exiting=" + FullscreenManager.FullscreenTransitionState\
                                    .isExitingFullscreen()\
                            + " layer=" + mLayerVisibility\
                            + " navH=" + getNavigationBarHeight()\
                            + " alpha=" + mAliceTabSwitcherBackgroundAlpha\
                            + " bg=" + (alice9999Background == null\
                                    ? "null"\
                                    : ("vis=" + alice9999Background.getVisibility()\
                                            + ",alpha=" + alice9999Background.getAlpha()\
                                            + ",z=" + alice9999Background.getTranslationZ()))\
                            + " container=" + (alice9999Container == null\
                                    ? "null"\
                                    : ("vis=" + alice9999Container.getVisibility()\
                                            + ",z=" + alice9999Container.getTranslationZ()\
                                            + ",h=" + alice9999Container.getHeight()))\
                            + " toolbar=" + (alice9999Toolbar == null\
                                    ? "null"\
                                    : ("vis=" + alice9999Toolbar.getVisibility()\
                                            + ",h=" + alice9999Toolbar.getHeight())));\
        }\
        // Alice patch end 9999' "$path2"

sed -i '/^        viewForLayer\.setTranslationY(layerYOffset);$/i\
        // Alice patch start 9999\
        if (layer == mBottomToolbarLayer\
                \&\& FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
            org.chromium.base.Log.i(\
                    "Alice9999",\
                    "toolbarOffset exiting=true layer=" + mLayerVisibility\
                            + " layerYOffset=" + layerYOffset\
                            + " position=" + mCurrentPosition.get()\
                            + " navH=" + getNavigationBarHeight()\
                            + " controlTransY=" + viewForLayer.getTranslationY());\
        }\
        // Alice patch end 9999\
' "$path2"

# CompositorViewHolder: 网页高度、视口补偿和退出完成。
sed -i '/^        int webContentsHeight = height - verticalViewportInsets;$/a\
        // Alice patch start 9999\
        if (FullscreenManager.FullscreenTransitionState.isPersistentFullscreen()\
                || FullscreenManager.FullscreenTransitionState.isExitingFullscreen()) {\
            org.chromium.base.Log.i(\
                    "Alice9999",\
                    "webContentsSize persistent=" + FullscreenManager.FullscreenTransitionState\
                            .isPersistentFullscreen()\
                            + " exiting=" + FullscreenManager.FullscreenTransitionState\
                                    .isExitingFullscreen()\
                            + " entering=" + FullscreenManager.FullscreenTransitionState\
                                    .isEnteringFullscreen()\
                            + " viewportSync=" + FullscreenManager.FullscreenTransitionState\
                                    .isViewportSyncEnabled()\
                            + " height=" + height\
                            + " webHeight=" + webContentsHeight\
                            + " verticalInsets=" + verticalViewportInsets\
                            + " topInset=" + aliceTopControlsInset\
                            + " bottomInset=" + aliceBottomControlsInset\
                            + " navInset=" + mAliceNavigationBarInset\
                            + " frozenNavH=" + mAliceExitFrozenNavigationBarHeight);\
        }\
        // Alice patch end 9999' "$path3"

sed -i '/^    public void applyAliceFullscreenExitViewport() {$/a\
        // Alice patch start 9999\
        View alice9999ContentView = getContentView();\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "applyExitViewport viewportSync=" + FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()\
                        + " pending=" + mAliceExitViewportPending\
                        + " frozenNavH=" + mAliceExitFrozenNavigationBarHeight\
                        + " contentH=" + (alice9999ContentView == null\
                                ? -1\
                                : alice9999ContentView.getHeight()));\
        // Alice patch end 9999' "$path3"

sed -i '/^    public void finishAliceFullscreenExit() {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "finishWebExit viewportSync=" + FullscreenManager.FullscreenTransitionState\
                        .isViewportSyncEnabled()\
                        + " exitPending=" + mAliceExitViewportPending\
                        + " frozenNavH=" + mAliceExitFrozenNavigationBarHeight);\
        // Alice patch end 9999' "$path3"

# BottomControlsStacker: 导航栏 chin 是否被计入底部控件高度。
sed -i '/^    private void updateBrowserControlsHeight(boolean animate) {$/a\
        // Alice patch start 9999\
        org.chromium.base.Log.i(\
                "Alice9999",\
                "bottomControlsHeight exitingFullscreen=" + mAliceExitingFullscreen\
                        + " totalH=" + mTotalHeight\
                        + " totalMinH=" + mTotalMinHeight\
                        + " lastChinH=" + mAliceLastChinHeight);\
        // Alice patch end 9999' "$path4"

