#!/bin/bash
# 禁用 mini origin bar；输入法显示或收起时始终保留完整工具栏

# # 1) 使用 ToolbarPositionController 已有的 hiding token 管理方式
# sed -i '/^import org\.chromium\.ui\.util\.CommonOnLayoutChangeListeners;$/a\
# // Alice patch start 0023\
# import org.chromium.ui.util.TokenHolder;\
# // Alice patch end 0023' "$path1"

# sed -i '/^    private boolean mShowingMiniOriginBar;$/a\
#     // Alice patch start 0023\
#     private int mMiniOriginControlsHidingToken = TokenHolder.INVALID_TOKEN;\
#     // Alice patch end 0023' "$path1"

# # 2) mini bar 进入显示态时改为隐藏完整工具栏和 compositor 层。
# #    不改 control container 高度，避免绕过 BrowserControlsSizer 的高度记账。
# sed -i '/^    private void showMiniOriginBar() {$/,/^    }$/c\
#     private void showMiniOriginBar() {\
#         // Alice patch start 0023\
#         mShowingMiniOriginBar = true;\
#         mSuppressToolbarSceneLayerSupplier.set(true);\
#         mMiniOriginControlsHidingToken =\
#                 mBrowserControlsSizer.hideAndroidControlsAndClearOldToken(\
#                         mMiniOriginControlsHidingToken);\
#         // Alice patch end 0023\
#     }' "$path1"

# # 3) mini bar 退出显示态时释放 token，并恢复完整工具栏高度。
# sed -i '/^    private void hideMiniOriginBar() {$/,/^    }$/c\
#     private void hideMiniOriginBar() {\
#         // Alice patch start 0023\
#         mShowingMiniOriginBar = false;\
#         mSuppressToolbarSceneLayerSupplier.set(true);\
#         setMinimizationProgress(0.0f);\
#         mLocationBar.setShowOriginOnly(false);\
#         mLocationBar.setShowStatusIconForSecureOrigins(true);\
#         mLocationBar.setMiniOriginMode(false);\
#         mControlContainer.toggleLocationBarOnlyMode(false);\
#         mControlContainer.mutateLayoutParams().height = LayoutParams.WRAP_CONTENT;\
#         var locationBarView = mLocationBar.getContainerView();\
#         locationBarView.setLayoutParams(mDefaultLocationBarLayoutParams);\
#         locationBarView.setPadding(\
#                 locationBarView.getPaddingLeft(),\
#                 locationBarView.getPaddingTop(),\
#                 mDefaultLocationBarRightPadding,\
#                 locationBarView.getPaddingBottom());\
#         mLocationBar.setUrlBarUsesSmallText(false);\
#         // 先恢复真实 Android 工具栏内容并显示，compositor 层继续抑制；\
#         // 两个动画帧后再恢复 compositor，避免空纹理或主题背景抢先显示。\
#         mControlContainer.doSynchronousLayout(/* forceCaptureAfterLayout= */ true);\
#         if (mMiniOriginControlsHidingToken != TokenHolder.INVALID_TOKEN) {\
#             mBrowserControlsSizer.releaseAndroidControlsHidingToken(\
#                     mMiniOriginControlsHidingToken);\
#             mMiniOriginControlsHidingToken = TokenHolder.INVALID_TOKEN;\
#         }\
#         mControlContainer.getView().postOnAnimation(\
#                 () -> mControlContainer.getView().postOnAnimation(\
#                         () -> mSuppressToolbarSceneLayerSupplier.set(false)));\
#         // Alice patch end 0023\
#     }' "$path1"

# # 4) 控制器销毁时确保不会遗留工具栏隐藏 token
# sed -i '/^    public void destroy() {$/a\
#         // Alice patch start 0023\
#         if (mMiniOriginControlsHidingToken != TokenHolder.INVALID_TOKEN) {\
#             mBrowserControlsSizer.releaseAndroidControlsHidingToken(\
#                     mMiniOriginControlsHidingToken);\
#             mMiniOriginControlsHidingToken = TokenHolder.INVALID_TOKEN;\
#         }\
#         // Alice patch end 0023' "$path1"

# # 5) 禁止 mini bar 的缩放和横向位移动画，隐藏期间只做整体显隐。
# #    这样键盘收起后恢复的是原始完整工具栏，不会残留 0.75 缩放或平移。
# sed -i '/^    private void applyCurrentMinimizationProgress() {$/a\
#         // Alice patch start 0023\
#         if (true) return;\
#         // Alice patch end 0023' "$path1"

# # 6) mini bar 动画结束时保持 compositor 抑制；恢复顺序由 hideMiniOriginBar()
# #    在真实 Android 工具栏完成布局后显式控制。
# sed -i 's@^            mSuppressToolbarSceneLayerSupplier\.set(mShowingMiniOriginBar\.getAsBoolean());$@            // Alice patch start 0023\n            mSuppressToolbarSceneLayerSupplier.set(true);\n            // Alice patch end 0023@' "$path1"

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/MiniOriginBarController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0023' "$path1"; then
    exit 100
fi

# mini origin 状态机始终停留在 NOT_READY，表单聚焦和输入法事件都不会改变
# 地址栏尺寸、缩放、位置或工具栏可见性。
sed -i '/^    private @MiniOriginState int getNewMiniOriginState(@MiniOriginEvent int miniOriginEvent) {$/,/^    }$/c\
    private @MiniOriginState int getNewMiniOriginState(@MiniOriginEvent int miniOriginEvent) {\
        // Alice patch start 0023\
        return MiniOriginState.NOT_READY;\
        // Alice patch end 0023\
    }' "$path1"

# 状态转换本身也不再执行，避免任何旧状态进入 mini origin 动画。
sed -i '/^    private void transitionToNewState(@MiniOriginState int newMiniOriginState) {$/,/^    }$/c\
    private void transitionToNewState(@MiniOriginState int newMiniOriginState) {\
        // Alice patch start 0023\
        // Mini origin is disabled; the normal toolbar never transitions.\
        // Alice patch end 0023\
    }' "$path1"

# IME animation listener 仅在这里被允许启动。直接返回 false，
# 可阻止 controlContainerTranslationSupplier 被逐帧写入键盘位移。
sed -i '/^    private boolean waitingForImeAnimationToStart() {$/,/^    }$/c\
    private boolean waitingForImeAnimationToStart() {\
        // Alice patch start 0023\
        return false;\
        // Alice patch end 0023\
    }' "$path1"

# 不创建 MiniOriginBarController，避免注册 IME listener、layout listener
# 或写入 controlContainerTranslationSupplier。
sed -i '/^        mMiniOriginBarController =$/,/^                        this::isUrlBarFocused);$/c\
        // Alice patch start 0023\
        // Mini origin is disabled; keep the normal bottom toolbar controller-free.\
        mMiniOriginBarController = null;\
        // Alice patch end 0023' "$path2"
