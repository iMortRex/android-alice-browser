#!/bin/bash
# 预览网页 viewport：TextureView、裁剪区域、固定尺寸和标题栏测量。

set -e

path1="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabSheetContent.java"
path2="chrome/browser/ui/android/ephemeraltab/java/src/org/chromium/chrome/browser/ephemeraltab/EphemeralTabMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0069' "$path1"; then
    exit 100
fi

# 3) 预览网页强制使用可参与普通 View 合成的 TextureView
sed -i '/^import android\.view\.LayoutInflater;$/a\
// Alice patch start 0069\
import android.view.MotionEvent;\
// Alice patch end 0069\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import android\.view\.ViewTreeObserver;$/a\
// Alice patch start 0069\
import android.view.WindowInsets;\
// Alice patch end 0069\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^import androidx\.annotation\.StringRes;$/a\
// Alice patch start 0069\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0069\
' "$path1"

# 背景色脚本依赖上游已有常量，不能依赖本补丁稍后才插入的扩展适配脚本。
sed -i '/^    private static final float FULL_HEIGHT_RATIO = 0\.9f;$/i\
    // Alice patch start 0069\
    private static final String ALICE_PAGE_BACKGROUND_COLOR_SCRIPT =\
            """\
            (() => {\
              const aliceParseBackgroundColor = (color) => {\
                if (!color || color === "transparent") return 0;\
                const canvas = document.createElement("canvas");\
                canvas.width = 1;\
                canvas.height = 1;\
                const context = canvas.getContext("2d", {willReadFrequently: true});\
                if (!context) return 0;\
                context.clearRect(0, 0, 1, 1);\
                context.fillStyle = color;\
                context.fillRect(0, 0, 1, 1);\
                const data = context.getImageData(0, 0, 1, 1).data;\
                if (data[3] <= 0) return 0;\
                return (((data[3] << 24)\
                        | (data[0] << 16)\
                        | (data[1] << 8)\
                        | data[2]) >>> 0);\
              };\
              if (document.documentElement) {\
                const htmlColor = aliceParseBackgroundColor(\
                        getComputedStyle(document.documentElement).backgroundColor);\
                if (htmlColor) return htmlColor;\
              }\
              if (document.body) {\
                return aliceParseBackgroundColor(\
                        getComputedStyle(document.body).backgroundColor);\
              }\
              return 0;\
            })()\
            """;\
    // Alice patch end 0069\
\
' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private static final float FULL_HEIGHT_RATIO = 0\.9f;$/a\
    // Alice patch start 0069\
    private static final String ALICE_EXTENSION_FIT_SCRIPT =\
            """\
            if (location.protocol === "chrome-extension:") {\
              document.documentElement.style.setProperty(\
                      "overflow-y", "auto", "important");\
              document.documentElement.style.setProperty(\
                      "touch-action", "pan-y", "important");\
              document.documentElement.style.setProperty(\
                      "width", "100%", "important");\
              document.documentElement.style.setProperty(\
                      "max-width", "none", "important");\
              document.documentElement.style.setProperty(\
                      "min-width", "0px", "important");\
              document.documentElement.style.setProperty(\
                      "box-sizing", "border-box", "important");\
              document.documentElement.style.setProperty(\
                      "margin", "0px", "important");\
              if (document.body) {\
                document.body.style.setProperty(\
                        "overflow-y", "auto", "important");\
                document.body.style.setProperty(\
                        "touch-action", "pan-y", "important");\
                document.body.style.setProperty(\
                        "width", "100%", "important");\
                document.body.style.setProperty(\
                        "max-width", "none", "important");\
                document.body.style.setProperty(\
                        "min-width", "0px", "important");\
                document.body.style.setProperty(\
                        "box-sizing", "border-box", "important");\
              }\
            }\
            (() => {\
              const aliceDeepActiveElement = () => {\
                let active = document.activeElement;\
                while (active \&\& active.shadowRoot \&\& active.shadowRoot.activeElement) {\
                  active = active.shadowRoot.activeElement;\
                }\
                return active;\
              };\
              const aliceParentNode = (node) => {\
                if (node.parentElement) return node.parentElement;\
                const root = node.getRootNode();\
                return root instanceof ShadowRoot ? root.host : null;\
              };\
              const aliceCanScroll = (node) => {\
                const overflowY = getComputedStyle(node).overflowY;\
                return (overflowY === "auto"\
                                || overflowY === "scroll"\
                                || overflowY === "overlay")\
                        \&\& node.scrollHeight > node.clientHeight + 1;\
              };\
              const aliceScrollBy = (node, amount) => {\
                const before = node.scrollTop;\
                node.scrollTop =\
                        Math.min(\
                                node.scrollHeight - node.clientHeight,\
                                before + amount);\
                return amount - (node.scrollTop - before);\
              };\
              window.__aliceRevealFocusedInput = (visibleHeightPx) => {\
                const active = aliceDeepActiveElement();\
                if (!active || typeof active.getBoundingClientRect !== "function") return;\
                const scale = window.devicePixelRatio || 1;\
                const viewportHeight = window.visualViewport\
                        ? window.visualViewport.height\
                        : window.innerHeight;\
                const visibleBottom =\
                        Math.max(\
                                1,\
                                Math.min(visibleHeightPx / scale, viewportHeight) - 12);\
                const inputBottom = active.getBoundingClientRect().bottom;\
                let remaining = inputBottom - visibleBottom;\
                if (remaining <= 0) return;\
                let node = aliceParentNode(active);\
                while (node \&\& remaining > 0.5) {\
                  if (aliceCanScroll(node)) {\
                    remaining = aliceScrollBy(node, remaining);\
                  }\
                  node = aliceParentNode(node);\
                }\
                if (remaining > 0.5) {\
                  const root = document.scrollingElement || document.documentElement;\
                  remaining = aliceScrollBy(root, remaining);\
                  if (remaining > 0.5) window.scrollBy(0, remaining);\
                }\
              };\
            })();\
            """;\
    // Alice patch end 0069\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^        mThinWebView =$/i\
        // Alice patch start 0069\
        ThinWebViewConstraints constraints = new ThinWebViewConstraints();\
        constraints.supportsOpacity = true;\
        android.util.TypedValue aliceBackgroundValue =\
                new android.util.TypedValue();\
        int aliceBackgroundColor = android.graphics.Color.BLACK;\
        if (mContext\
                .getTheme()\
                .resolveAttribute(\
                        android.R.attr.colorBackground,\
                        aliceBackgroundValue,\
                        true)) {\
            aliceBackgroundColor =\
                    aliceBackgroundValue.resourceId != 0\
                            ? mContext.getColor(aliceBackgroundValue.resourceId)\
                            : aliceBackgroundValue.data;\
        }\
        constraints.backgroundColor = aliceBackgroundColor;\
        constraints.ignoreSizeChanges = true;\
        // Alice patch end 0069\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private ViewGroup mSheetContentView;$/a\
    // Alice patch start 0069\
    private FrameLayout mContentViewport;\
    private int mLastSheetHeight;\
    // Alice patch end 0069' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    @EnsuresNonNull({"mThinWebView", "mSheetContentView"})$/c\
    // Alice patch start 0069\
    @EnsuresNonNull({"mThinWebView", "mSheetContentView", "mContentViewport"})\
    // Alice patch end 0069' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^                        mContext,$/,/^                        \/\* enablePermissionRequests= \*\/ false);$/c\
                        // Alice patch start 0069\
                        mContext,\
                        constraints,\
                        intentRequestTracker,\
                        /* enablePermissionRequests= */ false);\
                        // Alice patch end 0069' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private void createThinWebView(int maxSheetHeight, IntentRequestTracker intentRequestTracker) {$/i\
    // Alice patch start 0069\
    void applyExtensionViewportConstraint() {\
        if (mWebContents == null || mWebContents.isDestroyed()) return;\
        mWebContents\
                .getMainFrame()\
                .executeJavaScriptInIsolatedWorld(ALICE_EXTENSION_FIT_SCRIPT, 1, null);\
    }\
