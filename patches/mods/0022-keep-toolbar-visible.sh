#!/bin/bash
# 工具栏滑动时保持显示，且不干扰手势本身

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/fullscreen/BrowserControlsManager.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/compositor/scene_layer/ToolbarSwipeSceneLayer.java"
path4="chrome/browser/android/compositor/scene_layer/toolbar_swipe_scene_layer.cc"
path5="chrome/browser/android/compositor/scene_layer/toolbar_swipe_scene_layer.h"

# 检测是否已应用
if grep -q 'Alice patch start 0022' "$path1"; then
    exit 100
fi

# A0) 默认普通 NTP 滑动时，Android 工具栏保持唯一的可见工具栏。
sed -i '/^    private @Nullable LayoutTab mToTab; \/\/ Set to mLeftTab or mRightTab or null if undetermined.$/a\
    // Alice patch start 0022\
    private boolean mAliceDisableCompositorToolbar;\
    private boolean mAliceHideControlView;\
    // Alice patch end 0022' "$path1"

sed -i '/^        NativePage nativePage = (currentTab != null) ? currentTab.getNativePage() : null;$/i\
        // Alice patch start 0022\
        Tab aliceSwipeSourceTab = model.getTabAtChecked(fromIndex);\
        mAliceDisableCompositorToolbar =\
                aliceSwipeSourceTab != null\
                        \&\& !aliceSwipeSourceTab.isIncognito()\
                        \&\& UrlUtilities.isNtpUrl(aliceSwipeSourceTab.getUrl());\
        if (mAliceDisableCompositorToolbar) {\
            if (mLeftToolbarOverlay != null) mLeftToolbarOverlay.setManualVisibility(false);\
            if (mRightToolbarOverlay != null) mRightToolbarOverlay.setManualVisibility(false);\
            if (mControlView != null \&\& mControlView.getVisibility() == View.VISIBLE) {\
                mAliceHideControlView = true;\
                mControlView.setVisibility(View.INVISIBLE);\
            }\
        }\
        // Alice patch end 0022' "$path1"

sed -i 's|^        layoutTab\.setShowToolbar(mMoveToolbar);$|        // Alice patch start 0022\n        layoutTab.setShowToolbar(mMoveToolbar \&\& !mAliceDisableCompositorToolbar);\n        // Alice patch end 0022|' "$path1"

sed -i '/^            if (mLeftToolbarOverlay != null) {$/,/^            }$/c\
            // Alice patch start 0022\
            if (mLeftToolbarOverlay != null) {\
                if (mAliceDisableCompositorToolbar) {\
                    mLeftToolbarOverlay.setManualVisibility(false);\
                } else {\
                    mLeftToolbarOverlay.setManualVisibility(true);\
                    mLeftToolbarOverlay.setAnonymize(mLeftTab != mFromTab);\
                    mLeftToolbarOverlay.setXOffset(leftX * dpToPx);\
                }\
            }\
            // Alice patch end 0022' "$path1"

sed -i '/^            if (mRightToolbarOverlay != null) {$/,/^            }$/c\
            // Alice patch start 0022\
            if (mRightToolbarOverlay != null) {\
                if (mAliceDisableCompositorToolbar) {\
                    mRightToolbarOverlay.setManualVisibility(false);\
                } else {\
                    mRightToolbarOverlay.setManualVisibility(true);\
                    mRightToolbarOverlay.setAnonymize(mRightTab != mFromTab);\
                    mRightToolbarOverlay.setXOffset(rightX * dpToPx);\
                }\
            }\
            // Alice patch end 0022' "$path1"

# A) 滑动期间不再申请 hiding token（也不动工具栏位置）
sed -i '/^    public boolean forceHideBrowserControlsAndroidView() {$/,/^    }$/c\
    public boolean forceHideBrowserControlsAndroidView() {\
        // Alice patch start 0022\
        // Alice: keep-toolbar-visible -- 滑动期间不强制隐藏 Android 工具栏，位置也不动。\
        return false;\
        // Alice patch end 0022\
    }\
\
    // Alice patch start 0022\
    private void restoreAliceControlView() {\
        if (!mAliceHideControlView) return;\
        if (mControlView != null) mControlView.setVisibility(View.VISIBLE);\
        mAliceHideControlView = false;\
    }\
    // Alice patch end 0022' "$path1"

sed -i '/^        super\.doneHiding();$/a\
        // Alice patch start 0022\
        restoreAliceControlView();\
        // Alice patch end 0022' "$path1"

sed -i '/^    private void init() {$/a\
        // Alice patch start 0022\
        restoreAliceControlView();\
        // Alice patch end 0022' "$path1"

sed -i '/^        super\.destroy();$/i\
        // Alice patch start 0022\
        restoreAliceControlView();\
        // Alice patch end 0022' "$path1"

