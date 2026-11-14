#!/bin/bash
# 标签切换器「横向」样式（类 iOS 后台的横向堆叠卡片）
#   - 只有 设置-标签页和标签页分组-标签切换器 选中「横向」时生效，且只作用于标签切换器网格
#     （TabComponentId.GRID_TAB_SWITCHER）；标签组对话框 / 标签编辑器 / 底部标签条不受影响。
#   - 卡片高度 =（标签列表可视区高度 - 顶部工具栏 - 底部控制栏）×
#     AliceTabStackHelper.CARD_HEIGHT_FRACTION；宽度按网页内容区宽高比计算。
#   - 当前标签固定排在最后一张。中心卡前的卡片按紧凑间距向左堆叠，中心卡后的卡片按
#     大跨度向右展开；所有卡片左边不会越过屏幕左侧。
#   - 滚动停止时把离屏幕中心最近的卡片平滑吸附到中心。
#   - 向上滑关闭标签；禁止左右拖拽（左右滑只用来滚动卡片列表）。
#   - 设置里改样式后不用重启浏览器：下次打开标签管理页时会自动切换布局。
#   - 横向样式捕获缩略图时使用更高倍率；默认样式继续沿用 0038 的清晰度设置。

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridItemTouchHelperCallback.java"
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListContainerViewBinder.java"
path4="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
path5="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"
path6="alice/chromium_src/chrome/android/chrome_java_ext_sources.gni"
path7="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/pinned_tabs/PinnedTabStripCoordinator.java"
path8="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListMediator.java"
path9="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/SingleChildViewManager.java"
path10="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"
path11="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path12="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridView.java"

# 检测是否已应用
if grep -q 'Alice patch start 0036' "$path1"; then
    exit 100
fi

# ---------- 新增文件 ----------
mkdir -p "alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/tasks/tab_management"
cat > "alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/tasks/tab_management/AliceTabStackHelper.java" << 'ALICE_EOF'
// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.tasks.tab_management;

import android.animation.ValueAnimator;
import android.app.Activity;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.ViewParent;
import android.view.animation.DecelerateInterpolator;

import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.chrome.browser.browser_controls.BrowserControlsStateProvider;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;
import org.chromium.chrome.tab_ui.R;

import java.util.WeakHashMap;

/**
 * Alice: 标签切换器的「横向」样式（iOS 后台 / App Switcher 那样）。
 *
 * <p>卡片高度 = 去掉顶部工具栏和底部控制栏后的可视区高度 × {@link #CARD_HEIGHT_FRACTION}，
 * 宽度按网页内容区宽高比计算。中心卡由滚动进度决定，左侧卡片紧凑堆叠，右侧卡片大跨度展开；
 * 缩放随卡片相对中心卡的距离逐帧更新。
 *
 * <p>滚动时由 {@link #applyStackScales} 逐帧重算所有可见卡片的缩放，
 * 因此滑动过程中整组卡片都会连续变化。
 */
@NullMarked
public final class AliceTabStackHelper {
    /** SharedPreferences key（与设置页保持一致）。 */
    public static final String PREF_TAB_SWITCHER_STYLE = "alice_tab_switcher_style";

    /** 默认（上游样式）。 */
    public static final int STYLE_DEFAULT = 0;

    /** 竖向堆叠（暂未支持）。 */
    public static final int STYLE_VERTICAL = 1;

    /** 横向堆叠。 */
    public static final int STYLE_HORIZONTAL = 2;

    /** 卡片高度 = 去掉浏览器顶部/底部控制栏后的可用高度 × 这个比例。 */
    public static final float CARD_HEIGHT_FRACTION = 0.85f;

    /** 滚动一张卡片所需的位移，按卡片宽度比例计算。 */
    private static final float SCROLL_STEP_FRACTION = 0.6f;

    /** 中心卡左侧卡片的紧凑间距。 */
    private static final float LEFT_OFFSET_FRACTION = 0.16f;

    /** 中心卡到左侧第一张卡的单独间距。 */
    private static final float FIRST_LEFT_OFFSET_FRACTION = 0.15f;

    /** 右侧位移的线性分量。 */
    private static final float RIGHT_OFFSET_LINEAR_FRACTION = 0.48f;

    /** 右侧位移的二次加速分量，越大则后续卡片递增越快。 */
    private static final float RIGHT_OFFSET_QUADRATIC_FRACTION = 0.18f;

    private static final float MIN_SCALE = 0.5f;
    private static final float MAX_SCALE = 1.2f;

    /** 右侧缩放的线性基础项，保证中心附近仍有即时响应。 */
    private static final float RIGHT_SCALE_LINEAR = 0f;

    /** 右侧缩放的幂函数增幅。 */
    private static final float RIGHT_SCALE_AMPLITUDE = 0.025f;

    /** 右侧缩放的非线性指数。 */
    private static final float RIGHT_SCALE_EXPONENT = 1.0f;

    /** 竖直居中的微调：正数 = 整组卡片往下挪「可视区高度 × 这个比例」。 */
    private static final float VERTICAL_BIAS_FRACTION = 0.035f;

    /** 主线程 Handler：把可能触发布局的动作挪出当前布局流程。 */
    private static final Handler sMainHandler = new Handler(Looper.getMainLooper());

    /** 已经装到某个标签列表上的横向样式状态，卸载时要还回去。 */
    private static final WeakHashMap<RecyclerView, Integer> sPreviousOverScrollModes =
            new WeakHashMap<>();
    private static final WeakHashMap<RecyclerView, RecyclerView.OnScrollListener> sSnapListeners =
            new WeakHashMap<>();
    private static final WeakHashMap<View, Boolean> sStackCards = new WeakHashMap<>();

    private AliceTabStackHelper() {}

    /** 把动作放到主线程的下一个消息执行（不要在布局过程中直接改视图）。 */
    public static void postDeferred(Runnable runnable) {
        sMainHandler.post(runnable);
    }

    /** @return 用户选择的标签切换器样式。 */
    public static int getStyle() {
        return ChromeSharedPreferences.getInstance()
                .readInt(PREF_TAB_SWITCHER_STYLE, STYLE_DEFAULT);
    }