\
    private void applyPreviewImeVisibleHeight(int visibleHeightPx) {\
        if (mWebContents == null || mWebContents.isDestroyed()) return;\
        String aliceScript =\
                "if (window.__aliceRevealFocusedInput) {"\
                        + "window.__aliceRevealFocusedInput("\
                        + visibleHeightPx\
                        + ");}";\
        mWebContents\
                .getMainFrame()\
                .executeJavaScriptInIsolatedWorld(aliceScript, 1, null);\
    }\
    // Alice patch end 0069\
\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^                        \.build());$/a\
\
        // Alice patch start 0069\
        mWebContentView.setOnTouchListener(\
                (view, event) -> {\
                    if (event.getActionMasked() == MotionEvent.ACTION_DOWN\
                            \&\& view.getParent() != null) {\
                        view.getParent().requestDisallowInterceptTouchEvent(true);\
                    }\
                    return false;\
                });\
        // Alice patch end 0069' "$path1"

# 4) 在标题栏下方建立独立裁剪视口，网页只在该范围内绘制
sed -i '/^        mSheetContentView = new FrameLayout(mContext);$/,/^        mSheetContentView.addView(mThinWebView.getView());$/c\
        // Alice patch start 0069\
        mSheetContentView = new FrameLayout(mContext);\
        mSheetContentView.setClipChildren(true);\
        mSheetContentView.setClipToPadding(true);\
\
        mContentViewport = new FrameLayout(mContext);\
        mContentViewport.setClipChildren(true);\
        mContentViewport.setClipToPadding(true);\
        mContentViewport.setBackgroundColor(aliceBackgroundColor);\
        mContentViewport.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, maxSheetHeight));\
\
        FrameLayout.LayoutParams aliceWebViewParams =\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT,\
                        maxSheetHeight);\
        mThinWebView.getView().setBackgroundColor(aliceBackgroundColor);\
        mThinWebView.getView().setLayoutParams(aliceWebViewParams);\
        mContentViewport.addView(mThinWebView.getView());\
        mSheetContentView.addView(mContentViewport);\
        // Alice patch end 0069' "$path1"

