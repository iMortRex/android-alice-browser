#!/bin/bash
# 标签页网格：等待真实布局尺寸后执行初始滚动，并稳定动画几何。

set -e

path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListContainerViewBinder.java"
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListRecyclerView.java"
path4="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"

# 检测是否已应用
if grep -q 'Alice patch start 0048' "$path1"; then
    exit 100
fi

# 首次布局完成后再按真实尺寸计算初始滚动位置。
sed -i '/^        } else if (INITIAL_SCROLL_INDEX == propertyKey) {$/,/^        } else if (FOCUS_TAB_INDEX_FOR_ACCESSIBILITY == propertyKey) {$/c\
        } else if (INITIAL_SCROLL_INDEX == propertyKey) {\
            int index = model.get(INITIAL_SCROLL_INDEX);\
            // Alice patch start 0048\
            if (recyclerView.isLaidOut()\
                    \&\& recyclerView.getWidth() > 0\
                    \&\& recyclerView.getHeight() > 0) {\
                recyclerView.scrollToPositionWithOffset(\
                        index, computeOffset(recyclerView, model));\
            } else {\
                recyclerView.addOnLayoutChangeListener(\
                        new View.OnLayoutChangeListener() {\
                            @Override\
                            public void onLayoutChange(\
                                    View v,\
                                    int left,\
                                    int top,\
                                    int right,\
                                    int bottom,\
                                    int oldLeft,\
                                    int oldTop,\
                                    int oldRight,\
                                    int oldBottom) {\
                                if (recyclerView.getWidth() <= 0\
                                        || recyclerView.getHeight() <= 0) {\
                                    return;\
                                }\
                                recyclerView.removeOnLayoutChangeListener(this);\
                                recyclerView.scrollToPositionWithOffset(\
                                        index, computeOffset(recyclerView, model));\
                            }\
                        });\
                recyclerView.requestLayout();\
            }\
            // Alice patch end 0048\
        } else if (FOCUS_TAB_INDEX_FOR_ACCESSIBILITY == propertyKey) {' "$path2"

# 记录初始滚动请求和等待状态。
sed -i '/^    private boolean mBlockTouchInput;$/a\
    // Alice patch start 0048\
    private boolean mAliceInitialScrollRequested;\
    private @Nullable Runnable mAliceInitialScrollCompletionRunnable;\
    private int mAliceInitialScrollIndex;\
    private int mAliceInitialScrollOffset;\
    private int mAliceInitialScrollWaitFrames;\
    // Alice patch end 0048' "$path3"

# 布局变化后重新检查初始滚动是否已经稳定。
sed -i '/^        super\.onLayout(changed, l, t, r, b);$/a\
        // Alice patch start 0048\
        if (mAliceInitialScrollRequested\
                \&\& mAliceInitialScrollCompletionRunnable != null) {\
            postOnAnimation(this::maybeRunAliceInitialScrollCompletion);\
        }\
        // Alice patch end 0048' "$path3"

# 新增滚动等待和稳定帧检测方法。
sed -i '/^    Rect getRectOfTabThumbnail(int tabIndex) {$/i\
    // Alice patch start 0048\
    void scrollToPositionWithOffset(int index, int offset) {\
        LinearLayoutManager layoutManager =\
                assumeNonNull((LinearLayoutManager) getLayoutManager());\
        mAliceInitialScrollRequested = true;\
        mAliceInitialScrollIndex = index;\
        mAliceInitialScrollOffset = offset;\
        mAliceInitialScrollWaitFrames = 0;\
        layoutManager.scrollToPositionWithOffset(index, offset);\
        if (!isLayoutRequested()) {\
            requestLayout();\
        }\
    }\
\
    void runAfterInitialScroll(Runnable runnable) {\
        if (mAliceInitialScrollRequested) {\
            mAliceInitialScrollCompletionRunnable = runnable;\
        } else {\
            postOnAnimation(runnable);\
        }\
    }\
\
    private void maybeRunAliceInitialScrollCompletion() {\
        if (!mAliceInitialScrollRequested) return;\
        @Nullable Runnable completionRunnable = mAliceInitialScrollCompletionRunnable;\
        if (completionRunnable == null) return;\
        if (!isAliceInitialScrollSettled() \&\& mAliceInitialScrollWaitFrames++ < 6) {\
            postOnAnimation(this::maybeRunAliceInitialScrollCompletion);\
            return;\
        }\
        mAliceInitialScrollRequested = false;\
        mAliceInitialScrollWaitFrames = 0;\
        mAliceInitialScrollCompletionRunnable = null;\
        completionRunnable.run();\
    }\
\
    private boolean isAliceInitialScrollSettled() {\
        LinearLayoutManager layoutManager = (LinearLayoutManager) getLayoutManager();\
        if (layoutManager == null) return false;\
        View targetView = layoutManager.findViewByPosition(mAliceInitialScrollIndex);\
        if (targetView == null) return false;\
        int expectedTop = getPaddingTop() + mAliceInitialScrollOffset;\
        int actualTop = targetView.getTop();\
        if (actualTop == expectedTop) return true;\
        int firstComplete = layoutManager.findFirstCompletelyVisibleItemPosition();\
        int lastComplete = layoutManager.findLastCompletelyVisibleItemPosition();\
        int itemCount = getAdapter() == null ? 0 : getAdapter().getItemCount();\
        return (firstComplete == 0 \&\& actualTop <= expectedTop)\
                || (itemCount > 0 \&\& lastComplete == itemCount - 1 \&\& actualTop >= expectedTop);\
    }\
    // Alice patch end 0048\
' "$path3"

