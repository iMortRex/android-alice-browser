#!/bin/bash
# 底置地址栏建议列表：按搜索框上沿布局，跟随 IME 动画并保持底部锚定。

set -e

path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsContainer.java"
path2="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListViewBinder.java"
path3="chrome/android/java/res/layout/search_activity.xml"
path4="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/OmniboxSuggestionsDropdown.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPageCoordinator.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/ntp/NewTabPage.java"
path7="chrome/android/java/src/org/chromium/chrome/browser/searchwidget/SearchActivity.java"
path8="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/SuggestionListProperties.java"
path9="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteCoordinator.java"
path10="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0062' "$path1"; then
    exit 100
fi

# 底置工具栏时 NTP 推荐内容从搜索框上沿向上排列。
sed -i '/^    void onUrlFocusAnimationChanged() {$/a\
        // Alice patch start 0062\
        if (mToolbarOnBottom) {\
            mModel.set(NewTabPageLayoutProperties.TRANSITION_Y, 0f);\
            return;\
        }\
        // Alice patch end 0062' "$path5"

# 切换工具栏位置时重新计算 NTP inset 和推荐动画。
sed -i '/^    void setToolbarOnBottom(boolean toolbarOnBottom) {$/,/^    }$/c\
    void setToolbarOnBottom(boolean toolbarOnBottom) {\
        // Alice patch start 0062\
        if (mToolbarOnBottom == toolbarOnBottom) return;\
        mToolbarOnBottom = toolbarOnBottom;\
        updateToolbarInsets();\
        onUrlFocusAnimationChanged();\
        // Alice patch end 0062\
    }' "$path5"

# 搜索页建议容器改为顶部 gravity，不再锚定顶部工具栏。
sed -i '/^    <org\.chromium\.ui\.AsyncViewStub$/i\
    <!-- Alice patch start 0062 -->' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i 's|^        app:layout_anchor="@id/toolbar"$|        android:layout_gravity="top"|' "$path3"
# 修改对应源码以完成本补丁功能。
sed -i '/^        app:inflatedId="@+id\/search_activity_suggestions_container"\/>$/a\
    <!-- Alice patch end 0062 -->' "$path3"

# NTP 创建时同步工具栏当前位置。
sed -i '/^        mBrowserControlsStateProvider\.addObserver(this);$/i\
        // Alice patch start 0062\
        mNewTabPageCoordinator.setToolbarOnBottom(\
                mBrowserControlsStateProvider.getControlsPosition()\
                        == ControlsPosition.BOTTOM);\
        // Alice patch end 0062' "$path6"

# 建议容器引入 IME 动画类型。
sed -i '/^import androidx\.annotation\.VisibleForTesting;$/a\
// Alice patch start 0062\
import androidx.core.view.WindowInsetsAnimationCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0062' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.ui\.base\.ViewUtils;$/a\
// Alice patch start 0062\
import org.chromium.ui.insets.InsetObserver;\
// Alice patch end 0062' "$path1"

# 增加底置建议列表的 IME 动画状态。
sed -i '/^    private final int\[\] mStickPosition = new int\[2\];$/a\
    // Alice patch start 0062\
    private int mAliceBottomViewportHeight = -1;\
    private boolean mAliceImeAnimationActive;\
    private @Nullable InsetObserver mSuggestionsInsetObserver;\
    private final InsetObserver.WindowInsetsAnimationListener mSuggestionsImeListener =\
            new InsetObserver.WindowInsetsAnimationListener() {\
                @Override\
                public void onPrepare(WindowInsetsAnimationCompat animation) {\
                    if (mEmbedder != null\
                            \&\& mEmbedder.isToolbarOnBottom()\
                            \&\& (animation.getTypeMask() \& WindowInsetsCompat.Type.ime()) != 0) {\
                        mAliceImeAnimationActive = true;\
                        prepareAliceBottomAnchoredAnimation();\
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
                        java.util.List<WindowInsetsAnimationCompat> runningAnimations) {\
                    if (mEmbedder != null \&\& mEmbedder.isToolbarOnBottom()) {\
                        updateAliceImeViewport(insets);\
                    }\
                }\