# B) 全屏时隐藏 Android 工具栏。底置工具栏固定使用 Android view，
#    顶部工具栏继续使用 Chrome 原有的 compositor/Android 二选一逻辑。
sed -i 's|^        return !BrowserControlsUtils.drawControlsAsTexture(this);$|        // Alice patch start 0022\n        if (getFullscreenManager() != null \&\& getFullscreenManager().getPersistentFullscreenMode()) {\n            return false;\n        }\n        if (getControlsPosition() == ControlsPosition.BOTTOM) return true;\n        return !BrowserControlsUtils.drawControlsAsTexture(this);\n        // Alice patch end 0022|' "$path2"

# C) 切 Tab 时不再 transient show browser controls。这个调用会把 constraints
#    推到 SHOWN，并由 native 启动约 200ms 的 controls 动画。
sed -i '/^                mBrowserVisibilityDelegate.showControlsTransient();$/c\
                // Alice patch start 0022\
                // Tab switches must not force controls to SHOWN.\
                // Alice patch end 0022
' "$path2"

# D) 底置工具栏横滑时，让页面内容向下延伸 1px 覆盖工具栏顶部缝隙。
sed -i '/^    public void update(@Nullable LayoutTab tab, boolean isLeftTab, int backgroundColor) {$/,/^    }$/c\
    // Alice patch start 0022\
    public void update(\
            @Nullable LayoutTab tab,\
            boolean isLeftTab,\
            int backgroundColor,\
            float stretchDownHeight,\
            float stretchPx) {\
        final float dpToPx = mContext.getResources().getDisplayMetrics().density;\
\
        ToolbarSwipeSceneLayerJni.get()\
                .updateLayer(\
                        mNativePtr,\
                        tab != null ? tab.get(LayoutTab.TAB_ID) : Tab.INVALID_TAB_ID,\
                        isLeftTab,\
                        tab != null ? tab.get(LayoutTab.CAN_USE_LIVE_TEXTURE) : false,\
                        backgroundColor,\
                        tab != null ? tab.get(LayoutTab.X) * dpToPx : 0,\
                        tab != null ? tab.get(LayoutTab.Y) * dpToPx : 0,\
                        // Alice patch start 0022\
                        stretchDownHeight,\
                        stretchPx);\
        // Alice patch end 0022\
    }\
    // Alice patch end 0022' "$path3"

sed -i '/^        void updateLayer($/,/^                float y);$/c\
        // Alice patch start 0022\
        void updateLayer(\
                long nativeToolbarSwipeSceneLayer,\
                int id,\
                boolean leftTab,\
                boolean canUseLiveLayer,\
                int defaultBackgroundColor,\
                float x,\
                float y,\
                // Alice patch start 0022\
                float stretchDownHeight,\
                float stretchPx);\
        // Alice patch end 0022' "$path3"

sed -i 's|^            mSceneLayer\.update(mLeftTab, true, backgroundColor);$|            // Alice patch start 0022\n            float stretchDownHeight =\n                    mBrowserControlsVisibilityManager.getControlsPosition()\n                                    == BrowserControlsStateProvider.ControlsPosition.BOTTOM\n                            ? contentViewport.height()\n                                    * getContext().getResources().getDisplayMetrics().density\n                            : 0f;\n            float stretchPx =\n                    stretchDownHeight > 0\n                            ? TabContentManager.ALICE_SNAPSHOT_VERTICAL_STRETCH_PX\n                            : 0f;\n            // Alice patch end 0022\n            // Alice patch start 0022\n            mSceneLayer.update(\n                    mLeftTab, true, backgroundColor, stretchDownHeight, stretchPx);\n            // Alice patch end 0022|' "$path1"

sed -i 's|^            mSceneLayer\.update(mRightTab, false, backgroundColor);$|            // Alice patch start 0022\n            mSceneLayer.update(\n                    mRightTab, false, backgroundColor, stretchDownHeight, stretchPx);\n            // Alice patch end 0022|' "$path1"

sed -i '/^#include "ui\/gfx\/geometry\/size.h"$/a\
// Alice patch start 0022\
#include "ui/gfx/geometry/transform.h"\
// Alice patch end 0022' "$path4"

sed -i 's|^                                         float y) {$|                                         float y,\n                                         // Alice patch start 0022\n                                         float stretch_down_height,\n                                         float stretch_px) {\n  // Alice patch end 0022|' "$path4"

sed -i '/^  content_layer->layer()->SetPosition(gfx::PointF(x, y));$/a\
  // Alice patch start 0022\
  content_layer->layer()->SetTransformOrigin(gfx::PointF());\
  if (stretch_down_height > 0 \&\& stretch_px > 0) {\
    content_layer->layer()->SetTransform(gfx::Transform::MakeScale(\
        1.0f, (stretch_down_height + stretch_px) / stretch_down_height));\
  } else {\
    content_layer->layer()->SetTransform(gfx::Transform());\
  }\
  // Alice patch end 0022' "$path4"

sed -i 's|^                   float y);$|                   float y,\n                   // Alice patch start 0022\n                   float stretch_down_height,\n                   float stretch_px);\n  // Alice patch end 0022|' "$path5"
