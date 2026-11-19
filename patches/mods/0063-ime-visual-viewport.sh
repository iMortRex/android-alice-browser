#!/bin/bash
# IME visual viewport：逐帧同步 Android WebContents、Blink 和 compositor 视口。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"

# 检测是否已应用
if grep -q 'Alice patch start 0063' "$path1"; then
    exit 100
fi

# IME 动画逐帧更新 Blink inner visual viewport。抬升量从 IME 高度中扣除
#     底部工具栏和导航栏，并以物理像素原样传给 Blink。
#     同一个动画源驱动 Blink 内部视口，不再平移整个网页 View。
# 补充 IME 动画使用的 List import。
sed -i '/^import org\.chromium\.ui\.dragdrop\.DragStateTracker;$/a\
// Alice patch start 0063\
import java.util.List;\
// Alice patch end 0063' "$path1"

# 补充 MonotonicObservableSupplier import。
sed -i '/^import org\.chromium\.base\.Callback;$/i\
// Alice patch start 0063\
import org.chromium.base.supplier.MonotonicObservableSupplier;\
// Alice patch end 0063' "$path1"

# 补充 Activity import。
sed -i '/^import android\.util\.SparseArray;$/i\
// Alice patch start 0063\
import android.app.Activity;\
// Alice patch end 0063' "$path1"

# 补充 WindowManager import。
sed -i '/^import android\.view\.autofill\.AutofillValue;$/a\
// Alice patch start 0063\
import android.view.WindowManager;\
// Alice patch end 0063' "$path1"

# 补充 View import。
sed -i '/^import android\.util\.SparseArray;$/a\
// Alice patch start 0063\
import android.view.View;\
// Alice patch end 0063' "$path1"

# 补充 androidx insets 动画类型 import。
sed -i '/^import org\.chromium\.base\.Callback;$/i\
// Alice patch start 0063\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0063' "$path1"

# 补充 Content 层 ImeAdapter、WebContents 和 observer import。
sed -i '/^import org\.chromium\.content_public\.browser\.ContentFeatureMap;$/a\
// Alice patch start 0063\
import org.chromium.content_public.browser.ImeAdapter;\
import org.chromium.content_public.browser.WebContents;\
import org.chromium.content_public.browser.WebContentsObserver;\
// Alice patch end 0063' "$path1"

# 补充预览页协调器 import，用于判断是否处于预览页。
sed -i '/^import org\.chromium\.chrome\.R;$/a\
// Alice patch start 0063\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinator;\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinatorSupplier;\
// Alice patch end 0063' "$path1"

# 初始化 Tab 时注册 WebContents 焦点观察器。
sed -i '/^        mTab = (TabImpl) tab;$/a\
        // Alice patch start 0063\
        // Register the WebContents focus gate.\
        attachAliceWebContentsObserver();\
        // Alice patch end 0063' "$path1"

# 补充 InsetObserver import。
sed -i '/^import org\.chromium\.ui\.dragdrop\.DragStateTracker;$/a\
// Alice patch start 0063\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0063' "$path1"