\
                @Override\
                public void onEnd(WindowInsetsAnimationCompat animation) {\
                    if (mEmbedder != null\
                            \&\& mEmbedder.isToolbarOnBottom()\
                            \&\& (animation.getTypeMask() \& WindowInsetsCompat.Type.ime()) != 0) {\
                        mAliceImeAnimationActive = false;\
                        postOnAnimation(OmniboxSuggestionsContainer.this::stickToAnchor);\
                    }\
                }\
            };\
    // Alice patch end 0062' "$path1"

# 增加底部锚定、IME viewport 和稳定布局计算方法。
sed -i '/^    private boolean stickToAnchor() {$/i\
    // Alice patch start 0062\
    private int getAliceNavigationBarHeight() {\
        if (getContext() instanceof android.app.Activity\
                \&\& ((android.app.Activity) getContext()).isInMultiWindowMode()) {\
            return 0;\
        }\
        android.view.WindowInsets aliceRootInsets = getRootWindowInsets();\
        if (aliceRootInsets == null) return 0;\
        WindowInsetsCompat aliceInsets =\
                WindowInsetsCompat.toWindowInsetsCompat(aliceRootInsets, getRootView());\
        return Math.max(\
                aliceInsets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom,\
                aliceInsets\
                        .getInsets(WindowInsetsCompat.Type.mandatorySystemGestures())\
                        .bottom);\
    }\
\
    private void updateAliceBottomAnchoredPosition(\
            int aliceTargetTop, int aliceContainerTop) {\
        int aliceWindowHeight = getRootView().getHeight();\
        if (aliceWindowHeight <= 0) aliceWindowHeight = mEmbedder.getWindowHeight();\
        int aliceAnchorHeight = mEmbedder.getAnchorView().getHeight();\
        int aliceViewportHeight =\
                Math.max(\
                        0,\
                        aliceWindowHeight\
                                - getAliceNavigationBarHeight()\
                                - aliceAnchorHeight\
                                - aliceContainerTop);\
        if (aliceViewportHeight <= 0) return;\
        mAliceBottomViewportHeight = aliceViewportHeight;\
        setAliceDropdownStackFromEnd(true);\
        updateAliceDropdownViewportHeight(aliceViewportHeight);\
        float aliceTranslationY =\
                aliceTargetTop - (aliceContainerTop + aliceViewportHeight);\
        if (mDropdown.getTranslationY() != aliceTranslationY) {\
            mDropdown.setTranslationY(aliceTranslationY);\
        }\
    }\
\
    private void prepareAliceBottomAnchoredAnimation() {\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int aliceTargetTop = mStickPosition[1];\
        getLocationInWindow(mStickPosition);\
        updateAliceBottomAnchoredPosition(aliceTargetTop, mStickPosition[1]);\
    }\
\
    private void updateAliceSettledViewport(\
            int aliceTargetTop, int aliceContainerTop) {\
        int aliceViewportHeight = Math.max(0, aliceTargetTop - aliceContainerTop);\
        if (aliceViewportHeight <= 0) return;\
        mAliceBottomViewportHeight = aliceViewportHeight;\
        setAliceDropdownStackFromEnd(true);\
        updateAliceDropdownViewportHeight(aliceViewportHeight);\
        if (mDropdown.getTranslationY() != 0) mDropdown.setTranslationY(0);\
    }\
\
    private void updateAliceImeViewport(WindowInsetsCompat insets) {\
        if (mDropdown.getVisibility() != View.VISIBLE) return;\
        int aliceImeHeight = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom;\
        int aliceAnchorHeight = mEmbedder.getAnchorView().getHeight();\
        int aliceWindowHeight = getRootView().getHeight();\
        if (aliceWindowHeight <= 0) aliceWindowHeight = mEmbedder.getWindowHeight();\
        getLocationInWindow(mStickPosition);\
        int aliceContainerTop = mStickPosition[1];\
        int aliceViewportHeight =\
                Math.max(\
                        0,\
                        aliceWindowHeight - aliceImeHeight - aliceAnchorHeight - aliceContainerTop);\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int aliceCurrentAnchorTop = mStickPosition[1];\
        aliceViewportHeight =\
                Math.min(\
                        aliceViewportHeight,\
                        Math.max(0, aliceCurrentAnchorTop - aliceContainerTop));\
        updateAliceBottomAnchoredPosition(aliceCurrentAnchorTop, aliceContainerTop);\
        int aliceBaseBottomPadding = mDropdown.getBaseBottomPadding();\
        if (mDropdown.getPaddingBottom() != aliceBaseBottomPadding) {\
            mDropdown.setPaddingRelative(\
                    mDropdown.getPaddingStart(),\
                    mDropdown.getPaddingTop(),\
                    mDropdown.getPaddingEnd(),\
                    aliceBaseBottomPadding);\
        }\
    }\
    // Alice patch end 0062\
' "$path1"