# 将布局等待回调放到初始滚动完成之后。
sed -i 's|^        mRecyclerView\.runOnNextLayout(this::checkAwaitingLayout);$|        // Alice patch start 0048\n        mRecyclerView.runAfterInitialScroll(\n                () -> mRecyclerView.post(this::checkAwaitingLayout));\n        // Alice patch end 0048|' "$path1"

# 布局尚未完成或仍请求布局时继续等待，避免读取旧几何。
sed -i '/^    private void checkAwaitingLayout() {$/,/^        if (mAwaitingLayoutRunnable != null) {$/ s#^        if (mAwaitingLayoutRunnable != null) {$#        if (mAwaitingLayoutRunnable != null) {\
            // Alice patch start 0048\
            if (!mRecyclerView.isLaidOut()) {\
                if (mAliceAwaitingLayoutReadyListener == null) {\
                    mAliceAwaitingLayoutReadyListener =\
                            (v,\
                                    left,\
                                    top,\
                                    right,\
                                    bottom,\
                                    oldLeft,\
                                    oldTop,\
                                    oldRight,\
                                    oldBottom) -> {\
                                if (mRecyclerView.getWidth() <= 0\
                                        || mRecyclerView.getHeight() <= 0) {\
                                    return;\
                                }\
                                mRecyclerView.removeOnLayoutChangeListener(\
                                        mAliceAwaitingLayoutReadyListener);\
                                mAliceAwaitingLayoutReadyListener = null;\
                                mRecyclerView.post(this::checkAwaitingLayout);\
                            };\
                    mRecyclerView.addOnLayoutChangeListener(mAliceAwaitingLayoutReadyListener);\
                    mRecyclerView.requestLayout();\
                }\
                return;\
            }\
            if (mRecyclerView.isLayoutRequested()) {\
                mRecyclerView.postOnAnimation(this::checkAwaitingLayout);\
                return;\
            }\
            // Alice patch end 0048#' "$path1"

# holder 尚未就绪时延迟到下一帧重新检查。
sed -i '/^            if (holder == null) return;$/c\
            // Alice patch start 0048\
            if (holder == null) {\
                mRecyclerView.postOnAnimation(this::checkAwaitingLayout);\
                return;\
            }\
            // Alice patch end 0048' "$path1"

# 在收缩动画数据创建前先设置初始滚动索引偏移。
sed -i '0,/^        SyncOneshotSupplier<ShrinkExpandAnimationData> animationDataSupplier =$/s//        \/\/ Alice patch start 0048\n        setInitialScrollIndexOffset();\n        \/\/ Alice patch end 0048\n&/' "$path4"

# 展开动画不再等待 Tab 布局，改为下一帧直接提供动画数据。
sed -i 's|^        coordinator\.waitForLayoutWithTab(tabId, provideAnimationData);$|        // Alice patch start 0048\
        if (isShrink) {\
            coordinator.waitForLayoutWithTab(tabId, provideAnimationData);\
        } else {\
            hubContainerView.postOnAnimation(provideAnimationData);\
        }\
        // Alice patch end 0048|' "$path4"

# 记录等待中的卡片几何，确保动画读取连续稳定的位置。
sed -i '/^    private @Nullable PropertyModel mAwaitingModel;$/a\
    // Alice patch start 0048\
    private final Rect mAliceAwaitingGeometryRect = new Rect();\
    private int mAliceAwaitingGeometryStableFrames;\
    private @Nullable OnLayoutChangeListener mAliceAwaitingLayoutReadyListener;\
    // Alice patch end 0048' "$path1"

sed -i '/^        mTabListFaviconProvider\.destroy\(\);$/i\
        // Alice patch start 0048\
        if (mAliceAwaitingLayoutReadyListener != null) {\
            mRecyclerView.removeOnLayoutChangeListener(mAliceAwaitingLayoutReadyListener);\
            mAliceAwaitingLayoutReadyListener = null;\
        }\
        // Alice patch end 0048' "$path1"

# 切换等待中的 Tab 时重置几何稳定帧状态。
sed -i '/^        mAwaitingModel = mModelList.get(index)\.model;$/a\
        // Alice patch start 0048\
        mAliceAwaitingGeometryRect.setEmpty();\
        mAliceAwaitingGeometryStableFrames = 0;\
        // Alice patch end 0048' "$path1"

# 卡片几何连续 3 帧不变后再继续动画，避免使用布局中间态。
sed -i '/^            assert assumeNonNull(holder\.model) == mAwaitingModel;$/i\
            // Alice patch start 0048\
            Rect aliceGeometryRect = mRecyclerView.getRectOfTabThumbnail(index);\
            if (aliceGeometryRect.isEmpty()) {\
                mRecyclerView.postOnAnimation(this::checkAwaitingLayout);\
                return;\
            }\
            if (!aliceGeometryRect.equals(mAliceAwaitingGeometryRect)) {\
                mAliceAwaitingGeometryRect.set(aliceGeometryRect);\
                mAliceAwaitingGeometryStableFrames = 1;\
                mRecyclerView.postOnAnimation(this::checkAwaitingLayout);\
                return;\
            }\
            mAliceAwaitingGeometryStableFrames++;\
            if (mAliceAwaitingGeometryStableFrames < 3) {\
                mRecyclerView.postOnAnimation(this::checkAwaitingLayout);\
                return;\
            }\
            mAliceAwaitingGeometryStableFrames = 0;\
            // Alice patch end 0048\
' "$path1"