# 增加 IME 动画监听状态、焦点门控和辅助方法。
sed -i '/^    private final Callback<ViewportInsets> mInsetObserver = _ -> updateVisualViewportBottomInset();$/a\
    // Alice patch start 0063\
    private @Nullable InsetObserver mAliceImeInsetObserver;\
    private @Nullable WindowAndroid mAliceImeWindowAndroid;\
    private boolean mAliceImeAnimationActive;\
    private boolean mAliceLiftForFocusedInput;\
    private int mAliceLastImeHeightPx;\
    private final int[] mAliceTmpLocation = new int[2];\
    private @Nullable WebContentsObserver mAliceWebContentsObserver;\
    private final WindowAndroid.ActivityStateObserver mAliceActivityStateObserver =\
            new WindowAndroid.ActivityStateObserver() {\
                @Override\
                public void onActivityPaused() {\
                    resetAliceImeViewportTranslation();\
                }\
\
                @Override\
                public void onActivityTopResumedChanged(boolean isTopResumedActivity) {\
                    if (!isTopResumedActivity) resetAliceImeViewportTranslation();\
                }\
            };\
    private final InsetObserver.WindowInsetsAnimationListener\
            mAliceImeAnimationListener =\
                    new InsetObserver.WindowInsetsAnimationListener() {\
                        @Override\
                        public void onPrepare(WindowInsetsAnimationCompat animation) {\
                            if ((animation.getTypeMask() \& WindowInsetsCompat.Type.ime())\
                                    != 0) {\
                                mAliceImeAnimationActive =\
                                        shouldManageImeInVisualViewport();\
                                WindowInsetsCompat insets =\
                                        ViewCompat.getRootWindowInsets(getContentView());\
                                if (mAliceImeAnimationActive\
                                        \&\& (insets == null\
                                                || !insets.isVisible(\
                                                        WindowInsetsCompat.Type.ime()))) {\
                                    mAliceLiftForFocusedInput = false;\
                                }\
                            }\
                        }\
\
                        @Override\
                        public void onStart(\
                                WindowInsetsAnimationCompat animation,\
                                WindowInsetsAnimationCompat.BoundsCompat bounds) {}\
\
                        @Override\
                        public void onProgress(\
                                WindowInsetsCompat insets,\
                                List<WindowInsetsAnimationCompat> runningAnimations) {\
                            if (!mAliceImeAnimationActive) return;\
                            mAliceLastImeHeightPx = getAliceKeyboardHeight(insets);\
                            int focusedNodeBottomPx = getAliceFocusedNodeBottomPx();\
                            int imeTopPx =\
                                    getAliceRootBottomPx() - mAliceLastImeHeightPx;\
                            if (focusedNodeBottomPx > imeTopPx) {\
                                mAliceLiftForFocusedInput = true;\
                            }\
                            updateImeViewportTranslation(mAliceLastImeHeightPx);\
                        }\
\
                        @Override\
                        public void onEnd(WindowInsetsAnimationCompat animation) {\
                            if ((animation.getTypeMask() \& WindowInsetsCompat.Type.ime())\
                                    == 0) {\
                                return;\
                            }\
                            if (!mAliceImeAnimationActive) return;\
                            mAliceImeAnimationActive = false;\
                            updateImeViewportTranslation(mAliceLastImeHeightPx);\
                            if (mAliceLastImeHeightPx == 0) {\
                                mAliceLiftForFocusedInput = false;\
                            }\
                            setVisualViewportBottomInset(0);\
                        }\
                    };\
    // Alice patch end 0063\
' "$path1"

# 添加 inset supplier 观察者时同步挂载 IME 动画监听。
sed -i '/^            mCurrentInsetSupplier\.addSyncObserverAndPostIfNonNull(mInsetObserver);$/a\
            // Alice patch start 0063\
            attachAliceImeAnimationListener(window);\
            // Alice patch end 0063' "$path1"

# 移除 inset supplier 观察者时同步卸载 IME 动画监听。
sed -i '/^                            mCurrentInsetSupplier\.removeObserver(mInsetObserver);$/a\
                            // Alice patch start 0063\
                            detachAliceImeAnimationListener();\
                            // Alice patch end 0063' "$path1"

# 窗口恢复时重新挂载 IME 动画监听。
sed -i '/^                        if (window != null) {$/a\
                            // Alice patch start 0063\
                            attachAliceImeAnimationListener(window);\
                            // Alice patch end 0063' "$path1"

# Tab 显示时重新挂载 IME 监听和 WebContents 观察器。
sed -i '/^                    public void onShown(Tab tab, int type) {$/a\
                        // Alice patch start 0063\
                        WindowAndroid window = mTab.getWindowAndroid();\
                        if (window != null) attachAliceImeAnimationListener(window);\
                        attachAliceWebContentsObserver();\
                        // Alice patch end 0063' "$path1"

# IME 动画运行期间不要回退到普通 visual viewport inset。
sed -i '/^    private void updateVisualViewportBottomInset() {$/a\
        // Alice patch start 0063\
        if (mAliceImeAnimationActive) return;\
        // Alice patch end 0063\
' "$path1"