# 初始化建议容器并在尺寸变化时重新吸附。
sed -i '/^    protected void onFinishInflate() {$/,/^    }$/c\
    // Alice patch start 0062\
    protected void onFinishInflate() {\
        super.onFinishInflate();\
        mDropdown = findViewById(R.id.omnibox_suggestions_dropdown);\
    }\
\
    @Override\
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {\
        super.onSizeChanged(width, height, oldWidth, oldHeight);\
        if (width == oldWidth \&\& height == oldHeight) return;\
        mAliceBottomViewportHeight = -1;\
        postOnAnimation(OmniboxSuggestionsContainer.this::stickToAnchor);\
    }\
    // Alice patch end 0062' "$path1"

# 对齐信息变化时同步顶部和底部 padding。
sed -i '/^        mDropdown\.setPaddingRelative($/,/^                mDropdown\.getBaseBottomPadding() + mOmniboxAlignment\.paddingBottom);$/c\
        // Alice patch start 0062\
        int aliceTopPadding =\
                mDropdown.getBaseTopPadding() + mOmniboxAlignment.paddingTop;\
        if (mEmbedder != null \&\& !mEmbedder.isToolbarOnBottom()) {\
            aliceTopPadding +=\
                    getResources()\
                            .getDimensionPixelSize(R.dimen.location_bar_vertical_margin);\
        }\
        mDropdown.setPaddingRelative(\
                mDropdown.getPaddingStart(),\
                aliceTopPadding,\
                mDropdown.getPaddingEnd(),\
                mDropdown.getBaseBottomPadding() + mOmniboxAlignment.paddingBottom);\
        // Alice patch end 0062' "$path1"

# SearchActivity 根据地址栏位置切换输入法 adjust mode。
sed -i '/^import android\.view\.ViewGroup;$/a\
// Alice patch start 0062\
import android.view.WindowManager;\
// Alice patch end 0062' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.chrome\.browser\.tabwindow\.TabWindowInfo;$/a\
// Alice patch start 0062\
import org.chromium.chrome.browser.toolbar.settings.AddressBarPreference;\
// Alice patch end 0062' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^    protected ModalDialogManager createModalDialogManager() {$/,/^    protected void triggerLayoutInflation() {$/{
    /^    @Override$/i\
    // Alice patch start 0062\
    private boolean mAliceSoftInputModePreDrawAttached;\
\
    private void setAliceSoftInputAdjustMode(boolean toolbarOnTop) {\
        int aliceSoftInputMode = getWindow().getAttributes().softInputMode;\
        int aliceTargetAdjustMode =\
                toolbarOnTop\
                        ? WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING\
                        : WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;\
        if ((aliceSoftInputMode \& WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST)\
                == aliceTargetAdjustMode) return;\
        aliceSoftInputMode \&= ~WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST;\
        aliceSoftInputMode |= aliceTargetAdjustMode;\
        getWindow().setSoftInputMode(aliceSoftInputMode);\
    }\