    /** @return 实际生效的样式（竖向还没做，按默认样式处理）。 */
    public static int getEffectiveStyle() {
        return getStyle() == STYLE_HORIZONTAL ? STYLE_HORIZONTAL : STYLE_DEFAULT;
    }

    /** @return 这个容器是不是标签切换器网格（只有它受「标签切换器」设置影响）。 */
    public static boolean isGridTabSwitcher(int componentId) {
        return componentId == TabComponentId.GRID_TAB_SWITCHER;
    }

    /** @return 这个容器是不是要用横向堆叠样式。 */
    public static boolean isHorizontalStack(int componentId) {
        return isGridTabSwitcher(componentId) && getEffectiveStyle() == STYLE_HORIZONTAL;
    }

    /** @return 这个 RecyclerView 当前是不是横向堆叠布局。 */
    public static boolean isStackLayout(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return false;
        return recyclerView.getLayoutManager() instanceof AliceStackLayoutManager;
    }

    /** @return 该 View 是否属于横向牌堆，包括尚未直接挂到 RecyclerView 的阶段。 */
    public static boolean isInStackLayout(@Nullable View view) {
        if (view == null) return false;
        if (sStackCards.containsKey(view)) return true;
        ViewParent parent = view.getParent();
        while (parent != null) {
            if (parent instanceof RecyclerView recyclerView) {
                return isStackLayout(recyclerView);
            }
            parent = parent.getParent();
        }
        return false;
    }

    /** @return 列表可视区高度（去掉 padding）。 */
    private static int getContentHeight(RecyclerView recyclerView) {
        return Math.max(
                0,
                recyclerView.getHeight()
                        - recyclerView.getPaddingTop()
                        - recyclerView.getPaddingBottom());
    }

    /**
     * @return 卡片可用高度（px）：标签列表可视区去掉顶部工具栏和底部控制栏后的高度。
     */
    private static int getCardAreaHeight(
            RecyclerView recyclerView, BrowserControlsStateProvider browserControls) {
        return Math.max(
                0,
                getContentHeight(recyclerView)
                        - getVisibleBrowserControlsHeight(browserControls));
    }

    /** @return 卡片高度（px）：不含顶部工具栏和底部控制栏。 */
    public static int getCardHeightPx(
            RecyclerView recyclerView, BrowserControlsStateProvider browserControls) {
        return Math.max(
                1,
                Math.round(getCardAreaHeight(recyclerView, browserControls)
                        * CARD_HEIGHT_FRACTION));
    }

    /**
     * @return 卡片宽度（px）：按窗口（App 窗口）的宽高比算，也就是「窗口高矮比例」，
     *         卡片形状和窗口一致。
     */
    public static int getCardWidthPx(
            Activity activity,
            int cardHeightPx,
            BrowserControlsStateProvider browserControls) {
        final android.content.res.Resources resources = activity.getResources();
        final int cardMarginPx =
                resources.getDimensionPixelSize(R.dimen.tab_grid_card_margin);
        final int headerHeightPx =
                resources.getDimensionPixelSize(R.dimen.tab_grid_card_header_height);
        final int thumbnailMarginPx =
                resources.getDimensionPixelSize(R.dimen.tab_grid_card_thumbnail_margin);
        final int verticalInsetsPx =
                headerHeightPx + 2 * cardMarginPx + thumbnailMarginPx;
        final int horizontalInsetsPx = 2 * (cardMarginPx + thumbnailMarginPx);
        final int contentHeightPx = Math.max(1, cardHeightPx - verticalInsetsPx);
        final int contentWidthPx =
                Math.round(contentHeightPx * getPageAspectRatio(activity, browserControls));
        return Math.max(1, contentWidthPx + horizontalInsetsPx);
    }

    /** @return 网页内容区的宽高比（不含顶部工具栏和底部控制栏）。 */
    public static float getPageAspectRatio(
            Activity activity, BrowserControlsStateProvider browserControls) {
        final Rect frame = new Rect();
        activity.getWindow().getDecorView().getWindowVisibleDisplayFrame(frame);
        final int pageHeight =
                frame.height() - getVisibleBrowserControlsHeight(browserControls);
        if (frame.width() <= 0 || pageHeight <= 0) return 0.5f;
        return (float) frame.width() / pageHeight;
    }

    /** @return 当前实际占用网页高度的顶部和底部浏览器控制栏。 */
    private static int getVisibleBrowserControlsHeight(
            BrowserControlsStateProvider browserControls) {
        final int topControlsHeight =
                Math.max(0, Math.round(browserControls.getTopVisibleContentOffset()));
        final int bottomControlsHeight =
                Math.max(
                        0,
                        browserControls.getBottomControlsHeight()
                                - browserControls.getBottomControlOffset());
        return topControlsHeight + bottomControlsHeight;
    }

    /** 与参考 HTML 一致：按相对中心卡距离计算非线性缩放。 */
    private static float getScaleForDistance(float distance) {
        float scale = 1f;
        if (distance > 0) {
            scale =
                    1f
                            + distance * RIGHT_SCALE_LINEAR
                            + (float) Math.pow(distance, RIGHT_SCALE_EXPONENT)
                                    * RIGHT_SCALE_AMPLITUDE;
        } else if (distance < 0) {
            scale = 1f - (float) Math.pow(-distance, 1.25f) * 0.02f;
        }
        return Math.max(MIN_SCALE, Math.min(MAX_SCALE, scale));
    }

    /** @return 卡片相对中心卡的横向位移，左侧紧凑、右侧大跨度，并贴合屏幕左边缘。 */
    private static float getTranslationForDistance(
            float distance,
            int viewportWidth,
            int cardWidthPx,
            float scale,
            int cardInsetPx) {
        float translation;
        if (distance >= 0) {
            translation =
                    cardWidthPx
                            * (distance * RIGHT_OFFSET_LINEAR_FRACTION
                                    + distance
                                            * distance
                                            * RIGHT_OFFSET_QUADRATIC_FRACTION);
        } else {
            final float firstGapProgress = Math.min(1f, -distance);
            translation =
                    -firstGapProgress * cardWidthPx * FIRST_LEFT_OFFSET_FRACTION;
            if (distance < -1f) {
                translation +=
                        (distance + 1f) * cardWidthPx * LEFT_OFFSET_FRACTION;
            }
        }
        final float leftEdgeTranslation =
                -viewportWidth / 2f + cardWidthPx * scale / 2f - cardInsetPx;
        return distance < 0 ? Math.max(translation, leftEdgeTranslation) : translation;
    }