# 5) 固定视口尺寸，并在当前遍历中完成布局，拖动时只平移面板
sed -i '/^    void updateContentHeight(int maxViewHeight) {$/i\
    // Alice patch start 0069\
    private void ensureAliceWebViewStableHeight(int contentHeight) {\
        FrameLayout.LayoutParams params =\
                (FrameLayout.LayoutParams) mThinWebView.getView().getLayoutParams();\
        if (params.height < contentHeight) {\
            params.height = contentHeight;\
            mThinWebView.getView().setLayoutParams(params);\
        }\
    }\
    // Alice patch end 0069\
\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    void updateContentHeight(int maxViewHeight) {$/,/^    }$/c\
    // Alice patch start 0069\
    void updateContentHeight(int maxViewHeight) {\
        if (maxViewHeight == 0) return;\
\
        int aliceSheetHeight = getMaxSheetHeight(maxViewHeight);\
        int aliceToolbarHeight = getToolbarHeight();\
        int aliceContentHeight = Math.max(0, aliceSheetHeight - aliceToolbarHeight);\
        // Alice: the web contents fill the whole visible area so nothing is truncated.\
        ensureAliceWebViewStableHeight(aliceContentHeight);\
        int aliceWidth = mSheetContentView.getWidth();\
        if (aliceWidth <= 0) {\
            aliceWidth = mContext.getResources().getDisplayMetrics().widthPixels;\
        }\
\
        FrameLayout.LayoutParams aliceViewportParams =\
                (FrameLayout.LayoutParams) mContentViewport.getLayoutParams();\
        aliceViewportParams.height = aliceContentHeight;\
        aliceViewportParams.topMargin = aliceToolbarHeight;\
        mContentViewport.setLayoutParams(aliceViewportParams);\
        mSheetContentView.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, aliceSheetHeight));\
        mSheetContentView.setPadding(0, 0, 0, 0);\
\
        mThinWebView.resizeWebContents(aliceWidth, aliceContentHeight);\
        mContentViewport.forceLayout();\
        mContentViewport.measure(\
                View.MeasureSpec.makeMeasureSpec(aliceWidth, View.MeasureSpec.EXACTLY),\
                View.MeasureSpec.makeMeasureSpec(\
                        aliceContentHeight, View.MeasureSpec.EXACTLY));\
        mContentViewport.layout(\
                0,\
                aliceToolbarHeight,\
                aliceWidth,\
                aliceToolbarHeight + aliceContentHeight);\
        ViewUtils.requestLayout(mSheetContentView, "Alice preview fixed viewport");\
    }\
\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private int getToolbarHeight() {$/,/^    }$/c\
    // Alice patch start 0069\
    private int getToolbarHeight() {\
        int shadowHeight =\
                mContext.getResources().getDimensionPixelSize(R.dimen.action_bar_shadow_height);\
        int toolbarHeight = mToolbarView.getHeight();\
        if (toolbarHeight == 0) toolbarHeight = mToolbarView.getMeasuredHeight();\
        return Math.max(0, toolbarHeight - shadowHeight);\
    }\
    // Alice patch end 0069' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^    private int getMaxSheetHeight(int maxViewHeight) {$/,/^    }$/c\
    // Alice patch start 0069\
    private int getAliceNavigationBarInset() {\
        if (mSheetContentView == null) return 0;\
        WindowInsets aliceInsets = mSheetContentView.getRootWindowInsets();\
        if (aliceInsets == null) return 0;\
        return WindowInsetsCompat.toWindowInsetsCompat(\
                        aliceInsets, mSheetContentView)\
                .getInsetsIgnoringVisibility(\
                        WindowInsetsCompat.Type.navigationBars())\
                .bottom;\
    }\
