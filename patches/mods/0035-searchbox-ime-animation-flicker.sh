#!/bin/bash
# 搜索页弹出输入法时，地址栏先闪到最终位置，再回到底部和键盘一起上滑
# 使用 IME 动画每一帧的当前 inset 驱动工具栏，让工具栏底边始终贴着
# 输入法顶边，而不是停在屏幕底边或提前跳到最终位置。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/ToolbarPositionController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0035' "$path1"; then
    exit 100
fi

# 1) IME 动画进度需要的类型
sed -i '/^import androidx\.core\.view\.WindowInsetsCompat;$/a\
// Alice patch start 0035\
import androidx.core.view.WindowInsetsAnimationCompat;\
// Alice patch end 0035' "$path1"

sed -i '/^import java\.util\.function\.Supplier;$/i\
// Alice patch start 0035\
import java.util.List;\
// Alice patch end 0035' "$path1"

# 2) 动画期间缓存当前键盘高度，避免键盘 supplier 回调再次使用最终 inset
sed -i '/^    private final boolean mIsNtpCustomizationV2Enabled;$/a\
    // Alice patch start 0035\
    private boolean mImeAnimationInProgress;\
    private int mImeAnimationKeyboardHeight = -1;\
    private final InsetObserver.WindowInsetsAnimationListener mImeAnimationListener;\
    // Alice patch end 0035' "$path1"

# 3) 注册 IME 动画监听。收到第一个真实进度帧前不移动工具栏，
#    之后每个进度帧都用当前 IME 高度更新位置，始终跟随输入法顶边。
sed -i '/^        mKeyboardHeightSupplier\.addSyncObserverAndPostIfNonNull(mKeyboardHeightProgressBarCallback);$/a\
        // Alice patch start 0035\
        mImeAnimationListener =\
                new InsetObserver.WindowInsetsAnimationListener() {\
                    private @Nullable WindowInsetsAnimationCompat mCurrentAnimation;\
\
                    @Override\
                    public void onPrepare(WindowInsetsAnimationCompat animation) {\
                        if ((animation.getTypeMask() & WindowInsetsCompat.Type.ime()) == 0) {\
                            return;\
                        }\
                        mCurrentAnimation = animation;\
                        mImeAnimationInProgress = true;\
                        mImeAnimationKeyboardHeight = -1;\
                    }\
\
                    @Override\
                    public void onStart(\
                            WindowInsetsAnimationCompat animation,\
                            WindowInsetsAnimationCompat.BoundsCompat bounds) {}\
\
                    @Override\
                    public void onProgress(\
                            WindowInsetsCompat windowInsets,\
                            List<WindowInsetsAnimationCompat> runningAnimations) {\
                        if (mCurrentAnimation == null) return;\
                        mImeAnimationKeyboardHeight =\
                                Math.max(\
                                        0,\
                                        windowInsets\
                                                .getInsets(WindowInsetsCompat.Type.ime())\
                                                .bottom);\
                        updateImeLayerOffsets();\
                    }\
\
                    @Override\
                    public void onEnd(WindowInsetsAnimationCompat animation) {\
                        if (animation != mCurrentAnimation) return;\
                        mCurrentAnimation = null;\
                        mImeAnimationInProgress = false;\
                        mImeAnimationKeyboardHeight = 0;\
                        updateImeLayerOffsets();\
                    }\
                };\
        InsetObserver insetObserver = mWindowAndroid.getInsetObserver();\
        if (insetObserver != null) {\
            insetObserver.addWindowInsetsAnimationListener(mImeAnimationListener);\
        }\
        // Alice patch end 0035' "$path1"

# 4) 销毁时注销监听
sed -i '/^        mKeyboardHeightSupplier\.removeObserver(mKeyboardHeightProgressBarCallback);$/a\
        // Alice patch start 0035\
        InsetObserver insetObserver = mWindowAndroid.getInsetObserver();\
        if (insetObserver != null) {\
            insetObserver.removeWindowInsetsAnimationListener(mImeAnimationListener);\
        }\
        // Alice patch end 0035' "$path1"