    /** @return 指定索引在当前滚动进度下的屏幕左边位置。 */
    private static int getCardLeftPx(
            float progress,
            int position,
            int viewportWidth,
            int cardWidthPx,
            int cardInsetPx) {
        final float distance = position - progress;
        final float scale = getScaleForDistance(distance);
        final float translation =
                getTranslationForDistance(
                        distance, viewportWidth, cardWidthPx, scale, cardInsetPx);
        return Math.round((viewportWidth - cardWidthPx) / 2f + translation);
    }

    /** @return 卡片居中时的左边位置。 */
    private static int getCurrentCardScreenLeftPx(int parentWidth, int cardWidthPx) {
        return Math.max(0, (parentWidth - cardWidthPx) / 2);
    }

    /** @return 当前卡片居中时的滚动偏移。 */
    public static int getCardLeftPx(
            BrowserControlsStateProvider browserControls,
            RecyclerView recyclerView) {
        if (recyclerView.getAdapter() == null) return 0;
        final int itemCount = recyclerView.getAdapter().getItemCount();
        if (itemCount <= 0) return 0;
        final int cardHeightPx = getCardHeightPx(recyclerView, browserControls);
        final int cardWidthPx =
                getCardWidthPx(
                        (Activity) recyclerView.getContext(),
                        cardHeightPx,
                        browserControls);
        return getCurrentCardScreenLeftPx(recyclerView.getWidth(), cardWidthPx);
    }

    /**
     * 装上横向牌堆滚动实现。所有卡片位置由自定义 LayoutManager 统一计算，不使用负 ItemDecoration。
     *
     * @param recyclerView 标签列表的 RecyclerView。
     * @param browserControls 用于计算卡片可用高度。
     * @param onLayoutCompleted 布局完成后的回调。
     */
    public static void setUp(
            RecyclerView recyclerView,
            BrowserControlsStateProvider browserControls,
            @Nullable Runnable onLayoutCompleted) {
        tearDown(recyclerView);
        final int previousOverScrollMode = recyclerView.getOverScrollMode();
        sPreviousOverScrollModes.put(recyclerView, previousOverScrollMode);
        recyclerView.setOverScrollMode(View.OVER_SCROLL_NEVER);
        AliceStackLayoutManager layoutManager =
                new AliceStackLayoutManager(
                        recyclerView, browserControls, onLayoutCompleted);
        recyclerView.setLayoutManager(layoutManager);
        RecyclerView.OnScrollListener snapListener =
                new RecyclerView.OnScrollListener() {
                    @Override
                    public void onScrollStateChanged(RecyclerView recyclerView, int newState) {
                        if (newState == RecyclerView.SCROLL_STATE_DRAGGING) {
                            layoutManager.onDragStarted();
                        } else if (newState == RecyclerView.SCROLL_STATE_IDLE) {
                            layoutManager.snapToNearestCard();
                        }
                    }
                };
        sSnapListeners.put(recyclerView, snapListener);
        recyclerView.addOnScrollListener(snapListener);
        recyclerView.requestLayout();
    }

    /** 卸载横向堆叠样式（切回「默认」样式之前调用）。 */
    public static void tearDown(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return;
        Integer previousOverScrollMode = sPreviousOverScrollModes.remove(recyclerView);
        if (previousOverScrollMode != null) {
            recyclerView.setOverScrollMode(previousOverScrollMode);
        }
        RecyclerView.OnScrollListener snapListener = sSnapListeners.remove(recyclerView);
        if (snapListener != null) {
            recyclerView.removeOnScrollListener(snapListener);
        }
        for (int i = 0; i < recyclerView.getChildCount(); i++) {
            View child = recyclerView.getChildAt(i);
            if (child == null) continue;
            sStackCards.remove(child);
            resetChildTransform(child);
            child.setTranslationX(0f);
        }
    }

    /** 按相对中心卡的距离更新缩放。 */
    public static void applyStackScales(RecyclerView recyclerView) {
        if (!isStackLayout(recyclerView)) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (!(layoutManager instanceof AliceStackLayoutManager stackLayoutManager)) return;
        final float progress = stackLayoutManager.getProgress();
        final int itemCount =
                recyclerView.getAdapter() == null
                        ? 0
                        : recyclerView.getAdapter().getItemCount();
        for (int i = 0; i < recyclerView.getChildCount(); i++) {
            View child = recyclerView.getChildAt(i);
            if (child == null) continue;
            final int position = recyclerView.getChildAdapterPosition(child);
            if (position == RecyclerView.NO_POSITION) continue;
            applyChildTransform(child, position - progress);
        }
    }

    private static void applyChildTransform(View child, float distance) {
        final float scale = getScaleForDistance(distance);
        child.setPivotX(child.getWidth() / 2f);
        child.setPivotY(child.getHeight() / 2f);
        child.setScaleX(scale);
        child.setScaleY(scale);
        child.setTranslationX(0f);
    }

    private static void resetChildTransform(View child) {
        child.setScaleX(1f);
        child.setScaleY(1f);
    }

    /** 用中心卡进度驱动整组卡片布局。 */
    private static final class AliceStackLayoutManager extends LinearLayoutManager {
        private final RecyclerView mRecyclerView;
        private final BrowserControlsStateProvider mBrowserControls;
        private final @Nullable Runnable mOnLayoutCompleted;

        private float mProgress;
        private boolean mPendingScroll;
        private int mPendingPosition = RecyclerView.NO_POSITION;
        private boolean mDidInitialLayout;
        private @Nullable ValueAnimator mSnapAnimator;
        private final Runnable mSnapRunnable = this::performSnap;

        AliceStackLayoutManager(
                RecyclerView recyclerView,
                BrowserControlsStateProvider browserControls,
                @Nullable Runnable onLayoutCompleted) {
            super(recyclerView.getContext(), LinearLayoutManager.HORIZONTAL, false);
            mRecyclerView = recyclerView;
            mBrowserControls = browserControls;
            mOnLayoutCompleted = onLayoutCompleted;
        }