# 将 visual viewport inset 改为 IME 动画驱动的 compositor 位移。
sed -i '/^        if (inset == mVisualViewportInsetBottomPx) return;$/,/^        mTab\.getWebContents()\.getRenderWidgetHostView()\.onViewportInsetBottomChanged();$/c\
        // Alice patch start 0063\
        if (shouldManageImeInVisualViewport()) {\
            WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(getContentView());\
            int imeHeight =\
                    insets == null ? 0 : getAliceKeyboardHeight(insets);\
            if (imeHeight == 0\
                    \&\& insets != null\
                    \&\& insets.isVisible(WindowInsetsCompat.Type.ime())) {\
                imeHeight = mAliceLastImeHeightPx;\
            }\
            updateImeViewportTranslation(imeHeight);\
            setVisualViewportBottomInset(0);\
        } else {\
            setVisualViewportBottomInset(inset);\
        }\
        // Alice patch end 0063' "$path1"

# 新增 IME 监听挂载、卸载、焦点高度和位移计算方法。
sed -i '/^    \/\*\* Sets the Visual Viewport bottom inset\. \*\/$/i\
    // Alice patch start 0063\
    private void attachAliceImeAnimationListener(WindowAndroid window) {\
        if (isDestroyed()) return;\
        InsetObserver observer = window.getInsetObserver();\
        if (observer == null || observer == mAliceImeInsetObserver) return;\
        detachAliceImeAnimationListener();\
        mAliceImeInsetObserver = observer;\
        mAliceImeInsetObserver.addWindowInsetsAnimationListener(\
                mAliceImeAnimationListener);\
        if (mAliceImeWindowAndroid != window) {\
            if (mAliceImeWindowAndroid != null) {\
                mAliceImeWindowAndroid.removeActivityStateObserver(\
                        mAliceActivityStateObserver);\
            }\
            mAliceImeWindowAndroid = window;\
            mAliceImeWindowAndroid.addActivityStateObserver(\
                    mAliceActivityStateObserver);\
        }\
    }\
\
    private boolean shouldManageImeInVisualViewport() {\
        if (mTab.isHidden()) return false;\
        if (!getContentView().isAttachedToWindow()) return false;\
        WindowAndroid window = mTab.getWindowAndroid();\
        if (window == null) return false;\
        @Nullable MonotonicObservableSupplier<EphemeralTabCoordinator> previewSupplier =\
                EphemeralTabCoordinatorSupplier.from(window);\
        @Nullable EphemeralTabCoordinator preview =\
                previewSupplier == null ? null : previewSupplier.get();\
        if (preview != null \&\& preview.isOpened()) return false;\
        Activity activity = window.getActivity().get();\
        if (activity == null || !window.isTopResumedActivity()) return false;\
        int adjustMode =\
                activity.getWindow().getAttributes().softInputMode\
                        \& WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST;\
        return adjustMode == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING;\
    }\
\
    private void detachAliceImeAnimationListener() {\
        if (mAliceImeInsetObserver != null) {\
            mAliceImeInsetObserver.removeWindowInsetsAnimationListener(\
                    mAliceImeAnimationListener);\
            mAliceImeInsetObserver = null;\
        }\
        if (mAliceImeWindowAndroid != null) {\
            mAliceImeWindowAndroid.removeActivityStateObserver(\
                    mAliceActivityStateObserver);\
            mAliceImeWindowAndroid = null;\
        }\
        mAliceImeAnimationActive = false;\
        resetAliceImeViewportTranslation();\
    }\
\
    private int getAliceKeyboardHeight(WindowInsetsCompat insets) {\
        return insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;\
    }\
\
    private void attachAliceWebContentsObserver() {\
        @Nullable WebContents webContents = mTab.getWebContents();\
        if (webContents == null\
                || (mAliceWebContentsObserver != null\
                        \&\& mAliceWebContentsObserver.getWebContents() == webContents)) {\
            return;\
        }\
        if (mAliceWebContentsObserver != null) {\
            @Nullable WebContents previous = mAliceWebContentsObserver.getWebContents();\
            if (previous != null) previous.setImeViewportFocusCallback(null);\
            mAliceWebContentsObserver.observe(null);\
        }\
        webContents.setImeViewportFocusCallback(\
                () -> {\
                    if (!isDestroyed()) updateVisualViewportBottomInset();\
                });\
        mAliceWebContentsObserver =\
                new WebContentsObserver(webContents) {\
                    @Override\
                    public void onWebContentsLostFocus() {\
                        mAliceLiftForFocusedInput = false;\
                        if (!isDestroyed()) {\
                            updateImeViewportTranslation(mAliceLastImeHeightPx);\
                        }\
                    }\
\
                    @Override\
                    public void onWebContentsFocused() {\
                        if (!isDestroyed()) updateVisualViewportBottomInset();\
                    }\
                };\
    }\
\
    private int getAliceFocusedNodeBottomPx() {\
        if (mTab.getWebContents() == null) return 0;\
        @Nullable ImeAdapter imeAdapter = ImeAdapter.fromWebContents(mTab.getWebContents());\
        return imeAdapter == null ? 0 : imeAdapter.getFocusedNodeBottomPx();\
    }\
\
    private int getAliceRootBottomPx() {\
        View rootView = getContentView().getRootView();\
        rootView.getLocationOnScreen(mAliceTmpLocation);\
        return mAliceTmpLocation[1] + rootView.getHeight();\
    }\
\
    private int getAliceBottomChromeHeightPx() {\
        View contentView = getContentView();\
        View rootView = contentView.getRootView();\
        View bottomControls = rootView.findViewById(R.id.control_container);\
        if (bottomControls != null) {\
            int rootBottom = getAliceRootBottomPx();\
            bottomControls.getLocationOnScreen(mAliceTmpLocation);\
            return Math.max(0, rootBottom - mAliceTmpLocation[1]);\
        }\
\
        int toolbarHeight =\
                contentView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
        int hairlineHeight =\
                contentView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(contentView);\
        int navigationBarHeight =\
                insets == null\
                        ? 0\
                        : insets.getInsets(\
                                        WindowInsetsCompat.Type.navigationBars())\
                                .bottom;\
        return toolbarHeight + hairlineHeight + navigationBarHeight;\
    }\