# 5) 动画帧里使用绝对位移：搜索框底边 = 当前 IME 顶边。
#    不再从 layerYOffset 继续减，避免被现有底部偏移或重复回调带偏。
sed -i '/^                            mControlContainer\.getView()\.getRootView());$/a\
            // Alice patch start 0035\
            if (mImeAnimationInProgress) {\
                if (mImeAnimationKeyboardHeight < 0) return;\
                int aliceStatusBarHeight =\
                        windowInsetsCompat\
                                .getInsets(WindowInsetsCompat.Type.statusBars())\
                                .top;\
                int aliceWindowHeight = mWindowAndroid.getDisplay().getDisplayHeight();\
                int aliceNavigationBarHeight =\
                        windowInsetsCompat\
                                .getInsets(WindowInsetsCompat.Type.navigationBars())\
                                .bottom;\
                int aliceEffectiveKeyboardHeight =\
                        Math.max(\
                                mImeAnimationKeyboardHeight,\
                                aliceNavigationBarHeight);\
                mControlContainer.setMaxHeight(\
                        Math.max(\
                                0,\
                                aliceWindowHeight\
                                        - aliceEffectiveKeyboardHeight\
                                        - aliceStatusBarHeight));\
                int aliceTranslation = -aliceEffectiveKeyboardHeight;\
                viewForLayer.setTranslationY(aliceTranslation);\
                if (layer == mBottomToolbarLayer) {\
                    mBrowserControlsOffsetSupplier.set(aliceTranslation);\
                }\
                return;\
            }\
            // Alice patch end 0035' "$path1"

# 6) 动画开始和结束时同时校准工具栏与进度条位置
sed -i '/^    private void updateControlContainerHeight(int height) {$/,/^    }$/c\
    private void updateControlContainerHeight(int height) {\
        assert height >= 0;\
        mControlContainerHeight = height;\
        mBottomControlsStacker.requestLayerUpdate(false);\
    }\
\
    // Alice patch start 0035\
    private void updateImeLayerOffsets() {\
        updateViewOffset(mBottomToolbarLayer, mControlContainer.getView());\
        updateViewOffset(mProgressBarLayer, mToolbarProgressBarContainer);\
    }\
    // Alice patch end 0035' "$path1"

# 7) 全屏时隐藏 compositor 工具栏层，避免底置工具栏残留在视频画面上
sed -i 's@^                mIsXrFsm || mIsVerticalTabsHiddenDueToNarrow || mIsUrlBarFocusedForSceneLayer);$@                mIsXrFsm\n                        || mIsVerticalTabsHiddenDueToNarrow\n                        || mIsUrlBarFocusedForSceneLayer\n                        || mFullscreenManager.getPersistentFullscreenMode());@' "$path2"

# 进入全屏后立即刷新场景层抑制状态
sed -i '/^                                        false, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0035\
                        updateToolbarSceneLayerSuppression();\
                        // Alice patch end 0035' "$path2"

# 退出全屏后先应用最新系统栏 inset 并重排底部控件，再恢复工具栏场景层。
# 否则场景层会沿用全屏时的底部位置，直到旋转结束重新布局才避让导航栏。
sed -i '/^                                        true, mFullscreenHairlineToken);$/a\
                        // Alice patch start 0035\
                        refreshToolbarAfterFullscreen();\
                        // Alice patch end 0035' "$path2"

sed -i '/^    private void updateToolbarSceneLayerSuppression() {$/i\
    // Alice patch start 0035\
    private void refreshToolbarAfterFullscreen() {\
        View aliceControlContainer = mControlContainer.getView();\
        aliceControlContainer.postOnAnimation(\
                () -> {\
                    aliceControlContainer.requestApplyInsets();\
                    aliceControlContainer.requestLayout();\
                    mBottomControlsStacker.requestLayerUpdate(false);\
                    aliceControlContainer.postOnAnimation(\
                            ToolbarManager.this::updateToolbarSceneLayerSuppression);\
                });\
    }\
    // Alice patch end 0035\
' "$path2"