        @Override
        public void onLayoutChildren(RecyclerView.Recycler recycler, RecyclerView.State state) {
            final int itemCount = state.getItemCount();
            if (itemCount == 0) {
                removeAndRecycleAllViews(recycler);
                mProgress = 0f;
                mPendingScroll = false;
                mDidInitialLayout = false;
                runLayoutCompleted();
                return;
            }

            final int cardWidthPx = getLayoutCardWidthPx();
            final int cardHeightPx = getLayoutCardHeightPx();
            if (mPendingScroll && mPendingPosition != RecyclerView.NO_POSITION) {
                final int position =
                        Math.max(0, Math.min(itemCount - 1, mPendingPosition));
                mProgress = clampProgress(position, itemCount);
                mPendingScroll = false;
                mPendingPosition = RecyclerView.NO_POSITION;
            } else if (!mDidInitialLayout) {
                mProgress = itemCount - 1f;
            } else {
                mProgress = clampProgress(mProgress, itemCount);
            }
            mDidInitialLayout = true;

            detachAndScrapAttachedViews(recycler);
            fillVisible(recycler, itemCount, cardWidthPx, cardHeightPx);
            runLayoutCompleted();
        }

        @Override
        public int scrollHorizontallyBy(
                int dx, RecyclerView.Recycler recycler, RecyclerView.State state) {
            final int itemCount = state.getItemCount();
            if (itemCount == 0 || dx == 0) return 0;

            final int cardWidthPx = getLayoutCardWidthPx();
            final int cardHeightPx = getLayoutCardHeightPx();
            final float stepPx = cardWidthPx * SCROLL_STEP_FRACTION;
            final float targetProgress =
                    clampProgress(mProgress + dx / stepPx, itemCount);
            if (targetProgress == mProgress) return 0;

            mProgress = targetProgress;
            fillVisible(recycler, itemCount, cardWidthPx, cardHeightPx);
            return dx;
        }

        void onDragStarted() {
            mRecyclerView.removeCallbacks(mSnapRunnable);
            ValueAnimator animator = mSnapAnimator;
            mSnapAnimator = null;
            if (animator != null) animator.cancel();
        }

        void snapToNearestCard() {
            mRecyclerView.removeCallbacks(mSnapRunnable);
            mRecyclerView.post(mSnapRunnable);
        }

        private void performSnap() {
            if (mRecyclerView.getScrollState() != RecyclerView.SCROLL_STATE_IDLE) return;
            if (mSnapAnimator != null && mSnapAnimator.isRunning()) return;
            final int itemCount =
                    mRecyclerView.getAdapter() == null
                            ? 0
                            : mRecyclerView.getAdapter().getItemCount();
            if (itemCount <= 1) return;

            final int targetProgress = Math.round(mProgress);
            if (Math.abs(targetProgress - mProgress) < 0.001f) return;

            final float startProgress = mProgress;
            final ValueAnimator animator =
                    ValueAnimator.ofFloat(startProgress, targetProgress);
            mSnapAnimator = animator;
            animator.setDuration(220);
            animator.setInterpolator(new DecelerateInterpolator());
            animator.addUpdateListener(
                    animation -> {
                        final float nextProgress = (float) animation.getAnimatedValue();
                        final float stepPx =
                                getLayoutCardWidthPx() * SCROLL_STEP_FRACTION;
                        final int dx =
                                Math.round((nextProgress - mProgress) * stepPx);
                        if (dx != 0) mRecyclerView.scrollBy(dx, 0);
                    });
            animator.addListener(
                    new android.animation.AnimatorListenerAdapter() {
                        @Override
                        public void onAnimationEnd(android.animation.Animator animation) {
                            if (mSnapAnimator != animator) return;
                            final float stepPx =
                                    getLayoutCardWidthPx() * SCROLL_STEP_FRACTION;
                            final int remainingDx =
                                    Math.round((targetProgress - mProgress) * stepPx);
                            if (remainingDx != 0) {
                                mRecyclerView.scrollBy(remainingDx, 0);
                            }
                            mSnapAnimator = null;
                        }
                    });
            animator.start();
        }

        @Override
        public void scrollToPositionWithOffset(int position, int offset) {
            mPendingScroll = true;
            mPendingPosition = position;
            requestLayout();
        }

        @Override
        public void scrollToPosition(int position) {
            scrollToPositionWithOffset(position, 0);
        }

        @Override
        public boolean canScrollHorizontally() {
            return true;
        }

        @Override
        public View findViewByPosition(int position) {
            for (int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                if (child != null && getPosition(child) == position) return child;
            }
            return null;
        }

        @Override
        public int findFirstVisibleItemPosition() {
            int first = RecyclerView.NO_POSITION;
            final int visibleStart = getPaddingLeft();
            for (int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                if (child == null || child.getRight() <= visibleStart) continue;
                final int position = getPosition(child);
                if (first == RecyclerView.NO_POSITION || position < first) first = position;
            }
            return first;
        }

        @Override
        public int findLastVisibleItemPosition() {
            int last = RecyclerView.NO_POSITION;
            final int visibleEnd = getWidth() - getPaddingRight();
            for (int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                if (child == null || child.getLeft() >= visibleEnd) continue;
                final int position = getPosition(child);
                if (last == RecyclerView.NO_POSITION || position > last) last = position;
            }
            return last;
        }

        @Override
        public int findFirstCompletelyVisibleItemPosition() {
            int first = RecyclerView.NO_POSITION;
            final int visibleStart = getPaddingLeft();
            final int visibleEnd = getWidth() - getPaddingRight();
            for (int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                if (child == null
                        || child.getLeft() < visibleStart
                        || child.getRight() > visibleEnd) {
                    continue;
                }
                final int position = getPosition(child);
                if (first == RecyclerView.NO_POSITION || position < first) first = position;
            }
            return first;
        }

        @Override
        public int findLastCompletelyVisibleItemPosition() {
            int last = RecyclerView.NO_POSITION;
            final int visibleStart = getPaddingLeft();
            final int visibleEnd = getWidth() - getPaddingRight();
            for (int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                if (child == null
                        || child.getLeft() < visibleStart
                        || child.getRight() > visibleEnd) {
                    continue;
                }
                final int position = getPosition(child);
                if (last == RecyclerView.NO_POSITION || position > last) last = position;
            }
            return last;
        }