\
    @Override\
    protected void onPreCreate() {\
        super.onPreCreate();\
        setAliceSoftInputAdjustMode(\
                AddressBarPreference.isToolbarConfiguredToShowOnTop());\
    }\
\
    private void updateAliceSoftInputMode(View rootView) {\
        if (!mAliceSoftInputModePreDrawAttached) {\
            mAliceSoftInputModePreDrawAttached = true;\
            rootView.getViewTreeObserver().addOnPreDrawListener(\
                    () -> {\
                        updateAliceSoftInputMode(rootView);\
                        return true;\
                    });\
        }\
        View aliceToolbar = rootView.findViewById(R.id.toolbar);\
        if (aliceToolbar == null || rootView.getHeight() <= 0) return;\
        int[] aliceToolbarLocation = new int[2];\
        aliceToolbar.getLocationInWindow(aliceToolbarLocation);\
        setAliceSoftInputAdjustMode(\
                aliceToolbarLocation[1] + aliceToolbar.getHeight() / 2\
                        < rootView.getHeight() / 2);\
    }\
    // Alice patch end 0062
}' "$path7"
# 修改对应源码以完成本补丁功能。
sed -i '/^        setContentView(contentView);$/a\
        // Alice patch start 0062\
        contentView.addOnLayoutChangeListener(\
                (view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) ->\
                        updateAliceSoftInputMode(view));\
        contentView.post(() -> updateAliceSoftInputMode(contentView));\
        // Alice patch end 0062' "$path7"

# 安装和移除 IME 动画监听器。
sed -i '/^            getViewTreeObserver().addOnPreDrawListener(mStickListener);$/a\
            // Alice patch start 0062\
            if (mSuggestionsInsetObserver != null) {\
                mSuggestionsInsetObserver.removeWindowInsetsAnimationListener(\
                        mSuggestionsImeListener);\
            }\
            mSuggestionsInsetObserver = mEmbedder.getInsetObserver();\
            if (mSuggestionsInsetObserver != null) {\
                mSuggestionsInsetObserver.addWindowInsetsAnimationListener(\
                        mSuggestionsImeListener);\
            }\
            // Alice patch end 0062' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^        getViewTreeObserver().removeOnPreDrawListener(mStickListener);$/a\
            // Alice patch start 0062\
            mAliceBottomViewportHeight = -1;\
            mAliceImeAnimationActive = false;\
            setClipBounds(null);\
            if (mSuggestionsInsetObserver != null) {\
                mSuggestionsInsetObserver.removeWindowInsetsAnimationListener(\
                        mSuggestionsImeListener);\
                mSuggestionsInsetObserver = null;\
            }\
            // Alice patch end 0062' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0062\
        if (mSuggestionsInsetObserver != null) {\
            mSuggestionsInsetObserver.removeWindowInsetsAnimationListener(\
                    mSuggestionsImeListener);\
            mSuggestionsInsetObserver = null;\
        }\
        // Alice patch end 0062' "$path1"

