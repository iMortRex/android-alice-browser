#!/bin/bash
# IME visual viewport：按输入法进度逐帧同步 Blink VisualViewport。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/tab/TabViewAndroidDelegate.java"

# 检测是否已应用
if grep -q 'Alice patch start 0063' "$path1"; then
    exit 100
fi

# Java 只同步当前 IME 和底部浏览器控件高度；焦点容器几何由 renderer
#     在布局生命周期中实时计算。
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

# 补充 Content 层 WebContents 和 observer import。
sed -i '/^import org\.chromium\.content_public\.browser\.ContentFeatureMap;$/a\
// Alice patch start 0063\
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
    private int mAliceLastImeHeightPx;\
    private final int[] mAliceTmpLocation = new int[2];\
    private @Nullable WebContentsObserver mAliceWebContentsObserver;\
    private final WindowAndroid.ActivityStateObserver mAliceActivityStateObserver =\
            new WindowAndroid.ActivityStateObserver() {\
                @Override\
                public void onActivityPaused() {\
                    pauseAliceImeViewportAnimation();\
                }\
\
                @Override\
                public void onActivityTopResumedChanged(boolean isTopResumedActivity) {\
                    if (!isTopResumedActivity) {\
                        pauseAliceImeViewportAnimation();\
                    } else {\
                        restoreAliceImeViewportTranslation();\
                    }\
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
                                if (!mAliceImeAnimationActive) return;\
                                WindowInsetsCompat insets =\
                                        ViewCompat.getRootWindowInsets(getContentView());\
                                if (insets == null) return;\
                                int currentHeightPx = getAliceKeyboardHeight(insets);\
                                mAliceLastImeHeightPx =\
                                        Math.max(mAliceLastImeHeightPx, currentHeightPx);\
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
                            int currentHeightPx = getAliceKeyboardHeight(insets);\
                            mAliceLastImeHeightPx = currentHeightPx;\
                            syncAliceImeViewportLift(currentHeightPx);\
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
                            WindowInsetsCompat insets =\
                                    ViewCompat.getRootWindowInsets(getContentView());\
                            int finalHeightPx =\
                                    insets == null\
                                            ? 0\
                                            : getAliceKeyboardHeight(insets);\
                            mAliceLastImeHeightPx = finalHeightPx;\
                            syncAliceImeViewportLift(finalHeightPx);\
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
\
        if (shouldManageImeInVisualViewport()) {\
            WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(getContentView());\
            int imeHeight =\
                    insets == null ? 0 : getAliceKeyboardHeight(insets);\
            if (imeHeight == 0\
                    \&\& insets != null\
                    \&\& insets.isVisible(WindowInsetsCompat.Type.ime())) {\
                imeHeight = mAliceLastImeHeightPx;\
            }\
            syncAliceImeViewportLift(imeHeight);\
            setVisualViewportBottomInset(0);\
            return;\
        }\
        // Alice patch end 0063\
' "$path1"

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
    private void pauseAliceImeViewportAnimation() {\
        mAliceImeAnimationActive = false;\
    }\
\
    private void restoreAliceImeViewportTranslation() {\
        if (isDestroyed()) return;\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(getContentView());\
        int imeHeightPx =\
                insets == null\
                        ? 0\
                        : getAliceKeyboardHeight(insets);\
        if (imeHeightPx <= 0) {\
            resetAliceImeViewportTranslation();\
            return;\
        }\
        mAliceImeAnimationActive = shouldManageImeInVisualViewport();\
        if (!mAliceImeAnimationActive) return;\
        mAliceLastImeHeightPx = imeHeightPx;\
        syncAliceImeViewportLift(imeHeightPx);\
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
                        if (isDestroyed()) return;\
                        if (!mAliceImeAnimationActive && mAliceLastImeHeightPx <= 0) {\
                            applyAliceImeViewportState(0);\
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
    private int getAliceBottomChromeHeightPx() {\
        View contentView = getContentView();\
        View rootView = contentView.getRootView();\
        View bottomControls = rootView.findViewById(R.id.control_container);\
        if (bottomControls != null) {\
            rootView.getLocationOnScreen(mAliceTmpLocation);\
            int rootBottomPx = mAliceTmpLocation[1] + rootView.getHeight();\
            bottomControls.getLocationOnScreen(mAliceTmpLocation);\
            return Math.max(0, rootBottomPx - mAliceTmpLocation[1]);\
        }\
\
        int toolbarHeightPx =\
                contentView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.toolbar_height_no_shadow);\
        int hairlineHeightPx =\
                contentView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.toolbar_hairline_height);\
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(contentView);\
        int navigationBarHeightPx =\
                insets == null\
                        ? 0\
                        : insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom;\
        return toolbarHeightPx + hairlineHeightPx + navigationBarHeightPx;\
    }\
\
    private void applyAliceImeViewportState(int imeHeightPx) {\
        @Nullable WebContents webContents = mTab.getWebContents();\
        if (webContents != null) {\
            webContents.syncImeViewportLift(\
                    imeHeightPx,\
                    imeHeightPx <= 0 ? 0 : getAliceBottomChromeHeightPx());\
        }\
    }\
\
    private void syncAliceImeViewportLift(int imeHeightPx) {\
        applyAliceImeViewportState(imeHeightPx);\
    }\
\
    private void resetAliceImeViewportTranslation() {\
        mAliceImeAnimationActive = false;\
        mAliceLastImeHeightPx = 0;\
        applyAliceImeViewportState(0);\
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