        @Override
        public int computeHorizontalScrollOffset(RecyclerView.State state) {
            return Math.round(
                    mProgress * getLayoutCardWidthPx() * SCROLL_STEP_FRACTION);
        }

        @Override
        public int computeHorizontalScrollExtent(RecyclerView.State state) {
            return Math.max(0, getWidth() - getPaddingLeft() - getPaddingRight());
        }

        @Override
        public int computeHorizontalScrollRange(RecyclerView.State state) {
            final int itemCount = state.getItemCount();
            if (itemCount == 0) return 0;
            final int cardWidthPx = getLayoutCardWidthPx();
            return Math.round((itemCount - 1) * cardWidthPx * SCROLL_STEP_FRACTION)
                    + computeHorizontalScrollExtent(state);
        }

        @Override
        public RecyclerView.LayoutParams generateDefaultLayoutParams() {
            return new RecyclerView.LayoutParams(
                    RecyclerView.LayoutParams.WRAP_CONTENT,
                    RecyclerView.LayoutParams.MATCH_PARENT);
        }

        @Override
        public boolean supportsPredictiveItemAnimations() {
            return false;
        }

        private void fillVisible(
                RecyclerView.Recycler recycler,
                int itemCount,
                int cardWidthPx,
                int cardHeightPx) {
            final int overscanPx = cardWidthPx;
            final int visibleStart = getPaddingLeft() - overscanPx;
            final int visibleEnd = getWidth() - getPaddingRight() + overscanPx;

            for (int i = getChildCount() - 1; i >= 0; i--) {
                View child = getChildAt(i);
                if (child == null) continue;
                final int position = getPosition(child);
                if (position == RecyclerView.NO_POSITION) continue;
                final int left = getCardLeftPx(position, cardWidthPx, itemCount);
                if (left + cardWidthPx < visibleStart || left > visibleEnd) {
                    sStackCards.remove(child);
                    removeAndRecycleViewAt(i, recycler);
                }
            }

            final int contentHeight = getContentHeight(mRecyclerView);
            final int top =
                    getPaddingTop()
                            + Math.max(
                                    0,
                                    (contentHeight - cardHeightPx) / 2
                                            + Math.round(
                                                    contentHeight
                                                            * VERTICAL_BIAS_FRACTION));

            for (int position = 0; position < itemCount; position++) {
                final int left = getCardLeftPx(position, cardWidthPx, itemCount);
                if (left + cardWidthPx < visibleStart || left > visibleEnd) continue;

                View child = findViewByPosition(position);
                if (child == null) {
                    child = recycler.getViewForPosition(position);
                    int insertionIndex = 0;
                    for (int i = 0; i < getChildCount(); i++) {
                        View attachedChild = getChildAt(i);
                        if (attachedChild != null && getPosition(attachedChild) < position) {
                            insertionIndex++;
                        }
                    }
                    addView(child, insertionIndex);
                }
                child.measure(
                        View.MeasureSpec.makeMeasureSpec(cardWidthPx, View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(
                                cardHeightPx, View.MeasureSpec.EXACTLY));
                layoutDecoratedWithMargins(
                        child, left, top, left + cardWidthPx, top + cardHeightPx);
                sStackCards.put(child, true);
                applyChildTransform(child, position - mProgress);
            }
        }

        private int getCardLeftPx(int position, int cardWidthPx, int itemCount) {
            return AliceTabStackHelper.getCardLeftPx(
                    mProgress, position, getWidth(), cardWidthPx, getCardInsetPx());
        }

        private float clampProgress(float progress, int itemCount) {
            return Math.max(0f, Math.min(Math.max(0, itemCount - 1), progress));
        }

        float getProgress() {
            return mProgress;
        }

        private int getLayoutCardWidthPx() {
            return getCardWidthPx(
                    (Activity) mRecyclerView.getContext(),
                    getLayoutCardHeightPx(),
                    mBrowserControls);
        }

        private int getLayoutCardHeightPx() {
            return getCardHeightPx(mRecyclerView, mBrowserControls);
        }

        private int getCardInsetPx() {
            return mRecyclerView
                    .getResources()
                    .getDimensionPixelSize(R.dimen.tab_grid_card_margin);
        }

        private void runLayoutCompleted() {
            if (mOnLayoutCompleted != null) mOnLayoutCompleted.run();
        }
    }
}
ALICE_EOF

# ---------- 注册新增源文件（chrome_java 目标） ----------
sed -i 's|^  "java/src/org/chromium/chrome/browser/ChromeApplicationImplHooks.java",$|&\n  # Alice patch start 0036\n  "java/src/org/chromium/chrome/browser/tasks/tab_management/AliceTabStackHelper.java",\n  # Alice patch end 0036|' "$path6"

# ---------- 1) TabListCoordinator：GRID 分支记下网格布局管理器并应用当前样式 ----------
# 上游的网格分支照常创建（这样切回「默认」样式时可以直接还原这个 LayoutManager），
# 建完再按设置看要不要换成横向堆叠布局。
sed -i '/^                updateGridCardLayout(frame.width());$/a\
                // Alice patch start 0036\
                // 记住上游的网格布局管理器：切回「默认」样式时用它还原。\
                mAliceGridLayoutManager = gridLayoutManager;\
                if (AliceTabStackHelper.isGridTabSwitcher(componentId)) {\
                    mAliceTabSwitcherGrid = true;\
                    updateAliceTabSwitcherStyleIfNeeded();\
                }\
                // Alice patch end 0036\
' "$path1"

# ---------- 2) TabListCoordinator：记录横向样式相关的状态 ----------
sed -i '/^    private @Nullable OnLayoutChangeListener mListLayoutListener;$/a\
    // Alice patch start 0036\
    /** 上游 GRID 模式创建的网格布局管理器（切回「默认」样式时还原用）。 */\
    private @Nullable GridLayoutManager mAliceGridLayoutManager;\
\
    /** 本协调器是不是标签切换器网格（只有它对「标签切换器」设置生效）。 */\
    private boolean mAliceTabSwitcherGrid;\
\
    /** 已经应用到界面上的样式（-1 = 还没应用过）。 */\
    private int mAliceAppliedStyle = -1;\
    // Alice patch end 0036\
' "$path1"

# ---------- 3) TabListCoordinator：改设置后不用重启浏览器 ----------
sed -i '/^        mMediator.resetWithListOfTabs(tabs, tabGroupSyncIds, quickMode);$/i\
        // Alice patch start 0036\
        // 设置里换过「标签切换器」样式的话，这里就把布局换过来（不用重启浏览器）。\
        updateAliceTabSwitcherStyleIfNeeded();\
        // Alice patch end 0036\
' "$path1"


# ---------- 4) TabListCoordinator：横向样式的卡片尺寸 ----------
sed -i '/^    private void updateGridCardLayout(int viewWidth) {$/i\
    // Alice patch start 0036\
    /**\
     * 按设置里的「标签切换器」样式装上/卸掉横向堆叠布局。可以重复调用（幂等）：\
     * 设置里换成别的样式后，下一次打开标签管理页就会切过来，不用重启浏览器。\
     */\
    private void updateAliceTabSwitcherStyleIfNeeded() {\
        if (!mAliceTabSwitcherGrid) return;\
        final int style = AliceTabStackHelper.getEffectiveStyle();\
        if (style == mAliceAppliedStyle) return;\
        mAliceAppliedStyle = style;\
        if (style == AliceTabStackHelper.STYLE_HORIZONTAL) {\
            mMediator.setAliceStackStyle(true);\
            AliceTabStackHelper.setUp(\
                    mRecyclerView, mBrowserControlsStateProvider, this::checkAwaitingLayout);\
            AliceTabStackHelper.postDeferred(\
                    () -> updateAliceStackCardLayout(mRecyclerView.getWidth()));\
        } else {\
            AliceTabStackHelper.tearDown(mRecyclerView);\
            mMediator.setAliceStackStyle(false);\
            if (mAliceGridLayoutManager != null) {\
                mRecyclerView.setLayoutManager(mAliceGridLayoutManager);\
            }\
            updateGridCardLayout(mRecyclerView.getWidth());\
        }\
    }\
\
    /**\
     * 横向样式的卡片尺寸：高度 = 标签列表可视区高度 × CARD_HEIGHT_FRACTION，宽度按网页内容区\
     * 宽高比计算，确保卡片比例与不含浏览器控制栏的网页一致。\
     * 竖直方向的位置由 AliceTabStackHelper 的 ItemDecoration 居中。\
     */\
    private void updateAliceStackCardLayout(int viewWidth) {\
        if (mRecyclerView.getWidth() <= 0 || mRecyclerView.getHeight() <= 0) return;\
        final int cardHeightPx =\
                AliceTabStackHelper.getCardHeightPx(\
                        mRecyclerView, mBrowserControlsStateProvider);\
        final int cardWidthPx =\
                AliceTabStackHelper.getCardWidthPx(\
                        mActivity, cardHeightPx, mBrowserControlsStateProvider);\
        final Size newDefaultSize = new Size(cardWidthPx, cardHeightPx);\
        if (newDefaultSize.equals(mMediator.getDefaultGridCardSize())) return;\
        mMediator.setDefaultGridCardSize(newDefaultSize);\
        for (int i = 0; i < mModelList.size(); i++) {\
            PropertyModel tabPropertyModel = mModelList.get(i).model;\
            if (TabProperties.isTabOrTabGroup(tabPropertyModel)) {\
                tabPropertyModel.set(\
                        TabProperties.GRID_CARD_SIZE, new Size(cardWidthPx, cardHeightPx));\
            }\
        }\
        for (TabListItemSizeChangedObserver observer : mTabListItemSizeChangedObserverList) {\
            observer.onSizeChanged(mMediator.getCurrentSpanCount(), newDefaultSize);\
        }\
        ViewUtils.requestLayout(mRecyclerView, "AliceTabStackHelper#updateAliceStackCardLayout");\
    }\
    // Alice patch end 0036\
' "$path1"


# ---------- 5) TabListCoordinator：横向样式不去算网格空位布局 ----------
sed -i '/^        final GridLayoutManager layoutManager =$/i\
        // Alice patch start 0036\
        // 横向堆叠样式下卡片大小是固定的（见 updateAliceStackCardLayout），不走网格那套。\
        if (AliceTabStackHelper.isStackLayout(mRecyclerView)) {\
            updateAliceStackCardLayout(viewWidth);\
            return;\
        }\
        // Alice patch end 0036\
' "$path1"

# ---------- 6) TabGridItemTouchHelperCallback：上滑关闭、禁用左右拖拽 ----------
sed -i '/^    public int getMovementFlags(RecyclerView recyclerView, RecyclerView.ViewHolder viewHolder) {$/a\
        // Alice patch start 0036\
        // 横向堆叠样式：卡片不参与拖拽排序，只支持上滑关闭。\
        if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
            return makeMovementFlags(0, isSwipeable(viewHolder) ? ItemTouchHelper.UP : 0);\
        }\
        // Alice patch end 0036\