# 下拉列表支持底部锚定滚动。
sed -i '/^        private @Nullable Callback<Integer> mScrollOffsetListener;$/a\
        // Alice patch start 0062\
        private boolean mAliceBottomAnchored;\
\
        void setAliceBottomAnchored(boolean bottomAnchored) {\
            if (mAliceBottomAnchored == bottomAnchored) return;\
            mAliceBottomAnchored = bottomAnchored;\
            mIsScrolledToTop = !bottomAnchored;\
        }\
        // Alice patch end 0062' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^            if (OmniboxFeatures\.sResetSuggestionsScroll\.isEnabled()) {$/c\
            // Alice patch start 0062\
            if (OmniboxFeatures.sResetSuggestionsScroll.isEnabled()\
                    \&\& !mAliceBottomAnchored) {\
            // Alice patch end 0062' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^    private float mChildAlpha = 1.0f;$/a\
    // Alice patch start 0062\
    private boolean mAliceBottomAnchored;\
    // Alice patch end 0062' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^    public void resetSelection() {$/,/^    }$/c\
    public void resetSelection() {\
        // Alice patch start 0062\
        if (!mAliceBottomAnchored) {\
            mLayoutScrollListener.scrollToPositionWithOffset(0, 0);\
        }\
        // Alice patch end 0062\
        mSelectionController.reset();\
    }' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^            if (!mIsScrolledToTop) return;$/c\
            // Alice patch start 0062\
            if (!mIsScrolledToTop || mAliceBottomAnchored) return;\
            // Alice patch end 0062' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^                int resultingDeltaY, int requestedDeltaY) {$/a\
            // Alice patch start 0062\
            if (mAliceBottomAnchored) return resultingDeltaY;\
            // Alice patch end 0062' "$path4"
# 修改对应源码以完成本补丁功能。
sed -i '/^    public void translateChildrenVertical(float translation) {$/,/^    }$/c\
    public void translateChildrenVertical(float translation) {\
        mChildVerticalTranslation = translation;\
        final int childCount = getChildCount();\
        for (int i = 0; i < childCount; i++) {\
            getChildAt(i).setTranslationY(translation);\
        }\
        invalidateItemDecorations();\
    }\
\
    // Alice patch start 0062\
    void setAliceBottomAnchored(boolean bottomAnchored) {\
        mAliceBottomAnchored = bottomAnchored;\
        mLayoutScrollListener.setAliceBottomAnchored(bottomAnchored);\
    }\
    // Alice patch end 0062' "$path4"

# 重写建议容器吸附逻辑。
sed -i '/^    private boolean stickToAnchor() {$/,/^    }$/c\
    // Alice patch start 0062\
    private void setAliceDropdownStackFromEnd(boolean stackFromEnd) {\
        mDropdown.setAliceBottomAnchored(stackFromEnd);\
        androidx.recyclerview.widget.RecyclerView.LayoutManager aliceLayoutManager =\
                mDropdown.getLayoutManager();\
        if (!(aliceLayoutManager\
                instanceof androidx.recyclerview.widget.LinearLayoutManager)) return;\
        androidx.recyclerview.widget.LinearLayoutManager aliceLinearLayoutManager =\
                (androidx.recyclerview.widget.LinearLayoutManager) aliceLayoutManager;\
        if (aliceLinearLayoutManager.getStackFromEnd() != stackFromEnd) {\
            aliceLinearLayoutManager.setStackFromEnd(stackFromEnd);\
        }\
    }\
\
    private boolean updateAliceDropdownViewportHeight(int height) {\
        if (height <= 0) return false;\
        ViewGroup.LayoutParams aliceDropdownParams = mDropdown.getLayoutParams();\
        if (aliceDropdownParams.height == height \&\& mDropdown.getHeight() == height) {\
            return false;\
        }\
        aliceDropdownParams.height = height;\
        int aliceWidth = mDropdown.getWidth();\
        if (aliceWidth > 0) {\
            mDropdown.forceLayout();\
            mDropdown.measure(\
                    MeasureSpec.makeMeasureSpec(aliceWidth, MeasureSpec.EXACTLY),\
                    MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY));\
            mDropdown.layout(\
                    mDropdown.getLeft(), 0, mDropdown.getLeft() + aliceWidth, height);\
        }\
        return true;\
    }\
\
    private boolean stickToAnchor() {\
        if (mDropdown == null) return true;\
        if (getTranslationY() != 0) setTranslationY(0);\
        if (mEmbedder == null || !mEmbedder.isToolbarOnBottom()) {\
            setAliceDropdownStackFromEnd(false);\
            mAliceBottomViewportHeight = -1;\
            mAliceImeAnimationActive = false;\
            setClipBounds(null);\
            return true;\
        }\
        if (mDropdown.getVisibility() != View.VISIBLE) return true;\
        View aliceParent =\
                mDropdown.getParent() instanceof View ? (View) mDropdown.getParent() : null;\
        while (aliceParent instanceof ViewGroup) {\
            ((ViewGroup) aliceParent).setClipChildren(true);\
            ((ViewGroup) aliceParent).setClipToPadding(true);\
            aliceParent =\
                    aliceParent.getParent() instanceof View\
                            ? (View) aliceParent.getParent()\
                            : null;\
        }\
        mEmbedder.getAnchorView().getLocationInWindow(mStickPosition);\
        int aliceTargetTop = mStickPosition[1];\
        getLocationInWindow(mStickPosition);\
        int aliceContainerTop = mStickPosition[1];\
        if (aliceTargetTop <= aliceContainerTop || getWidth() <= 0) return true;\
        if (mAliceImeAnimationActive) {\
            updateAliceBottomAnchoredPosition(aliceTargetTop, aliceContainerTop);\
        } else {\
            updateAliceSettledViewport(aliceTargetTop, aliceContainerTop);\
        }\
        setClipBounds(null);\
        return true;\
    }\
    // Alice patch end 0062' "$path1"

# 测量和属性绑定沿用底部锚定状态。
sed -i '/^            int availableViewportHeight = mOmniboxAlignment\.height;$/c\
            // Alice patch start 0062\
            int availableViewportHeight = MeasureSpec.getSize(heightMeasureSpec);\
            if (availableViewportHeight <= 0) availableViewportHeight = mOmniboxAlignment.height;\
            // Alice patch end 0062' "$path1"
# 修改对应源码以完成本补丁功能。
sed -i '/^        } else if (propertyKey == SuggestionListProperties\.CHILD_TRANSLATION_Y) {$/,/^        } else if (propertyKey == SuggestionListProperties\.COLOR_SCHEME) {$/c\
        // Alice patch start 0062\
        } else if (propertyKey == SuggestionListProperties.CHILD_TRANSLATION_Y) {\
            float aliceTranslation = model.get(SuggestionListProperties.CHILD_TRANSLATION_Y);\
            if (model.containsKey(SuggestionListProperties.TOOLBAR_ON_BOTTOM)\
                    \&\& model.get(SuggestionListProperties.TOOLBAR_ON_BOTTOM)) {\
                aliceTranslation = 0;\
            }\
            view.dropdown.translateChildrenVertical(aliceTranslation);\
        // Alice patch end 0062\
        } else if (propertyKey == SuggestionListProperties.COLOR_SCHEME) {' "$path2"
# 修改对应源码以完成本补丁功能。
sed -i '/^        } else if (propertyKey == SuggestionListProperties\.ALPHA) {$/,/^        } else if (propertyKey == SuggestionListProperties\.APPLY_MARGIN_FOR_LEFT_SIDE_BAR) {$/c\
        // Alice patch start 0062\
        } else if (propertyKey == SuggestionListProperties.ALPHA) {\
            float aliceAlpha = model.get(SuggestionListProperties.ALPHA);\
            if (model.containsKey(SuggestionListProperties.TOOLBAR_ON_BOTTOM)\
                    \&\& model.get(SuggestionListProperties.TOOLBAR_ON_BOTTOM)) {\
                aliceAlpha = 1f;\
            }\
            view.dropdown.setChildAlpha(aliceAlpha);\
        // Alice patch end 0062\
        } else if (propertyKey == SuggestionListProperties.APPLY_MARGIN_FOR_LEFT_SIDE_BAR) {' "$path2"
# 修改对应源码以完成本补丁功能。
sed -i '/^        } else if (propertyKey == SuggestionListProperties\.CONTAINER_ALWAYS_VISIBLE) {$/i\
        // Alice patch start 0062\
        } else if (propertyKey == SuggestionListProperties.TOOLBAR_ON_BOTTOM) {\
            updateColorScheme(model, view);\
        // Alice patch end 0062\
' "$path2"

# 底部锚定时容器透明、下拉列表使用建议背景色。
sed -i '/^    private void updateColorScheme(PropertyModel model, SuggestionListViewHolder holder) {$/,/^    }$/c\
    private void updateColorScheme(PropertyModel model, SuggestionListViewHolder holder) {\
        @FuseboxLayoutMode int layoutMode = model.get(SuggestionListProperties.FUSEBOX_LAYOUT_MODE);\
        @ColorInt\
        int backgroundColor =\
                getResourceProvider(model)\
                        .getSuggestionBackgroundColor(layoutMode, /* isDropdownContainer= */ true);\
        boolean aliceBottomAnchored =\
                model.containsKey(SuggestionListProperties.TOOLBAR_ON_BOTTOM)\
                        \&\& model.get(SuggestionListProperties.TOOLBAR_ON_BOTTOM);\
        holder.dropdown.setBackgroundColor(backgroundColor);\
        if (aliceBottomAnchored\
                || (model.get(SuggestionListProperties.IS_LARGE_SCREEN)\
                        \&\& layoutMode != FuseboxLayoutMode.SUGGESTIONS_POPOVER)) {\
            holder.container.setBackgroundColor(Color.TRANSPARENT);\
        } else {\
            holder.container.setBackgroundColor(backgroundColor);\
        }\
    }' "$path2"
# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.build\.annotations\.NullMarked;$/a\
// Alice patch start 0062\
import org.chromium.build.annotations.Nullable;\
// Alice patch end 0062' "$path2"
# 修改对应源码以完成本补丁功能。
sed -i '/^            listItems\.addObserver($/,/^                    });$/c\
            // Alice patch start 0062\
            listItems.addObserver(\
                    new ListObservable.ListObserver<>() {\
                        @Override\
                        public void onItemRangeInserted(\
                                ListObservable source, int index, int count) {\
                            view.dropdown.resetSelection();\
                            updateContainerVisibility(model, view);\
                        }\
\
                        @Override\
                        public void onItemRangeRemoved(\
                                ListObservable source, int index, int count) {\
                            updateContainerVisibility(model, view);\
                        }\
\
                        @Override\
                        public void onItemRangeChanged(\
                                ListObservable<Void> source,\
                                int index,\
                                int count,\
                                @Nullable Void payload) {}\
                    });\
            // Alice patch end 0062' "$path2"

# 增加工具栏位置属性并向建议模型传入。
sed -i '/^    ReadableObjectPropertyKey<ModelList> SUGGESTION_MODELS = new ReadableObjectPropertyKey<>();$/a\
\
    // Alice patch start 0062\
    WritableBooleanPropertyKey TOOLBAR_ON_BOTTOM = new WritableBooleanPropertyKey();\
    // Alice patch end 0062' "$path8"
# 修改对应源码以完成本补丁功能。
sed -i '/^                SUGGESTION_MODELS,$/i\
                // Alice patch start 0062\
                TOOLBAR_ON_BOTTOM,\
                // Alice patch end 0062\
' "$path8"
# 修改对应源码以完成本补丁功能。
sed -i '/^import org\.chromium\.build\.annotations\.Nullable;$/a\
// Alice patch start 0062\
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider.ControlsPosition;\
// Alice patch end 0062' "$path9"
# 修改对应源码以完成本补丁功能。
sed -i '/^                        \.with(SuggestionListProperties\.SUGGESTION_MODELS, listItems)$/a\
                        // Alice patch start 0062\
                        .with(\
                                SuggestionListProperties.TOOLBAR_ON_BOTTOM,\
                                locationBarDataProvider.getToolbarPositionSupplier().get()\
                                        == ControlsPosition.BOTTOM)\
                        // Alice patch end 0062\
' "$path9"
# 工具栏位置变化时同步建议列表的底部锚定状态。
sed -i '/^    private void onToolbarPositionChanged() {$/a\
        // Alice patch start 0062\
        mListPropertyModel.set(\
                SuggestionListProperties.TOOLBAR_ON_BOTTOM,\
                mDataProvider.getToolbarPositionSupplier().get() == ControlsPosition.BOTTOM);\
        // Alice patch end 0062\
' "$path10"