\
    private int getMaxSheetHeight(int maxViewHeight) {\
        int aliceSheetHeight = (int) (maxViewHeight * FULL_HEIGHT_RATIO);\
        return Math.max(0, aliceSheetHeight - getAliceNavigationBarInset());\
    }\
    // Alice patch end 0069' "$path1"

# 6) 预览网页在首次显示前完成标题栏测量
sed -i '/^        mOnToolbarCreatedCallback\.onResult(mToolbarView);$/a\
        // Alice patch start 0069\
        // The toolbar must be measured before the sheet is measured for the first time.\
        // Otherwise the page content starts at the sheet top and covers the title bar.\
        int aliceToolbarWidth = mContext.getResources().getDisplayMetrics().widthPixels;\
        mToolbarView.measure(\
                View.MeasureSpec.makeMeasureSpec(aliceToolbarWidth, View.MeasureSpec.EXACTLY),\
                View.MeasureSpec.makeMeasureSpec(\
                        getMaxSheetHeight(maxViewHeight), View.MeasureSpec.AT_MOST));\
        mToolbarView.layout(\
                0, 0, mToolbarView.getMeasuredWidth(), mToolbarView.getMeasuredHeight());\
        updateContentHeight(maxViewHeight);\
        // Alice patch end 0069\
' "$path1"

# 修改对应源码以完成本补丁功能。
sed -i '/^                        if (navigation.hasCommitted()) {$/a\
                            // Alice patch start 0069\
                            mSheetContent.applyExtensionViewportConstraint();\
                            // Alice patch end 0069' "$path2"