' "$path2"

sed -i '/^    public float getSwipeThreshold(RecyclerView.ViewHolder viewHolder) {$/a\
        // Alice patch start 0036\
        // 上滑关闭：阈值按卡片高度的五分之一左右。\
        if (AliceTabStackHelper.isStackLayout(mRecyclerViewSupplier.get())) return 0.2f;\
        // Alice patch end 0036\
' "$path2"

# ---------- 7) TabListContainerViewBinder：初始滚动偏移（当前卡片居中） ----------
sed -i '/^        LinearLayoutManager layoutManager = (LinearLayoutManager) view.getLayoutManager();$/i\
        // Alice patch start 0036\
        // 横向样式：当前卡片是牌堆最后一张，初始位置居中。\
        if (AliceTabStackHelper.isStackLayout(view)) {\
            return AliceTabStackHelper.getCardLeftPx(\
                    model.get(BROWSER_CONTROLS_STATE_PROVIDER), view);\
        }\
        // Alice patch end 0036\
' "$path3"

# ---------- 8) TabSwitcherPaneBase：允许非 GridLayoutManager ----------
# 这里原来直接强转 GridLayoutManager，横向样式下会 ClassCastException。
sed -i 's|^import androidx.recyclerview.widget.GridLayoutManager;$|// Alice patch start 0036\nimport androidx.recyclerview.widget.LinearLayoutManager;\n// Alice patch end 0036|' "$path4"
sed -i 's|^                    GridLayoutManager lm =$|                    // Alice patch start 0036\n                    LinearLayoutManager lm =|' "$path4"
sed -i 's|^                            (GridLayoutManager) tabListRecyclerView.getLayoutManager();$|                            (LinearLayoutManager) tabListRecyclerView.getLayoutManager();\n                    // Alice patch end 0036|' "$path4"