\
    private void updateImeViewportTranslation(int imeHeightPx) {\
        if (isDestroyed()) return;\
        if (!getContentView().isAttachedToWindow()) return;\
        int focusedNodeBottomPx = getAliceFocusedNodeBottomPx();\
        int imeTopPx = getAliceRootBottomPx() - imeHeightPx;\
        mAliceLiftForFocusedInput =\
                imeHeightPx > 0 \&\& focusedNodeBottomPx > imeTopPx;\
        int viewportInsetPx =\
                mAliceLiftForFocusedInput\
                        ? Math.max(\
                                0, imeHeightPx - getAliceBottomChromeHeightPx())\
                        : 0;\
        if (mTab.getWebContents() == null) return;\
        mTab.getWebContents().setImeViewportTranslation(viewportInsetPx);\
    }\
\
    private void resetAliceImeViewportTranslation() {\
        mAliceImeAnimationActive = false;\
        mAliceLiftForFocusedInput = false;\
        mAliceLastImeHeightPx = 0;\
        if (mTab.getWebContents() != null) {\
            mTab.getWebContents().setImeViewportTranslation(0);\
        }\
        setVisualViewportBottomInset(0);\
    }\
\
    private void setVisualViewportBottomInset(int inset) {\
        if (inset == mVisualViewportInsetBottomPx) return;\
        mVisualViewportInsetBottomPx = inset;\
        if (mTab.getWebContents() == null\
                || mTab.getWebContents().getRenderWidgetHostView() == null) {\
            return;\
        }\
        mTab.getWebContents().getRenderWidgetHostView().onViewportInsetBottomChanged();\
    }\
    // Alice patch end 0063\
\
' "$path1"

# Tab 销毁时卸载 IME 动画监听。
sed -i '/^            mCurrentInsetSupplier\.removeObserver(mInsetObserver);$/a\
            // Alice patch start 0063\
            detachAliceImeAnimationListener();\
            // Alice patch end 0063' "$path1"

# Tab 销毁时注销 WebContents 焦点观察器。
sed -i '/^            mTabObserver = null;$/a\
        // Alice patch start 0063\
        // Unregister the WebContents focus gate.\
        if (mAliceWebContentsObserver != null) {\
            @Nullable WebContents previous = mAliceWebContentsObserver.getWebContents();\
            if (previous != null) previous.setImeViewportFocusCallback(null);\
            mAliceWebContentsObserver.observe(null);\
            mAliceWebContentsObserver = null;\
        }\
        // Alice patch end 0063' "$path1"