# 修改对应源码以完成本补丁功能。
sed -i '/^                        if (mSheetContent != null) mSheetContent\.setProgress(progress);$/a\
                        // Alice patch start 0069\
                        if (progress >= 1f \&\& mSheetContent != null) {\
                            mSheetContent.applyExtensionViewportConstraint();\
                        }\
                        // Alice patch end 0069' "$path2"

# 修改对应源码以完成本补丁功能。
sed -i '/^    @Nullable$/i\
    // Alice patch start 0069\
    @Override\
    public void getPageBackgroundColor(org.chromium.base.Callback<Integer> callback) {\
        if (mWebContents == null || mWebContents.isDestroyed()) {\
            org.chromium.base.Callback.runNullSafe(\
                    callback, android.graphics.Color.TRANSPARENT);\
            return;\
        }\
        mWebContents\
                .getMainFrame()\
                .executeJavaScriptInIsolatedWorld(\
                        ALICE_PAGE_BACKGROUND_COLOR_SCRIPT,\
                        1,\
                        jsonResult -> {\
                            int aliceColor = android.graphics.Color.TRANSPARENT;\
                            try {\
                                long alicePackedColor =\
                                        (long) Double.parseDouble(jsonResult.trim());\
                                if (alicePackedColor > 0\
                                        \&\& alicePackedColor <= 0xFFFFFFFFL) {\
                                    aliceColor = (int) alicePackedColor;\
                                }\
                            } catch (NumberFormatException ignored) {\
                            }\
                            org.chromium.base.Callback.runNullSafe(\
                                    callback, aliceColor);\
                        });\
    }\
\
    @Override\
    public boolean shouldUseFullWindowPresentation() {\
        return true;\
    }\
\
    @Override\
    public boolean shouldHandleContentTouchEvents() {\
        return true;\
    }\
\
    @Override\
    public void onSheetHeightChanged(int sheetHeight) {\
        if (sheetHeight <= 0) return;\
        boolean aliceHeightReduced =\
                mLastSheetHeight > 0 \&\& sheetHeight < mLastSheetHeight;\
        mLastSheetHeight = sheetHeight;\
        int aliceToolbarHeight = getToolbarHeight();\
        int aliceContentHeight = Math.max(1, sheetHeight - aliceToolbarHeight);\
        ensureAliceWebViewStableHeight(aliceContentHeight);\
        int aliceWidth = mSheetContentView.getWidth();\
        if (aliceWidth <= 0) {\
            aliceWidth = mContext.getResources().getDisplayMetrics().widthPixels;\
        }\
        mSheetContentView.setLayoutParams(\
                new FrameLayout.LayoutParams(\
                        ViewGroup.LayoutParams.MATCH_PARENT, sheetHeight));\
        FrameLayout.LayoutParams aliceViewportParams =\
                (FrameLayout.LayoutParams) mContentViewport.getLayoutParams();\
        aliceViewportParams.height = aliceContentHeight;\
        aliceViewportParams.topMargin = aliceToolbarHeight;\
        mContentViewport.setLayoutParams(aliceViewportParams);\
        mThinWebView.resizeWebContents(aliceWidth, aliceContentHeight);\
        mContentViewport.forceLayout();\
        mContentViewport.measure(\
                View.MeasureSpec.makeMeasureSpec(\
                        aliceWidth, View.MeasureSpec.EXACTLY),\
                View.MeasureSpec.makeMeasureSpec(\
                        aliceContentHeight, View.MeasureSpec.EXACTLY));\
        mContentViewport.layout(\
                0,\
                aliceToolbarHeight,\
                aliceWidth,\
                aliceToolbarHeight + aliceContentHeight);\
        ViewUtils.requestLayout(\
                mSheetContentView, "Alice preview sheet height");\
        if (aliceHeightReduced) {\
            applyPreviewImeVisibleHeight(aliceContentHeight);\
        }\
    }\
\
    @Override\
    public int getToolbarBackgroundHeight() {\
        return getToolbarHeight();\
    }\
    // Alice patch end 0069\
\
' "$path1"