# ---------- 8.1) TabGridView：横向牌堆不复用上游选中/悬停缩放动画 ----------
sed -i '/^    void scaleTabGridCardView(@AnimationStatus int status) {$/a\
        // Alice patch start 0036\
        // 横向牌堆统一控制缩放，避免首次布局后上游选中态动画覆盖牌堆缩放。\
        if (AliceTabStackHelper.isInStackLayout(this)\
                || AliceTabStackHelper.getEffectiveStyle()\
                        == AliceTabStackHelper.STYLE_HORIZONTAL) {\
            return;\
        }\
        // Alice patch end 0036\
' "$path12"

# ---------- 9) TabContentManager：仅横向样式捕获时提高倍率 ----------
sed -i '/^    private static final int WAIT_FOR_NATIVE_MAX_BACKOFF_ATTEMPTS = 2;$/a\
    // Alice patch start 0036\
    private static final String PREF_ALICE_TAB_SWITCHER_STYLE = "alice_tab_switcher_style";\
    private static final int ALICE_TAB_SWITCHER_STYLE_HORIZONTAL = 2;\
    // Alice patch end 0036\
' "$path5"

sed -i '/^    private final float mThumbnailScale;$/a\
    // Alice patch start 0036\
    private final float mAliceHorizontalThumbnailScale;\
    // Alice patch end 0036\
' "$path5"

sed -i '/^        mThumbnailScale = thumbnailScale;$/a\
        // Alice patch start 0036\
        // 横向堆叠样式使用更高捕获倍率；默认样式仍沿用 0038 设置的倍率。\
        mAliceHorizontalThumbnailScale =\
                !DeviceFormFactor.isNonMultiDisplayContextOnTablet(mContext)\
                                && deviceDensity > 1.5f\
                        ? Math.max(thumbnailScale, 3.0f / deviceDensity)\
                        : thumbnailScale;\
        // Alice patch end 0036\
' "$path5"

sed -i '/^    \/\*\* Called after native library is loaded\. \*\/$/i\
    // Alice patch start 0036\
    /** @return 当前标签切换器样式对应的缩略图捕获倍率。 */\
    private float getThumbnailScale() {\
        int style =\
                ContextUtils.getAppSharedPreferences()\
                        .getInt(PREF_ALICE_TAB_SWITCHER_STYLE, 0);\
        return style == ALICE_TAB_SWITCHER_STYLE_HORIZONTAL\
                ? mAliceHorizontalThumbnailScale\
                : mThumbnailScale;\
    }\
    // Alice patch end 0036\
' "$path5"

sed -i '/^    @Nullable Bitmap readbackNativeView(/,/^    }$/{
    s/mThumbnailScale/scale/g
    s|^    @Nullable Bitmap readbackNativeView(|    // Alice patch start 0036\n    @Nullable Bitmap readbackNativeView(|
    s|^    }$|    // Alice patch end 0036\n    }|
}' "$path5"

sed -i '/^    private @Nullable Bitmap cacheNativeTabThumbnail(final Tab tab) {$/,/^    }$/{
    s/mThumbnailScale/thumbnailScale/g
    s|^    private @Nullable Bitmap cacheNativeTabThumbnail(final Tab tab) {$|    // Alice patch start 0036\n    private @Nullable Bitmap cacheNativeTabThumbnail(\n            final Tab tab, float thumbnailScale) {|
    s|^    }$|    // Alice patch end 0036\n    }|
}' "$path5"

sed -i '/^    private void captureThumbnail($/,/^    }$/{
    s/mThumbnailScale/thumbnailScale/g
    s|^    private void captureThumbnail($|    // Alice patch start 0036\n    private void captureThumbnail(|
    s|^        long startTime = SystemClock.elapsedRealtime();$|&\n        final float thumbnailScale = getThumbnailScale();|
    s|Bitmap bitmap = cacheNativeTabThumbnail(tab);|Bitmap bitmap = cacheNativeTabThumbnail(tab, thumbnailScale);|
    s|^    }$|    // Alice patch end 0036\n    }|
}' "$path5"

# ---------- 10) 固定标签条：横向样式下主标签列表不是 GridLayoutManager ----------
# 原来这里直接强转，横向样式下会 ClassCastException（打开标签管理页时崩在固定标签条构造里）。
# 退化成没挂到 RecyclerView 上的 GridLayoutManager(span=1)，固定标签条查不到可见项会自动隐藏。
sed -i 's|^        GridLayoutManager tabGridListLayoutManager =$|        // Alice patch start 0036\n        RecyclerView.LayoutManager aliceTabGridListLayoutManager =\n                tabGridListRecyclerView.getLayoutManager();\n        GridLayoutManager tabGridListLayoutManager =\n                aliceTabGridListLayoutManager instanceof GridLayoutManager\n                        ? (GridLayoutManager) aliceTabGridListLayoutManager\n                        : new GridLayoutManager(activity, 1);\n        // Alice patch end 0036|' "$path7"

sed -i '/^                (GridLayoutManager) tabGridListRecyclerView.getLayoutManager();$/d' "$path7"

# ---------- 11) TabListMediator：当前标签置后，并跳过横向样式的网格逻辑 ----------
sed -i '/^    private @Nullable GridLayoutManager mGridLayoutManager;$/a\
    // Alice patch start 0036\
    /** 横向堆叠样式下没有可用的网格布局，跳过所有网格相关逻辑。 */\
    private boolean mAliceStackStyle;\
\
    void setAliceStackStyle(boolean enabled) {\
        mAliceStackStyle = enabled;\
    }\
\
    /** 横向牌堆把当前标签放到最后一张，旧标签在左侧收拢。 */\
    private @Nullable List<Tab> maybeMoveAliceCurrentTabToLast(@Nullable List<Tab> tabs) {\
        if (!mAliceStackStyle || tabs == null || tabs.size() < 2) return tabs;\
        @Nullable Tab currentTab = getCurrentTabModelChecked().getCurrentTabSupplier().get();\
        if (currentTab == null) return tabs;\
        int currentIndex = -1;\
        for (int i = 0; i < tabs.size(); i++) {\
            if (tabs.get(i).getId() == currentTab.getId()) {\
                currentIndex = i;\
                break;\
            }\
        }\
        if (currentIndex < 0 || currentIndex == tabs.size() - 1) return tabs;\
        ArrayList<Tab> reordered = new ArrayList<>(tabs);\
        reordered.add(reordered.remove(currentIndex));\
        return reordered;\
    }\
    // Alice patch end 0036\
' "$path8"

sed -i '/^    public void resetWithListOfTabs($/,/^    }$/ s|^        TabModel tabModel = mCurrentTabModelSupplier.get();$|&\n        // Alice patch start 0036\n        tabs = maybeMoveAliceCurrentTabToLast(tabs);\n        // Alice patch end 0036|' "$path8"

sed -i 's|^                    if (mTabListLayoutDelegate.areTabsInSameGroup(model, tab)) {$|                    // Alice patch start 0036\n                    if (!mAliceStackStyle\n                            \&\& mTabListLayoutDelegate.areTabsInSameGroup(model, tab)) {\n                    // Alice patch end 0036|' "$path8"

sed -i '/^    int getPriceWelcomeMessageInsertionIndex() {$/a\
        // Alice patch start 0036\
        // 横向堆叠样式下没有网格布局，不做消息卡片定位。\
        if (mAliceStackStyle || mGridLayoutManager == null) return TabList.INVALID_TAB_INDEX;\
        // Alice patch end 0036\
' "$path8"

sed -i '/^    void updateLayout() {$/a\
        // Alice patch start 0036\
        // 横向堆叠样式下没有网格布局，跳过网格空位整理。\
        if (mAliceStackStyle || mGridLayoutManager == null) return;\
        // Alice patch end 0036\
' "$path8"

# ---------- 12) TabListCoordinator：尺寸还没算出来时不要用 null 通知/取缩略图尺寸 ----------
sed -i '/^    public void addTabListItemSizeChangedObserver(TabListItemSizeChangedObserver observer) {$/,/^    }$/ s|^        Size size = mMediator.getDefaultGridCardSize();$|&\n        // Alice patch start 0036\n        // 横向样式的卡片尺寸要等第一次布局之后才算得出来，这里先跳过。\n        if (size == null) return;\n        // Alice patch end 0036|' "$path1"

sed -i '/^    Size getThumbnailSize() {$/,/^    }$/ s|^        Size size = mMediator.getDefaultGridCardSize();$|&\n        // Alice patch start 0036\n        if (size == null) {\n            updateAliceStackCardLayout(mRecyclerView.getWidth());\n            size = mMediator.getDefaultGridCardSize();\n            if (size == null) return new Size(1, 1);\n        }\n        // Alice patch end 0036|' "$path1"

# ---------- 13) SingleChildViewManager：布局过程中改子视图一律延后（修 HubContainerView null child 崩溃） ----------
sed -i '/^    private void onViewChanged(@Nullable View view) {$/,/^    }$/{
    s|^    private void onViewChanged(@Nullable View view) {$|&\n        // Alice patch start 0036\n        // 布局过程中直接增删子视图，会让父容器（HubContainerView）的 children 出现 null 而崩溃；\n        // 这里统一延后一帧，并打一条带调用栈的日志便于定位。\n        if (mContainerView.isInLayout()) {\n            final @Nullable View pendingView = view;\n            android.util.Log.w("AliceHub", "defer onViewChanged in layout: " + view, new Throwable());\n            mContainerView.post(() -> onViewChanged(pendingView));\n            return;\n        }\n        // Alice patch end 0036|
}' "$path9"

# ---------- 14) HubManagerImpl：合成器布局流程中删 HubContainerView 子视图会崩，延后一帧 ----------
sed -i 's|^    public void onHubLayoutDoneHiding() {$|&\n        // Alice patch start 0036\n        // 本方法在合成器布局流程（即 View 布局过程中）被调用，直接 removeAllViews() 会让\n        // HubContainerView 的 children 出现 null 而崩溃（点卡片关闭 Hub 时必现）；延后一帧。\n        if (mHubContainerView.isInLayout()) {\n            android.util.Log.w("AliceHub", "defer onHubLayoutDoneHiding", new Throwable());\n            mHubContainerView.post(this::onHubLayoutDoneHiding);\n            return;\n        }\n        // Alice patch end 0036|' "$path10"

# ---------- 15) ShrinkExpandHubLayoutAnimatorProvider：动画清理也延后 ----------
sed -i '/^    private void resetState() {$/,/^    }$/{
    s|^        mHubContainerView.removeView(mShrinkExpandImageView);$|        // Alice patch start 0036\n        // 布局过程中不要直接移除 HubContainerView 的子视图（会崩）；把删除延后一帧，状态照常清理。\n        if (mHubContainerView.isInLayout()) {\n            final View aliceShrinkView = assumeNonNull(mShrinkExpandImageView);\n            final @Nullable View aliceFakeView = mFakeBottomControlsView;\n            android.util.Log.w("AliceHub", "defer resetState removals", new Throwable());\n            mHubContainerView.post(\n                    () -> {\n                        mHubContainerView.removeView(aliceShrinkView);\n                        if (aliceFakeView != null) {\n                            mHubContainerView.removeView(aliceFakeView);\n                        }\n                    });\n            mShrinkExpandImageView.setImageBitmap(null);\n            mShrinkExpandImageView = null;\n            mFakeBottomControlsView = null;\n            return;\n        }\n        // Alice patch end 0036\n        mHubContainerView.removeView(mShrinkExpandImageView);|
}' "$path11"
