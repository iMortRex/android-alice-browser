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
#   - 上滑关闭时左侧卡片会向右挤压；点击时中心卡和邻卡严格跟随 Hub 预览图动画进度。
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
path13="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneCoordinator.java"
path14="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListRecyclerView.java"
path15="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimationData.java"
path16="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubAnimationConstants.java"
path17="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandImageView.java"
path18="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridViewBinder.java"
path19="third_party/androidx/local_modifications/recyclerview/java/org/chromium/ui/recyclerview/widget/ItemTouchHelper2.java"

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
import android.view.ViewTreeObserver;
import android.view.animation.DecelerateInterpolator;

import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
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

    /** 横向堆叠，但不重排标签。 */
    public static final int STYLE_HORIZONTAL_NO_REORDER = 3;

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

    /** 上滑关闭时左侧卡片的挤压幅度。 */
    private static final float SWIPE_PUSH_FRACTION = 0.8f;

    /** 快速斜上滑关闭所需的最小纵向距离（dp）。 */
    private static final float FAST_SWIPE_MIN_DISTANCE_DP = 24f;

    /** 快速斜上滑关闭所需的最小平均速度（px/ms）。 */
    private static final float FAST_SWIPE_MIN_VELOCITY_PX_PER_MS = 1.6f;

    /** 上滑关闭后左侧卡片补位动画时长。 */
    private static final long SWIPE_REPLACE_DURATION_MS = 230;

    /** 点击卡片时左右邻卡的放大增量。 */
    private static final float TAP_NEIGHBOR_SCALE_GAIN = 0.2f;

    /** 点击后两侧卡片完全移出屏幕的时长。 */
    private static final long TAP_CARD_EXIT_DURATION_MS = 230L;

    /** 横向 Hub 预览图缩放动画时长。 */
    private static final long HUB_PREVIEW_DURATION_MS = 260L;

    /** 主线程 Handler：把可能触发布局的动作挪出当前布局流程。 */
    private static final Handler sMainHandler = new Handler(Looper.getMainLooper());

    /** 已经装到某个标签列表上的横向样式状态，卸载时要还回去。 */
    private static final WeakHashMap<RecyclerView, Integer> sPreviousOverScrollModes =
            new WeakHashMap<>();
    private static final WeakHashMap<RecyclerView, RecyclerView.OnScrollListener> sSnapListeners =
            new WeakHashMap<>();
    private static final WeakHashMap<RecyclerView, RecyclerView.OnItemTouchListener>
            sInteractionListeners = new WeakHashMap<>();
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
        int style = getStyle();
        return style == STYLE_HORIZONTAL || style == STYLE_HORIZONTAL_NO_REORDER
                ? STYLE_HORIZONTAL
                : STYLE_DEFAULT;
    }

    /** @return 当前样式是否允许把激活标签移动到模型末尾。 */
    public static boolean shouldReorderTabs() {
        return getStyle() != STYLE_HORIZONTAL_NO_REORDER;
    }

    /** @return Hub 预览动画时长；默认样式保持上游时长。 */
    public static long getHubAnimationDurationMs() {
        return getEffectiveStyle() == STYLE_HORIZONTAL
                ? HUB_PREVIEW_DURATION_MS
                : 325L;
    }

    /** @return 这个容器是不是标签切换器网格（只有它受「标签切换器」设置影响）。 */
    public static boolean isGridTabSwitcher(int componentId) {
        return componentId == TabComponentId.GRID_TAB_SWITCHER;
    }

    /** @return 这个 RecyclerView 当前是不是横向堆叠布局。 */
    public static boolean isStackLayout(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return false;
        return recyclerView.getLayoutManager() instanceof AliceStackLayoutManager;
    }

    /** @return 该 View 是否属于横向牌堆，包括尚未直接挂到 RecyclerView 的阶段。 */
    public static boolean isInStackLayout(@Nullable View view) {
        if (view == null) return false;
        if (getEffectiveStyle() != STYLE_HORIZONTAL) return false;
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
                (int) Math.ceil(contentHeightPx * getPageAspectRatio(activity, browserControls));
        return Math.max(1, contentWidthPx + horizontalInsetsPx);
    }

    /** @return 网页内容区的宽高比（不含顶部工具栏和底部控制栏）。 */
    public static float getPageAspectRatio(
            Activity activity, BrowserControlsStateProvider browserControls) {
        final View decorView = activity.getWindow().getDecorView();
        final int windowWidth =
                decorView.getWidth() > 0
                        ? decorView.getWidth()
                        : activity.getResources().getDisplayMetrics().widthPixels;
        final int fullWindowHeight =
                decorView.getHeight() > 0
                        ? decorView.getHeight()
                        : activity.getResources().getDisplayMetrics().heightPixels;
        final int pageHeight = fullWindowHeight - getWindowChromeHeightPx(activity);
        if (windowWidth <= 0 || pageHeight <= 0) return 0.5f;
        return (float) windowWidth / pageHeight;
    }

    /** @return 状态栏、工具栏、hairline 和系统导航栏占用的总高度。 */
    private static int getWindowChromeHeightPx(Activity activity) {
        final View rootView = activity.getWindow().getDecorView();
        android.content.res.Resources resources = activity.getResources();
        int toolbarHeight =
                resources.getDimensionPixelSize(
                        org.chromium.chrome.R.dimen.toolbar_height_no_shadow);
        int hairlineHeight =
                resources.getDimensionPixelSize(
                        org.chromium.chrome.R.dimen.toolbar_hairline_height);
        int navigationBarHeight = 0;
        @Nullable View navigationBar =
                rootView.findViewById(org.chromium.chrome.R.id.edge_to_edge_bottom_chin);
        if (navigationBar != null) {
            navigationBarHeight = navigationBar.getHeight();
        }
        int statusBarHeight = 0;
        WindowInsetsCompat insets = ViewCompat.getRootWindowInsets(rootView);
        if (insets != null) {
            statusBarHeight =
                    insets.getInsets(
                                    WindowInsetsCompat.Type.statusBars()
                                            | WindowInsetsCompat.Type.displayCutout())
                            .top;
            navigationBarHeight =
                    Math.max(
                            navigationBarHeight,
                            insets.getInsets(
                                            WindowInsetsCompat.Type.navigationBars()
                                                    | WindowInsetsCompat.Type
                                                            .mandatorySystemGestures()
                                                    | WindowInsetsCompat.Type.tappableElement())
                                    .bottom);
        }
        return statusBarHeight + toolbarHeight + hairlineHeight + navigationBarHeight;
    }

    /** @return 顶部和底部浏览器控制栏的总高度；缩略图比例不随 Hub 中的隐藏 offset 变化。 */
    private static int getVisibleBrowserControlsHeight(
            BrowserControlsStateProvider browserControls) {
        final int topControlsHeight =
                Math.max(0, browserControls.getTopControlsHeight());
        final int bottomControlsHeight =
                Math.max(0, browserControls.getBottomControlsHeight());
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
        return getCardLeftPx(
                position - progress, viewportWidth, cardWidthPx, cardInsetPx);
    }

    private static int getCardLeftPx(
            float distance, int viewportWidth, int cardWidthPx, int cardInsetPx) {
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
        RecyclerView.OnItemTouchListener interactionListener =
                new RecyclerView.OnItemTouchListener() {
                    @Override
                    public boolean onInterceptTouchEvent(
                            RecyclerView recyclerView, android.view.MotionEvent event) {
                        int action = event.getActionMasked();
                        if (action == android.view.MotionEvent.ACTION_DOWN) {
                            layoutManager.onUserInteractionStarted();
                        } else if (action == android.view.MotionEvent.ACTION_UP
                                || action == android.view.MotionEvent.ACTION_CANCEL) {
                            layoutManager.onUserInteractionEnded();
                        }
                        return false;
                    }

                    @Override
                    public void onTouchEvent(
                            RecyclerView recyclerView, android.view.MotionEvent event) {
                        int action = event.getActionMasked();
                        if (action == android.view.MotionEvent.ACTION_UP
                                || action == android.view.MotionEvent.ACTION_CANCEL) {
                            layoutManager.onUserInteractionEnded();
                        }
                    }

                    @Override
                    public void onRequestDisallowInterceptTouchEvent(boolean disallowIntercept) {}
                };
        sInteractionListeners.put(recyclerView, interactionListener);
        recyclerView.addOnItemTouchListener(interactionListener);
        recyclerView.requestLayout();
    }

    /** 更新上滑关闭时左侧卡片的挤压滚动。 */
    public static void updateSwipePush(
            @Nullable RecyclerView recyclerView,
            int anchorPosition,
            float pushProgress,
            boolean active) {
        if (recyclerView == null) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager instanceof AliceStackLayoutManager stackLayoutManager) {
            stackLayoutManager.setSwipePush(anchorPosition, pushProgress, active);
        }
    }

    /** 在 RecyclerView 处理触摸前记录斜上滑意图。 */
    public static void onStackPreTouch(
            @Nullable RecyclerView recyclerView, android.view.MotionEvent event) {
        if (recyclerView == null) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager instanceof AliceStackLayoutManager stackLayoutManager) {
            stackLayoutManager.onPreTouchEvent(event);
        }
    }

    /** @return 当前手势是否应按斜上滑处理。 */
    public static boolean isDiagonalUpSwipeCandidate(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        return layoutManager instanceof AliceStackLayoutManager stackLayoutManager
                && stackLayoutManager.isDiagonalUpSwipeCandidate();
    }

    /** 只放行一次横向方向位，让 ItemTouchHelper 进入 swipe；随后仍按仅上滑处理。 */
    public static boolean consumeDiagonalUpSwipeDirectionBypass(
            @Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        return layoutManager instanceof AliceStackLayoutManager stackLayoutManager
                && stackLayoutManager.consumeDiagonalUpSwipeDirectionBypass();
    }

    /** @return 当前手势是否达到快速斜上滑关闭条件。 */
    public static boolean shouldCommitFastUpSwipe(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        return layoutManager instanceof AliceStackLayoutManager stackLayoutManager
                && stackLayoutManager.shouldCommitFastUpSwipe();
    }

    /** @return 快速上滑兜底使用的最小距离（px）。 */
    public static float getFastSwipeMinDistancePx(RecyclerView recyclerView) {
        return FAST_SWIPE_MIN_DISTANCE_DP
                * recyclerView.getResources().getDisplayMetrics().density;
    }

    /** 上滑关闭时先完成左侧补位动画，再真正从列表移除卡片。 */
    public static boolean animateSwipeReplacementAndThen(
            @Nullable RecyclerView recyclerView,
            int anchorPosition,
            @Nullable Runnable onComplete) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager instanceof AliceStackLayoutManager stackLayoutManager) {
            stackLayoutManager.animateSwipeReplacementAndThen(anchorPosition, onComplete);
            return true;
        }
        return false;
    }

    /** 上滑未达到关闭阈值或手势结束时清理挤压状态。 */
    public static void onSwipeCleared(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager instanceof AliceStackLayoutManager stackLayoutManager) {
            stackLayoutManager.clearSwipePushUnlessCommitted();
        }
    }

    /** 点击卡片时立即启动中心卡缩放和左右邻卡避让。 */
    public static boolean animateNeighborAvoidance(
            @Nullable RecyclerView recyclerView, int focusedPosition) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (!(layoutManager instanceof AliceStackLayoutManager stackLayoutManager)) {
            return false;
        }
        stackLayoutManager.animateNeighborAvoidance(focusedPosition);
        return true;
    }

    /** 重新进入 Hub 时强制把当前标签所在的最后一张卡重置到中心。 */
    public static boolean resetToLastCard(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (!(layoutManager instanceof AliceStackLayoutManager stackLayoutManager)) {
            return false;
        }
        stackLayoutManager.resetToLastCard();
        return true;
    }

    /** 把指定的标签卡滚动到中心。 */
    public static boolean resetToCard(@Nullable RecyclerView recyclerView, int position) {
        if (recyclerView == null) return false;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (!(layoutManager instanceof AliceStackLayoutManager stackLayoutManager)) {
            return false;
        }
        stackLayoutManager.resetToCard(position);
        return true;
    }

    /** 卸载横向堆叠样式（切回「默认」样式之前调用）。 */
    public static void tearDown(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager instanceof AliceStackLayoutManager stackLayoutManager) {
            stackLayoutManager.shutdown();
        }
        recyclerView.stopScroll();
        Integer previousOverScrollMode = sPreviousOverScrollModes.remove(recyclerView);
        if (previousOverScrollMode != null) {
            recyclerView.setOverScrollMode(previousOverScrollMode);
        }
        RecyclerView.OnScrollListener snapListener = sSnapListeners.remove(recyclerView);
        if (snapListener != null) {
            recyclerView.removeOnScrollListener(snapListener);
        }
        RecyclerView.OnItemTouchListener interactionListener =
                sInteractionListeners.remove(recyclerView);
        if (interactionListener != null) {
            recyclerView.removeOnItemTouchListener(interactionListener);
        }
        for (int i = 0; i < recyclerView.getChildCount(); i++) {
            View child = recyclerView.getChildAt(i);
            if (child == null) continue;
            sStackCards.remove(child);
            resetCardTransform(child);
        }
    }

    /** 清理横向动画留下的 View 变换，避免回收后污染默认样式。 */
    public static void resetCardTransform(@Nullable View child) {
        if (child == null) return;
        sStackCards.remove(child);
        child.animate().cancel();
        resetChildTransform(child);
        child.setPivotX(child.getWidth() / 2f);
        child.setPivotY(child.getHeight() / 2f);
    }

    /** 按相对中心卡的距离更新缩放。 */
    public static void applyStackScales(RecyclerView recyclerView) {
        if (!isStackLayout(recyclerView)) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (!(layoutManager instanceof AliceStackLayoutManager stackLayoutManager)) return;
        for (int i = 0; i < recyclerView.getChildCount(); i++) {
            View child = recyclerView.getChildAt(i);
            if (child == null) continue;
            if (stackLayoutManager.isTapAnimating(child)) continue;
            final int position = recyclerView.getChildAdapterPosition(child);
            if (position == RecyclerView.NO_POSITION) continue;
            applyChildTransform(
                    child,
                    stackLayoutManager.getEffectiveDistance(position));
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
        child.setTranslationX(0f);
        child.setTranslationY(0f);
        child.setTranslationZ(0f);
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
        private boolean mUserInteractionActive;
        private final int mTouchSlop;
        private float mTouchDownX;
        private float mTouchDownY;
        private long mTouchDownTime;
        private long mLastMoveTime;
        private float mLastMoveY;
        private boolean mDiagonalSwipeCandidate;
        private boolean mDiagonalDirectionBypassPending;
        private @Nullable ValueAnimator mSnapAnimator;
        private int mSwipePushAnchor = RecyclerView.NO_POSITION;
        private float mSwipePushProgress;
        private boolean mSwipePushActive;
        private boolean mSwipeCommitted;
        private @Nullable ValueAnimator mSwipeReplaceAnimator;
        private int mDismissingPosition = RecyclerView.NO_POSITION;
        private float mSwipeReplacementStartProgress;
        private int mTapFocusPosition = RecyclerView.NO_POSITION;
        private @Nullable ValueAnimator mTapAnimator;
        private int mEnterFocusPosition = RecyclerView.NO_POSITION;
        private @Nullable ValueAnimator mEnterAnimator;
        private final ViewTreeObserver.OnPreDrawListener mStartEnterAnimationOnPreDraw =
                this::startEnterAnimationOnPreDraw;
        private boolean mEnterAnimationPreDrawRegistered;
        private final WeakHashMap<View, Boolean> mTapAnimatingViews = new WeakHashMap<>();
        private RecyclerView.@Nullable ItemAnimator mSavedItemAnimator;
        private final Runnable mSnapRunnable = this::performSnap;
        private final Runnable mTapResetRunnable = this::resetTapAnimationIfNotEntering;
        private final Runnable mSwipeClearRunnable =
                () -> {
                    if (mSwipeCommitted) return;
                    setSwipePush(RecyclerView.NO_POSITION, 0f, false);
                    snapToNearestCard();
                };

        AliceStackLayoutManager(
                RecyclerView recyclerView,
                BrowserControlsStateProvider browserControls,
                @Nullable Runnable onLayoutCompleted) {
            super(recyclerView.getContext(), LinearLayoutManager.HORIZONTAL, false);
            mRecyclerView = recyclerView;
            mBrowserControls = browserControls;
            mOnLayoutCompleted = onLayoutCompleted;
            mTouchSlop =
                    android.view.ViewConfiguration.get(recyclerView.getContext())
                            .getScaledTouchSlop();
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

        void animateSwipeReplacementAndThen(
                int anchorPosition, @Nullable Runnable onComplete) {
            final int itemCount =
                    mRecyclerView.getAdapter() == null
                            ? 0
                            : mRecyclerView.getAdapter().getItemCount();
            if (itemCount == 0) {
                if (onComplete != null) onComplete.run();
                return;
            }

            mRecyclerView.removeCallbacks(mSwipeClearRunnable);
            final int targetProgress =
                    Math.max(0, Math.min(itemCount - 1, anchorPosition - 1));
            final float startProgress = mProgress;
            final float startPushProgress = mSwipePushProgress;
            mSwipeCommitted = true;
            mDismissingPosition = anchorPosition;
            mSwipeReplacementStartProgress = startProgress;
            ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);
            mSwipeReplaceAnimator = animator;
            animator.setDuration(SWIPE_REPLACE_DURATION_MS);
            animator.setInterpolator(
                    org.chromium.chrome.browser.hub.HubAnimationConstants
                            .ALICE_STACK_INTERPOLATOR);
            animator.addUpdateListener(
                    animation -> {
                        final float fraction = (float) animation.getAnimatedValue();
                        mProgress =
                                startProgress
                                        + (targetProgress - startProgress) * fraction;
                        mSwipePushProgress =
                                startPushProgress * (1f - fraction);
                        mSwipePushActive = mSwipePushProgress > 0.001f;
                        mRecyclerView.requestLayout();
                    });
            animator.addListener(
                    new android.animation.AnimatorListenerAdapter() {
                        @Override
                        public void onAnimationEnd(android.animation.Animator animation) {
                            if (mSwipeReplaceAnimator != animator) return;
                            mProgress = targetProgress;
                            mSwipePushProgress = 0f;
                            mSwipePushActive = false;
                            mSwipePushAnchor = RecyclerView.NO_POSITION;
                            mSwipeCommitted = false;
                            mSwipeReplaceAnimator = null;
                            if (onComplete != null) {
                                runWithoutItemAnimations(onComplete);
                            }
                            mDismissingPosition = RecyclerView.NO_POSITION;
                            mSwipeReplacementStartProgress = 0f;
                            mRecyclerView.requestLayout();
                        }
                    });
            animator.start();
        }

        private void runWithoutItemAnimations(Runnable action) {
            final RecyclerView.ItemAnimator itemAnimator = mRecyclerView.getItemAnimator();
            if (itemAnimator == null) {
                action.run();
                return;
            }
            final long addDuration = itemAnimator.getAddDuration();
            final long removeDuration = itemAnimator.getRemoveDuration();
            final long moveDuration = itemAnimator.getMoveDuration();
            final long changeDuration = itemAnimator.getChangeDuration();
            itemAnimator.setAddDuration(0);
            itemAnimator.setRemoveDuration(0);
            itemAnimator.setMoveDuration(0);
            itemAnimator.setChangeDuration(0);
            action.run();
            itemAnimator.endAnimations();
            mRecyclerView.post(
                    () -> {
                        itemAnimator.setAddDuration(addDuration);
                        itemAnimator.setRemoveDuration(removeDuration);
                        itemAnimator.setMoveDuration(moveDuration);
                        itemAnimator.setChangeDuration(changeDuration);
                    });
        }

        void onDragStarted() {
            mRecyclerView.removeCallbacks(mSnapRunnable);
            mRecyclerView.removeCallbacks(mSwipeClearRunnable);
            ValueAnimator animator = mSnapAnimator;
            mSnapAnimator = null;
            if (animator != null) animator.cancel();
            ValueAnimator swipeReplaceAnimator = mSwipeReplaceAnimator;
            mSwipeReplaceAnimator = null;
            if (swipeReplaceAnimator != null) swipeReplaceAnimator.cancel();
            mSwipeCommitted = false;
            mDismissingPosition = RecyclerView.NO_POSITION;
            mSwipeReplacementStartProgress = 0f;
            cancelHubTapAnimation();
        }

        void shutdown() {
            mRecyclerView.removeCallbacks(mSnapRunnable);
            mRecyclerView.removeCallbacks(mTapResetRunnable);
            mRecyclerView.removeCallbacks(mSwipeClearRunnable);
            removeEnterAnimationPreDrawListener();

            ValueAnimator snapAnimator = mSnapAnimator;
            mSnapAnimator = null;
            if (snapAnimator != null) snapAnimator.cancel();

            ValueAnimator tapAnimator = mTapAnimator;
            mTapAnimator = null;
            if (tapAnimator != null) tapAnimator.cancel();

            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubEnterAnimationStarter(() -> {});
            ValueAnimator enterAnimator = mEnterAnimator;
            mEnterAnimator = null;
            if (enterAnimator != null) enterAnimator.cancel();

            ValueAnimator swipeReplaceAnimator = mSwipeReplaceAnimator;
            mSwipeReplaceAnimator = null;
            if (swipeReplaceAnimator != null) swipeReplaceAnimator.cancel();

            mTapAnimatingViews.clear();
            mTapFocusPosition = RecyclerView.NO_POSITION;
            mEnterFocusPosition = RecyclerView.NO_POSITION;
            mSwipePushAnchor = RecyclerView.NO_POSITION;
            mSwipePushProgress = 0f;
            mSwipePushActive = false;
            mSwipeCommitted = false;
            mDismissingPosition = RecyclerView.NO_POSITION;
            mSwipeReplacementStartProgress = 0f;
            mUserInteractionActive = false;

            if (mSavedItemAnimator != null) {
                mRecyclerView.setItemAnimator(mSavedItemAnimator);
                mSavedItemAnimator = null;
            }
            mRecyclerView.suppressLayout(false);
        }

        void onUserInteractionStarted() {
            mUserInteractionActive = true;
            mRecyclerView.removeCallbacks(mSnapRunnable);
            ValueAnimator animator = mSnapAnimator;
            mSnapAnimator = null;
            if (animator != null) animator.cancel();
            if (mRecyclerView.getScrollState() != RecyclerView.SCROLL_STATE_IDLE) {
                mRecyclerView.stopScroll();
            }
        }

        void onPreTouchEvent(android.view.MotionEvent event) {
            final int action = event.getActionMasked();
            if (action == android.view.MotionEvent.ACTION_DOWN) {
                mTouchDownX = event.getX();
                mTouchDownY = event.getY();
                mTouchDownTime = event.getEventTime();
                mLastMoveTime = mTouchDownTime;
                mLastMoveY = mTouchDownY;
                mDiagonalSwipeCandidate = false;
                mDiagonalDirectionBypassPending = false;
                return;
            }
            if (action == android.view.MotionEvent.ACTION_UP
                    || action == android.view.MotionEvent.ACTION_CANCEL) {
                mLastMoveTime = event.getEventTime();
                mLastMoveY = event.getY();
                return;
            }
            if (action != android.view.MotionEvent.ACTION_MOVE) return;
            mLastMoveTime = event.getEventTime();
            mLastMoveY = event.getY();
            final float dx = Math.abs(event.getX() - mTouchDownX);
            final float dy = event.getY() - mTouchDownY;
            if (!mDiagonalSwipeCandidate
                    && dy < 0f
                    && -dy > mTouchSlop
                    && -dy >= dx * 0.5f) {
                mDiagonalSwipeCandidate = true;
                mDiagonalDirectionBypassPending = true;
            }
        }

        boolean isDiagonalUpSwipeCandidate() {
            return mDiagonalSwipeCandidate;
        }

        boolean consumeDiagonalUpSwipeDirectionBypass() {
            if (!mDiagonalDirectionBypassPending) return false;
            mDiagonalDirectionBypassPending = false;
            return true;
        }

        boolean shouldCommitFastUpSwipe() {
            final long durationMs =
                    Math.max(1L, mLastMoveTime - mTouchDownTime);
            final float distancePx =
                    Math.max(0f, mTouchDownY - mLastMoveY);
            final float velocityPxPerMs = distancePx / durationMs;
            return mDiagonalSwipeCandidate
                    && distancePx >= getFastSwipeMinDistancePx(mRecyclerView)
                    && velocityPxPerMs >= FAST_SWIPE_MIN_VELOCITY_PX_PER_MS;
        }

        void onUserInteractionEnded() {
            mUserInteractionActive = false;
            if (!mSwipePushActive && !mSwipeCommitted) {
                snapToNearestCard();
            }
        }

        void cancelEnterAnimation() {
            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubEnterAnimationStarter(() -> {});
            removeEnterAnimationPreDrawListener();
            ValueAnimator animator = mEnterAnimator;
            mEnterAnimator = null;
            boolean hadEnterAnimation =
                    animator != null || mEnterFocusPosition != RecyclerView.NO_POSITION;
            if (animator != null) animator.cancel();
            mEnterFocusPosition = RecyclerView.NO_POSITION;
            if (hadEnterAnimation) {
                mTapAnimatingViews.clear();
                mRecyclerView.requestLayout();
            }
        }

        void setSwipePush(int anchorPosition, float pushProgress, boolean active) {
            if (mSwipeCommitted) return;
            if (mSwipePushAnchor == anchorPosition
                    && Math.abs(mSwipePushProgress - pushProgress) < 0.001f
                    && mSwipePushActive == active) {
                return;
            }
            mSwipePushAnchor = anchorPosition;
            mSwipePushProgress = Math.max(0f, Math.min(1f, pushProgress));
            mSwipePushActive = active;
            mRecyclerView.requestLayout();
        }

        void clearSwipePushUnlessCommitted() {
            mRecyclerView.removeCallbacks(mSwipeClearRunnable);
            if (!mSwipeCommitted) {
                setSwipePush(RecyclerView.NO_POSITION, 0f, false);
            }
        }

        void animateNeighborAvoidance(int focusedPosition) {
            onUserInteractionStarted();
            final int itemCount =
                    mRecyclerView.getAdapter() == null
                            ? 0
                            : mRecyclerView.getAdapter().getItemCount();
            if (itemCount == 0) {
                mRecyclerView.suppressLayout(false);
                if (mSavedItemAnimator != null) {
                    mRecyclerView.setItemAnimator(mSavedItemAnimator);
                    mSavedItemAnimator = null;
                }
                return;
            }
            if (mTapFocusPosition != RecyclerView.NO_POSITION) {
                cancelHubTapAnimation();
            }
            cancelEnterAnimation();
            mRecyclerView.suppressLayout(true);
            RecyclerView.ItemAnimator itemAnimator = mRecyclerView.getItemAnimator();
            if (itemAnimator != null) {
                itemAnimator.endAnimations();
                mSavedItemAnimator = itemAnimator;
                mRecyclerView.setItemAnimator(null);
            }
            mTapFocusPosition =
                    Math.max(0, Math.min(itemCount - 1, focusedPosition));
            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubTapAnimationStarter(this::startTapAnimationNow);
        }

        void startTapAnimationNow() {
            if (mTapFocusPosition == RecyclerView.NO_POSITION) {
                return;
            }
            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubTapAnimationStarter(() -> {});
            ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);
            mTapAnimator = animator;
            animator.setDuration(TAP_CARD_EXIT_DURATION_MS);
            animator.setInterpolator(
                    org.chromium.chrome.browser.hub.HubAnimationConstants
                            .ALICE_STACK_INTERPOLATOR);
            animator.addUpdateListener(
                    animation -> {
                        final float progress = (float) animation.getAnimatedValue();
                        for (int i = 0; i < mRecyclerView.getChildCount(); i++) {
                            View child = mRecyclerView.getChildAt(i);
                            if (child == null) continue;
                            int position = mRecyclerView.getChildAdapterPosition(child);
                            if (position == RecyclerView.NO_POSITION) continue;
                            if (position == mTapFocusPosition) continue;
                            int distance = Math.abs(position - mTapFocusPosition);
                            float scaleGain =
                                    TAP_NEIGHBOR_SCALE_GAIN / Math.max(1, distance);
                            float translationX =
                                    getCardExitTranslationX(
                                            child, position, scaleGain, mTapFocusPosition);

                            float baseScale =
                                    getScaleForDistance(getEffectiveDistance(position));
                            float targetScale = baseScale + scaleGain;
                            float cardProgress =
                                    getTapNeighborProgress(progress, distance);
                            child.setPivotX(child.getWidth() / 2f);
                            child.setPivotY(child.getHeight() / 2f);
                            child.setScaleX(
                                    baseScale + (targetScale - baseScale) * cardProgress);
                            child.setScaleY(
                                    baseScale + (targetScale - baseScale) * cardProgress);
                            child.setTranslationX(translationX * cardProgress);
                            mTapAnimatingViews.put(child, true);
                        }
                        mRecyclerView.invalidate();
                    });
            animator.addListener(
                    new android.animation.AnimatorListenerAdapter() {
                        @Override
                        public void onAnimationEnd(android.animation.Animator animation) {
                            if (mTapAnimator == animator) mTapAnimator = null;
                        }
                    });
            animator.start();
            mRecyclerView.removeCallbacks(mTapResetRunnable);
            mRecyclerView.postDelayed(
                    mTapResetRunnable,
                    TAP_CARD_EXIT_DURATION_MS + 250);
        }

        void startEnterAnimationNow() {
            if (mEnterFocusPosition == RecyclerView.NO_POSITION) return;
            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubEnterAnimationStarter(() -> {});
            ValueAnimator previousAnimator = mEnterAnimator;
            mEnterAnimator = null;
            if (previousAnimator != null) previousAnimator.cancel();
            mTapAnimatingViews.clear();
            removeEnterAnimationPreDrawListener();
            ViewTreeObserver observer = mRecyclerView.getViewTreeObserver();
            if (observer.isAlive()) {
                observer.addOnPreDrawListener(mStartEnterAnimationOnPreDraw);
                mEnterAnimationPreDrawRegistered = true;
                mRecyclerView.invalidate();
            }
        }

        boolean startEnterAnimationOnPreDraw() {
            if (mEnterFocusPosition == RecyclerView.NO_POSITION
                    || !mRecyclerView.isAttachedToWindow()
                    || !mRecyclerView.isShown()
                    || !mRecyclerView.isLaidOut()
                    || mRecyclerView.getChildCount() == 0) {
                return true;
            }
            removeEnterAnimationPreDrawListener();
            startEnterAnimationAfterFrame();
            return true;
        }

        void removeEnterAnimationPreDrawListener() {
            if (!mEnterAnimationPreDrawRegistered) return;
            ViewTreeObserver observer = mRecyclerView.getViewTreeObserver();
            if (observer.isAlive()) {
                observer.removeOnPreDrawListener(mStartEnterAnimationOnPreDraw);
            }
            mEnterAnimationPreDrawRegistered = false;
        }

        void startEnterAnimationAfterFrame() {
            if (mEnterFocusPosition == RecyclerView.NO_POSITION) return;

            ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);
            mEnterAnimator = animator;
            animator.setDuration(HUB_PREVIEW_DURATION_MS);
            animator.setInterpolator(
                    org.chromium.chrome.browser.hub.HubAnimationConstants
                            .ALICE_STACK_INTERPOLATOR);
            animator.addUpdateListener(
                    animation ->
                            applyEnterAnimationFrame(
                                    (float) animation.getAnimatedValue()));
            animator.addListener(
                    new android.animation.AnimatorListenerAdapter() {
                        @Override
                        public void onAnimationEnd(android.animation.Animator animation) {
                            if (mEnterAnimator != animator) return;
                            mEnterAnimator = null;
                            mEnterFocusPosition = RecyclerView.NO_POSITION;
                            mTapAnimatingViews.clear();
                            mRecyclerView.requestLayout();
                        }
                    });
            applyEnterAnimationFrame(0f);
            animator.start();
        }

        void applyEnterAnimationFrame(float progress) {
            final float clampedProgress = Math.max(0f, Math.min(1f, progress));
            for (int i = 0; i < mRecyclerView.getChildCount(); i++) {
                View child = mRecyclerView.getChildAt(i);
                if (child == null) continue;
                int position = mRecyclerView.getChildAdapterPosition(child);
                if (position == RecyclerView.NO_POSITION
                        || position == mEnterFocusPosition) {
                    continue;
                }
                int distance = Math.abs(position - mEnterFocusPosition);
                float scaleGain = TAP_NEIGHBOR_SCALE_GAIN / Math.max(1, distance);
                float baseScale = getScaleForDistance(getEffectiveDistance(position));
                float targetScale = baseScale + scaleGain;
                float cardProgress =
                        getTapNeighborProgress(clampedProgress, distance);
                float reverseProgress = 1f - cardProgress;
                float exitTranslation =
                        getCardExitTranslationX(
                                child,
                                position,
                                scaleGain,
                                mEnterFocusPosition);
                child.setPivotX(child.getWidth() / 2f);
                child.setPivotY(child.getHeight() / 2f);
                child.setScaleX(
                        baseScale + (targetScale - baseScale) * reverseProgress);
                child.setScaleY(
                        baseScale + (targetScale - baseScale) * reverseProgress);
                child.setTranslationX(exitTranslation * reverseProgress);
                mTapAnimatingViews.put(child, true);
            }
            mRecyclerView.invalidate();
        }

        private static float getTapNeighborProgress(float progress, int distance) {
            final float clampedProgress = Math.max(0f, Math.min(1f, progress));
            final float exponent =
                    Math.min(2.2f, 0.55f + Math.max(0, distance - 1) * 0.22f);
            return (float) Math.pow(clampedProgress, exponent);
        }

        void resetTapAnimationIfNotEntering() {
            if (mEnterFocusPosition != RecyclerView.NO_POSITION
                    || mEnterAnimationPreDrawRegistered) {
                return;
            }
            cancelHubTapAnimation();
        }

        void cancelHubTapAnimation() {
            mRecyclerView.removeCallbacks(mTapResetRunnable);
            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubTapAnimationStarter(() -> {});
            ValueAnimator tapAnimator = mTapAnimator;
            mTapAnimator = null;
            if (tapAnimator != null) tapAnimator.cancel();

            cancelEnterAnimation();
            for (View child : mTapAnimatingViews.keySet()) {
                if (child != null) {
                    child.animate().cancel();
                }
            }
            mTapAnimatingViews.clear();
            mTapFocusPosition = RecyclerView.NO_POSITION;
            if (mSavedItemAnimator != null) {
                mRecyclerView.setItemAnimator(mSavedItemAnimator);
                mSavedItemAnimator = null;
            }
            mRecyclerView.suppressLayout(false);
            mRecyclerView.requestLayout();
        }

        boolean isTapAnimating(View child) {
            return mTapAnimatingViews.containsKey(child);
        }

        float getEffectiveDistance(int position) {
            float distance =
                    mDismissingPosition != RecyclerView.NO_POSITION
                                    && position > mDismissingPosition
                            ? position - mSwipeReplacementStartProgress
                            : position - mProgress;
            if (mSwipePushActive
                    && mSwipePushAnchor != RecyclerView.NO_POSITION
                    && position < mSwipePushAnchor) {
                distance += mSwipePushProgress * SWIPE_PUSH_FRACTION;
            }
            return distance;
        }

        float getCardExitTranslationX(
                View card, int position, float scaleGain, int focusPosition) {
            int cardWidthPx = card.getWidth();
            float targetScale =
                    getScaleForDistance(getEffectiveDistance(position)) + scaleGain;
            final float scaledWidth = cardWidthPx * targetScale;
            final float scaledLeft =
                    card.getLeft() + (cardWidthPx - scaledWidth) / 2f;
            return position < focusPosition
                    ? Math.min(0f, -scaledLeft - scaledWidth)
                    : Math.max(0f, getWidth() - scaledLeft);
        }

        void snapToNearestCard() {
            mRecyclerView.removeCallbacks(mSnapRunnable);
            if (mUserInteractionActive || mSwipeCommitted) return;
            mRecyclerView.post(mSnapRunnable);
        }

        private void performSnap() {
            if (mUserInteractionActive || mSwipeCommitted) return;
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

        void resetToLastCard() {
            final int itemCount =
                    mRecyclerView.getAdapter() == null
                            ? 0
                            : mRecyclerView.getAdapter().getItemCount();
            if (itemCount == 0) return;
            resetToCard(itemCount - 1);
        }

        void resetToCard(int position) {
            final int itemCount =
                    mRecyclerView.getAdapter() == null
                            ? 0
                            : mRecyclerView.getAdapter().getItemCount();
            if (itemCount == 0) return;
            // 上一次卡片的延迟 reset 不能取消新一轮进入动画。
            mRecyclerView.removeCallbacks(mTapResetRunnable);
            if (mTapFocusPosition != RecyclerView.NO_POSITION || mTapAnimator != null) {
                cancelHubTapAnimation();
            }
            mPendingScroll = true;
            mPendingPosition = Math.max(0, Math.min(itemCount - 1, position));
            mEnterFocusPosition = mPendingPosition;
            org.chromium.chrome.browser.hub.HubAnimationConstants
                    .setAliceHubEnterAnimationStarter(this::startEnterAnimationNow);
            mRecyclerView.requestLayout();
        }

        @Override
        public boolean canScrollHorizontally() {
            return !mDiagonalSwipeCandidate;
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
                if (position == mDismissingPosition) {
                    sStackCards.remove(child);
                    removeAndRecycleViewAt(i, recycler);
                    continue;
                }
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
                if (position == mDismissingPosition) continue;
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
                if (!isTapAnimating(child)) {
                    applyChildTransform(child, getEffectiveDistance(position));
                }
            }
        }

        private int getCardLeftPx(int position, int cardWidthPx, int itemCount) {
            return AliceTabStackHelper.getCardLeftPx(
                    getEffectiveDistance(position),
                    getWidth(),
                    cardWidthPx,
                    getCardInsetPx());
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
    /** 已经应用到界面上的样式；初始值按默认样式处理，避免改动上游首屏。 */\
    private int mAliceAppliedStyle = AliceTabStackHelper.STYLE_DEFAULT;\
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
        final int selectedStyle = AliceTabStackHelper.getStyle();\
        final int style = AliceTabStackHelper.getEffectiveStyle();\
        final boolean horizontal = style == AliceTabStackHelper.STYLE_HORIZONTAL;\
        final boolean appliedHorizontal =\
                mAliceAppliedStyle == AliceTabStackHelper.STYLE_HORIZONTAL\
                        || mAliceAppliedStyle\
                                == AliceTabStackHelper.STYLE_HORIZONTAL_NO_REORDER;\
        if (horizontal == appliedHorizontal) {\
            mAliceAppliedStyle = selectedStyle;\
            return;\
        }\
        if (horizontal) {\
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
            mRecyclerView.requestLayout();\
        }\
        mAliceAppliedStyle = selectedStyle;\
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


# Alice patch start 0036
sed -i '/^    private void updateAliceTabSwitcherStyleIfNeeded() {$/i\
    // Alice patch start 0036\
    /** 每次进入 Hub 时把横向牌堆恢复到当前标签所在卡片。 */\
    void resetAliceStackToCurrentTab() {\
        if (!AliceTabStackHelper.isStackLayout(mRecyclerView)) return;\
        @Nullable TabModel tabModel = mTabModelSupplier.get();\
        if (tabModel == null) return;\
        @Nullable Tab tab = tabModel.getTabAt(tabModel.index());\
        if (tab == null) return;\
        if (AliceTabStackHelper.shouldReorderTabs()) {\
            AliceTabStackHelper.resetToLastCard(mRecyclerView);\
            return;\
        }\
        int position = getIndexFromTabId(tab.getId());\
        if (position != TabModel.INVALID_TAB_INDEX) {\
            AliceTabStackHelper.resetToCard(mRecyclerView, position);\
        }\
    }\
    // Alice patch end 0036\
\
' "$path1"
# Alice patch end 0036


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
sed -i '/^import android.view.View;$/a\
// Alice patch start 0036\
import android.view.animation.Interpolator;\
// Alice patch end 0036\
' "$path2"

sed -i '/^    private float mSwipeToDismissThreshold;$/a\
    // Alice patch start 0036\
    private static final float ALICE_STACK_SWIPE_THRESHOLD_DP = 300f;\
    private static final float ALICE_STACK_SWIPE_EXIT_SPEED_PX_PER_MS = 8f;\
    private static final float ALICE_STACK_SWIPE_CANCEL_SPEED_PX_PER_MS = 2f;\
    private int mAliceSwipePosition = RecyclerView.NO_POSITION;\
    // Alice patch end 0036\
' "$path2"

sed -i '/^    public void onSelectedChanged(/,/^    }$/ s|^        @Nullable RecyclerView recyclerView = mRecyclerViewSupplier.get();$|&\n        // Alice patch start 0036\n        final boolean aliceSwipeSelected =\n                actionState == ItemTouchHelper.ACTION_STATE_SWIPE\n                        \&\& viewHolder != null\n                        \&\& AliceTabStackHelper.isStackLayout(recyclerView);\n        if (aliceSwipeSelected) {\n            assumeNonNull(viewHolder);\n            mAliceSwipePosition = viewHolder.getBindingAdapterPosition();\n        }\n        // Alice patch end 0036|' "$path2"

sed -i '/^    public int getMovementFlags(RecyclerView recyclerView, RecyclerView.ViewHolder viewHolder) {$/a\
        // Alice patch start 0036\
        // 横向堆叠样式：卡片不参与拖拽排序，只支持上滑关闭。\
        if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
            int swipeFlags = ItemTouchHelper.UP;\
            if (AliceTabStackHelper.consumeDiagonalUpSwipeDirectionBypass(recyclerView)) {\
                swipeFlags |= ItemTouchHelper.LEFT | ItemTouchHelper.RIGHT;\
            }\
            return makeMovementFlags(0, isSwipeable(viewHolder) ? swipeFlags : 0);\
        }\
        // Alice patch end 0036\
' "$path2"

sed -i '/^    public float getSwipeThreshold(RecyclerView.ViewHolder viewHolder) {$/a\
        // Alice patch start 0036\
        // 上滑关闭：固定 300dp，不随窗口高度变化。\
        @Nullable RecyclerView aliceRecyclerView = mRecyclerViewSupplier.get();\
        if (AliceTabStackHelper.isStackLayout(aliceRecyclerView)) {\
            assumeNonNull(aliceRecyclerView);\
            final float thresholdPx =\
                    AliceTabStackHelper.shouldCommitFastUpSwipe(aliceRecyclerView)\
                            ? AliceTabStackHelper.getFastSwipeMinDistancePx(\
                                    aliceRecyclerView)\
                            : ALICE_STACK_SWIPE_THRESHOLD_DP\
                                    * aliceRecyclerView\
                                            .getResources()\
                                            .getDisplayMetrics()\
                                            .density;\
            return thresholdPx / Math.max(1, aliceRecyclerView.getHeight());\
        }\
        // Alice patch end 0036\
' "$path2"

sed -i '/^    public float getSwipeThreshold(RecyclerView.ViewHolder viewHolder) {$/i\
    @Override\
    public long getAnimationDuration(\
            RecyclerView recyclerView,\
            int animationType,\
            float animateDx,\
            float animateDy) {\
        // Alice patch start 0036\
        if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
            final float distance =\
                    (float) Math.hypot(animateDx, animateDy);\
            final float speedPxPerMs =\
                    animationType == ItemTouchHelper.ANIMATION_TYPE_SWIPE_SUCCESS\
                            ? ALICE_STACK_SWIPE_EXIT_SPEED_PX_PER_MS\
                            : ALICE_STACK_SWIPE_CANCEL_SPEED_PX_PER_MS;\
            return Math.max(\
                    1L,\
                    Math.round(\
                            distance\
                                    / speedPxPerMs));\
        }\
        // Alice patch end 0036\
        return super.getAnimationDuration(\
                recyclerView, animationType, animateDx, animateDy);\
    }\
' "$path2"

sed -i '/^    public long getAnimationDuration($/i\
    public @Nullable Interpolator getAnimationInterpolator(int animationType) {\
        // Alice patch start 0036\
        if (AliceTabStackHelper.isStackLayout(mRecyclerViewSupplier.get())\
                \&\& (animationType == ItemTouchHelper.ANIMATION_TYPE_SWIPE_SUCCESS\
                        \|\| animationType == ItemTouchHelper.ANIMATION_TYPE_SWIPE_CANCEL)) {\
            return org.chromium.chrome.browser.hub.HubAnimationConstants\
                    .ALICE_STACK_INTERPOLATOR;\
        }\
        // Alice patch end 0036\
        return super.getAnimationInterpolator(animationType);\
    }\
    @Override\
' "$path2"

sed -i '/^    public float getSwipeThreshold(RecyclerView.ViewHolder viewHolder) {$/i\
    public float getSwipeEscapeVelocity(float defaultValue) {\
        // Alice patch start 0036\
        // 横向牌堆允许更短的上滑手势；速度快时不应因为位移不足而回弹。\
        if (AliceTabStackHelper.isStackLayout(mRecyclerViewSupplier.get())) {\
            return defaultValue * 0.6f;\
        }\
        // Alice patch end 0036\
        return super.getSwipeEscapeVelocity(defaultValue);\
    }\
    @Override\
' "$path2"

sed -i '/^        super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive);$/i\
        // Alice patch start 0036\
        // 斜上滑按关闭处理时，不允许横向分量拖动卡片。\
        if (AliceTabStackHelper.isDiagonalUpSwipeCandidate(recyclerView)) {\
            dX = 0f;\
        }\
        // Alice patch end 0036\
' "$path2"

sed -i '/^        super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive);$/a\
        // Alice patch start 0036\
        // 横向牌堆中禁止 ItemTouchHelper 提升被拖卡片层级。\
        if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
            viewHolder.itemView.setTranslationZ(0f);\
            viewHolder.itemView.setElevation(0f);\
            // 回收动画继续驱动挤压视觉，但不能覆盖最后一次真实上滑距离。\
            final int aliceAnchorPosition =\
                    isCurrentlyActive\
                            ? viewHolder.getBindingAdapterPosition()\
                            : mAliceSwipePosition;\
            if (aliceAnchorPosition == RecyclerView.NO_POSITION) return;\
            if (isCurrentlyActive) {\
                mAliceSwipePosition = aliceAnchorPosition;\
            }\
            final float aliceCloseProgress =\
                    Math.max(0f, -dY) / Math.max(1f, recyclerView.getHeight());\
            final float alicePushProgress =\
                    org.chromium.chrome.browser.hub.HubAnimationConstants\
                            .ALICE_STACK_INTERPOLATOR\
                            .getInterpolation(Math.min(1f, aliceCloseProgress));\
            AliceTabStackHelper.updateSwipePush(\
                    recyclerView,\
                    aliceAnchorPosition,\
                    alicePushProgress,\
                    alicePushProgress > 0f);\
        }\
        // Alice patch end 0036\
' "$path2"

sed -i '/^            mTabClosedListener.run($/,/^                    \/\* triggeringMotion= \*\/ null);$/c\
            // Alice patch start 0036\
            RecyclerView aliceSwipeRecyclerView = mRecyclerViewSupplier.get();\
            final int aliceClosePosition =\
                    mAliceSwipePosition != RecyclerView.NO_POSITION\
                            ? mAliceSwipePosition\
                            : viewHolder.getBindingAdapterPosition();\
            Runnable aliceCloseTab =\
                    () ->\
                            mTabClosedListener.run(\
                                    viewHolder.itemView,\
                                    model.get(TabProperties.TAB_ID),\
                                    /* triggeringMotion= */ null);\
            if (!AliceTabStackHelper.isStackLayout(aliceSwipeRecyclerView)\
                    || !AliceTabStackHelper.animateSwipeReplacementAndThen(\
                            aliceSwipeRecyclerView,\
                            aliceClosePosition,\
                            aliceCloseTab)) {\
                aliceCloseTab.run();\
            }\
            // Alice patch end 0036\
' "$path2"

sed -i '/^        super.clearView(recyclerView, viewHolder);$/a\
        // Alice patch start 0036\
        AliceTabStackHelper.onSwipeCleared(recyclerView);\
        // Alice patch end 0036\
' "$path2"

sed -i '/^                rv.setDuration(duration);$/a\
                // Alice patch start 0036\
                final @Nullable Interpolator aliceInterpolator =\
                        mCallback.getAnimationInterpolator(animationType);\
                if (aliceInterpolator != null) {\
                    rv.mValueAnimator.setInterpolator(aliceInterpolator);\
                }\
                // Alice patch end 0036\
' "$path19"

sed -i '/^        public long getAnimationDuration(/,/^        }$/ s#^        }$#&\n        // Alice patch start 0036\n        /** Returns an optional interpolator for the recover animation. */\n        public @Nullable Interpolator getAnimationInterpolator(int animationType) {\n            return null;\n        }\n        // Alice patch end 0036#' "$path19"

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

sed -i '/^            int index = model.get(INITIAL_SCROLL_INDEX);$/a\
            // Alice patch start 0036\
            if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
                if (AliceTabStackHelper.shouldReorderTabs()) {\
                    AliceTabStackHelper.resetToLastCard(recyclerView);\
                } else {\
                    AliceTabStackHelper.resetToCard(recyclerView, index);\
                }\
                return;\
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

sed -i '/^    public static void bindTab(/,/^    }$/ s|^        assertNonNull(propertyKey);$|&\n        // Alice patch start 0036\n        if (propertyKey == TabProperties.TAB_ACTION_STATE\n                \&\& AliceTabStackHelper.getEffectiveStyle()\n                        != AliceTabStackHelper.STYLE_HORIZONTAL) {\n            AliceTabStackHelper.resetCardTransform(view);\n        }\n        // Alice patch end 0036|' "$path18"

sed -i '/^    public static void onViewRecycled(PropertyModel model, View view) {$/a\
        // Alice patch start 0036\
        if (AliceTabStackHelper.getEffectiveStyle()\
                != AliceTabStackHelper.STYLE_HORIZONTAL) {\
            AliceTabStackHelper.resetCardTransform(view);\
        }\
        // Alice patch end 0036\
' "$path18"

# ---------- 8.2) TabSwitcherPaneCoordinator：点击后跟随 Hub 动画进度 ----------
sed -i '/^    public Rect getTabThumbnailRect(int tabId) {$/i\
    // Alice patch start 0036\
    public java.util.@Nullable List<View> getAliceRightCardViews(int tabId) {\
        int position = mTabListCoordinator.getIndexFromTabId(tabId);\
        if (position == TabModel.INVALID_TAB_INDEX) return null;\
        return mTabListCoordinator.getAliceRightCardViews(position);\
    }\
    // Alice patch end 0036\
\
' "$path13"

sed -i '/^    private TabListItemOnClickListenerProvider getTabListItemOnClickListenerProvider() {$/,/^    }$/c\
    // Alice patch start 0036\
    private TabListItemOnClickListenerProvider getTabListItemOnClickListenerProvider() {\
        return new TabListItemOnClickListenerProvider() {\
            @Override\
            public @Nullable TabActionListener onTabGroupClicked(Tab tab) {\
                return mMediator.onTabGroupClicked(tab);\
            }\
\
            @Override\
            public @Nullable TabActionListener onTabGroupClicked(String syncId) {\
                return mMediator.onTabGroupClicked(syncId);\
            }\
\
            @Override\
            public @Nullable Boolean isTabGroupSelected(Tab tab, PropertyModel model) {\
                return mMediator.isTabGroupSelected(tab, model);\
            }\
\
            @Override\
            public @Nullable TabActionButtonData getTabGroupActionButtonData(\
                    Tab tab,\
                    PropertyModel model,\
                    Supplier<TabActionListener> defaultOverflowListenerSupplier) {\
                return mMediator.getTabGroupActionButtonData(\
                        tab, model, defaultOverflowListenerSupplier);\
            }\
\
            @Override\
            public void onTabSelecting(int tabId) {\
                TabListRecyclerView recyclerView = mTabListCoordinator.getContainerView();\
                if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
                    int position = mTabListCoordinator.getIndexFromTabId(tabId);\
                    if (position != TabModel.INVALID_TAB_INDEX) {\
                        AliceTabStackHelper.animateNeighborAvoidance(\
                                recyclerView, position);\
                        mMediator.onTabSelecting(tabId);\
                        return;\
                    }\
                }\
                mMediator.onTabSelecting(tabId);\
            }\
        };\
    }\
    // Alice patch end 0036\
' "$path13"

sed -i '/^    public void setInitialScrollIndexOffset() {$/,/^    }$/c\
    // Alice patch start 0036\
    public void setInitialScrollIndexOffset() {\
        mMediator.setInitialScrollIndexOffset();\
        mTabListCoordinator.resetAliceStackToCurrentTab();\
    }\
    // Alice patch end 0036\
' "$path13"

# 横向样式的预览图使用未裁剪的完整变换矩形，避免右侧卡片只取到屏幕内残片。
sed -i '/^    public boolean dispatchTouchEvent(MotionEvent e) {$/,/^    }$/c\
    // Alice patch start 0036\
    @Override\
    public boolean dispatchTouchEvent(MotionEvent e) {\
        if (mBlockTouchInput) return true;\
        AliceTabStackHelper.onStackPreTouch(this, e);\
        return super.dispatchTouchEvent(e);\
    }\
    // Alice patch end 0036\
' "$path14"

sed -i '/^import android.graphics.Rect;$/i\
// Alice patch start 0036\
import android.graphics.Matrix;\
import android.graphics.RectF;\
// Alice patch end 0036\
' "$path14"

sed -i '/^    Rect getRectOfTabThumbnail(int tabIndex) {$/i\
    // Alice patch start 0036\
    Rect getAliceStackTabThumbnailRect(int tabIndex) {\
        SimpleRecyclerViewAdapter.ViewHolder holder =\
                (SimpleRecyclerViewAdapter.ViewHolder)\
                        findViewHolderForAdapterPosition(tabIndex);\
        Rect rect = new Rect();\
        if (holder == null || tabIndex == TabModel.INVALID_TAB_INDEX) return rect;\
        ViewLookupCachingFrameLayout root =\
                (ViewLookupCachingFrameLayout) holder.itemView;\
        View thumbnail = root.fastFindViewById(R.id.tab_thumbnail);\
        if (thumbnail == null) return rect;\
        Matrix matrix = new Matrix();\
        thumbnail.transformMatrixToGlobal(matrix);\
        RectF transformedBounds =\
                new RectF(\
                        0f,\
                        0f,\
                        thumbnail.getWidth(),\
                        thumbnail.getHeight());\
        matrix.mapRect(transformedBounds);\
        transformedBounds.round(rect);\
        return rect;\
    }\
    // Alice patch end 0036\
' "$path14"

sed -i '/^    Rect getRectOfTabThumbnail(int tabIndex) {$/a\
        // Alice patch start 0036\
        if (AliceTabStackHelper.isStackLayout(this)) {\
            return getAliceStackTabThumbnailRect(tabIndex);\
        }\
        // Alice patch end 0036\
' "$path14"

# 预览动画期间提供点击卡片右侧的卡片 View，用于在预览层挖空。
sed -i '/^    Rect getRectOfTabThumbnail(int tabIndex) {$/i\
    // Alice patch start 0036\
    public java.util.@Nullable List<View> getAliceRightCardViews(int anchorPosition) {\
        if (!AliceTabStackHelper.isStackLayout(this)\
                || anchorPosition == TabModel.INVALID_TAB_INDEX) {\
            return null;\
        }\
        ArrayList<View> cards = new ArrayList<>();\
        int itemCount = getAdapter() == null ? 0 : getAdapter().getItemCount();\
        for (int position = anchorPosition + 1; position < itemCount; position++) {\
            RecyclerView.ViewHolder holder = findViewHolderForAdapterPosition(position);\
            if (holder != null && holder.itemView.getVisibility() == View.VISIBLE) {\
                View card = holder.itemView.findViewById(R.id.card_view);\
                cards.add(card != null ? card : holder.itemView);\
            }\
        }\
        return cards;\
    }\
    // Alice patch end 0036\
\
' "$path14"

# ---------- 9) TabContentManager：仅横向样式捕获时提高倍率 ----------
sed -i '/^    private static final int WAIT_FOR_NATIVE_MAX_BACKOFF_ATTEMPTS = 2;$/a\
    // Alice patch start 0036\
    private static final String PREF_ALICE_TAB_SWITCHER_STYLE = "alice_tab_switcher_style";\
    private static final int ALICE_TAB_SWITCHER_STYLE_HORIZONTAL = 2;\
    private static final int ALICE_TAB_SWITCHER_STYLE_HORIZONTAL_NO_REORDER = 3;\
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
                        || style == ALICE_TAB_SWITCHER_STYLE_HORIZONTAL_NO_REORDER\
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
    /** 把真实 TabModel 中的激活标签移动到末尾。 */\
    private void moveAliceSelectedTabToLast(Tab tab) {\
        if (!mAliceStackStyle\
                || !AliceTabStackHelper.shouldReorderTabs()\
                || tab.getIsPinned()) {\
            return;\
        }\
        TabModel tabModel = getCurrentTabModelChecked();\
        int tabId = tab.getId();\
        int currentIndex = TabModelUtils.getTabIndexById(tabModel, tabId);\
        int lastIndex = tabModel.getCount() - 1;\
        if (currentIndex < 0 || currentIndex == lastIndex) return;\
        org.chromium.chrome.browser.hub.HubAnimationConstants\
                .setAlicePendingTabReorder(\
                        () -> {\
                            int pendingIndex =\
                                    TabModelUtils.getTabIndexById(tabModel, tabId);\
                            int pendingLastIndex = tabModel.getCount() - 1;\
                            if (pendingIndex >= 0\
                                    \&\& pendingIndex != pendingLastIndex) {\
                                tabModel.moveTab(tabId, pendingLastIndex);\
                            }\
                        });\
    }\
\
    /** 横向牌堆把当前标签放到最后一张，旧标签在左侧收拢。 */\
    private @Nullable List<Tab> maybeMoveAliceCurrentTabToLast(@Nullable List<Tab> tabs) {\
        if (!mAliceStackStyle\
                || !AliceTabStackHelper.shouldReorderTabs()\
                || tabs == null\
                || tabs.size() < 2) {\
            return tabs;\
        }\
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
\
    // Alice patch end 0036\
' "$path8"

sed -i '/^                        mTabListLayoutDelegate.didSelectTab(tab, type, lastId);$/a\
                        // Alice patch start 0036\
                        moveAliceSelectedTabToLast(tab);\
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
sed -i '/^    public void addTabListItemSizeChangedObserver(TabListItemSizeChangedObserver observer) {$/,/^    }$/ s|^        Size size = mMediator.getDefaultGridCardSize();$|&\n        // Alice patch start 0036\n        // 只有横向样式允许尺寸尚未布局完成。\n        if (AliceTabStackHelper.isStackLayout(mRecyclerView) \&\& size == null) return;\n        // Alice patch end 0036|' "$path1"

sed -i '/^    Size getThumbnailSize() {$/i\
    // Alice patch start 0036\
    java.util.@Nullable List<View> getAliceRightCardViews(int anchorPosition) {\
        return mRecyclerView.getAliceRightCardViews(anchorPosition);\
    }\
    // Alice patch end 0036\
\
' "$path1"

sed -i '/^    Size getThumbnailSize() {$/,/^    }$/ s|^        Size size = mMediator.getDefaultGridCardSize();$|&\n        // Alice patch start 0036\n        if (AliceTabStackHelper.isStackLayout(mRecyclerView) \&\& size == null) {\n            updateAliceStackCardLayout(mRecyclerView.getWidth());\n            size = mMediator.getDefaultGridCardSize();\n            if (size == null) return new Size(1, 1);\n        }\n        // Alice patch end 0036|' "$path1"

# ---------- 13) SingleChildViewManager：布局过程中改子视图一律延后（修 HubContainerView null child 崩溃） ----------
sed -i '/^    private void onViewChanged(@Nullable View view) {$/,/^    }$/{
    s|^    private void onViewChanged(@Nullable View view) {$|&\n        // Alice patch start 0036\n        // 仅横向样式的 Hub 层级需要避开布局过程中增删子视图。\n        if (HubAnimationConstants.isAliceHorizontalStyle() \&\& mContainerView.isInLayout()) {\n            final @Nullable View pendingView = view;\n            mContainerView.post(() -> onViewChanged(pendingView));\n            return;\n        }\n        // Alice patch end 0036|
}' "$path9"

# ---------- 14) HubManagerImpl：合成器布局流程中删 HubContainerView 子视图会崩，延后一帧 ----------
sed -i 's|^    public void onHubLayoutDoneHiding() {$|&\n        // Alice patch start 0036\n        // 仅横向样式需要在布局流程中延后删除 HubContainerView 的子视图。\n        if (HubAnimationConstants.isAliceHorizontalStyle()\n                \&\& mHubContainerView.isInLayout()) {\n            mHubContainerView.post(this::onHubLayoutDoneHiding);\n            return;\n        }\n        HubAnimationConstants.runAlicePendingTabReorder();\n        // Alice patch end 0036|' "$path10"

# ---------- 15) TabSwitcherPaneBase：仅横向样式调整预览图动画时长 ----------
sed -i '/^                                    bottomMargin));$/a\
        // Alice patch start 0036\
        {\
            @Nullable ShrinkExpandAnimationData aliceLayerAnimationData =\
                    animationDataSupplier.get();\
            if (aliceLayerAnimationData != null\
                    \&\& AliceTabStackHelper.getEffectiveStyle()\
                            == AliceTabStackHelper.STYLE_HORIZONTAL) {\
                aliceLayerAnimationData.setAliceRightCardViewsSupplier(\
                        () -> coordinator.getAliceRightCardViews(tabId));\
            }\
        }\
        // Alice patch end 0036\
' "$path4"

sed -i 's|^                HUB_LAYOUT_SHRINK_EXPAND_DURATION_MS,$|                AliceTabStackHelper.getHubAnimationDurationMs(),|' "$path4"

# ---------- 15.0) ShrinkExpandAnimationData：右侧卡片挖空区域 ----------
sed -i '/^    private final int mBottomMargin;$/a\
    // Alice patch start 0036\
    private java.util.function.@Nullable Supplier<\
                    java.util.@Nullable List<android.view.View>>\
            mAliceRightCardViewsSupplier;\
    // Alice patch end 0036\
' "$path15"

sed -i '$i\
    // Alice patch start 0036\
    public void setAliceRightCardViewsSupplier(\
            java.util.function.@Nullable Supplier<\
                            java.util.@Nullable List<android.view.View>>\
                    supplier) {\
        mAliceRightCardViewsSupplier = supplier;\
    }\
\
    public java.util.function.@Nullable Supplier<\
                    java.util.@Nullable List<android.view.View>>\
            getAliceRightCardViewsSupplier() {\
        return mAliceRightCardViewsSupplier;\
    }\
    // Alice patch end 0036\
' "$path15"

# ---------- 15.1) HubAnimationConstants：转发点击动画同步启动信号 ----------
sed -i '/^public class HubAnimationConstants {$/a\
    // Alice patch start 0036\
    public static final android.view.animation.Interpolator ALICE_STACK_INTERPOLATOR =\
            androidx.core.view.animation.PathInterpolatorCompat.create(\
                    0.22f, 0.72f, 0.38f, 1.0f);\
\
    private static Runnable sAliceHubTapAnimationStarter = () -> {};\
    private static Runnable sAliceHubEnterAnimationStarter = () -> {};\
    private static @Nullable Runnable sAlicePendingTabReorder;\
\
    public static void setAliceHubTapAnimationStarter(Runnable starter) {\
        sAliceHubTapAnimationStarter = starter;\
    }\
\
    public static void setAliceHubEnterAnimationStarter(Runnable starter) {\
        sAliceHubEnterAnimationStarter = starter;\
    }\
\
    public static void setAlicePendingTabReorder(@Nullable Runnable reorder) {\
        sAlicePendingTabReorder = reorder;\
    }\
\
    public static void runAlicePendingTabReorder() {\
        @Nullable Runnable reorder = sAlicePendingTabReorder;\
        sAlicePendingTabReorder = null;\
        if (reorder != null) reorder.run();\
    }\
\
    public static boolean isAliceHorizontalStyle() {\
        int style =\
                org.chromium.base.ContextUtils.getAppSharedPreferences()\
                        .getInt("alice_tab_switcher_style", 0);\
        return style == 2 || style == 3;\
    }\
\
    public static void notifyAliceHubTapAnimationStart() {\
        if (isAliceHorizontalStyle()) sAliceHubTapAnimationStarter.run();\
    }\
\
    public static void notifyAliceHubEnterAnimationStart() {\
        if (isAliceHorizontalStyle()) sAliceHubEnterAnimationStarter.run();\
    }\
    // Alice patch end 0036\
' "$path16"

# ---------- 15.2) ShrinkExpandImageView：右侧卡片区域挖空 ----------
sed -i '/^import android\.graphics\.Matrix;$/a\
// Alice patch start 0036\
import android.graphics.Canvas;\
import android.graphics.RectF;\
import android.view.View;\
import java.util.List;\
import java.util.function.Supplier;\
// Alice patch end 0036\
' "$path17"

sed -i '/^    private final RunOnNextLayoutDelegate mRunOnNextLayoutDelegate;$/a\
    // Alice patch start 0036\
    private @Nullable Supplier<@Nullable List<View>> mAliceRightCardViewsSupplier;\
    // Alice patch end 0036\
' "$path17"

sed -i '/^    public void reset(@Nullable Rect layoutRect) {$/i\
    // Alice patch start 0036\
    public void setAliceRightCardViewsSupplier(\
            @Nullable Supplier<@Nullable List<View>> supplier) {\
        mAliceRightCardViewsSupplier = supplier;\
        invalidate();\
    }\
\
    @Override\
    protected void onDraw(Canvas canvas) {\
        @Nullable Supplier<@Nullable List<View>> supplier = mAliceRightCardViewsSupplier;\
        @Nullable List<View> cards = supplier == null ? null : supplier.get();\
        if (cards == null || cards.isEmpty()) {\
            super.onDraw(canvas);\
            return;\
        }\
\
        Matrix previewToGlobal = new Matrix();\
        transformMatrixToGlobal(previewToGlobal);\
        Matrix globalToPreview = new Matrix();\
        if (!previewToGlobal.invert(globalToPreview)) {\
            super.onDraw(canvas);\
            return;\
        }\
\
        int saveCount = canvas.save();\
        for (View card : cards) {\
            if (card.getWidth() <= 0 || card.getHeight() <= 0) continue;\
            Matrix cardToGlobal = new Matrix();\
            card.transformMatrixToGlobal(cardToGlobal);\
            RectF cardBounds = new RectF(0f, 0f, card.getWidth(), card.getHeight());\
            cardToGlobal.mapRect(cardBounds);\
            globalToPreview.mapRect(cardBounds);\
            canvas.clipOutRect(cardBounds);\
        }\
        super.onDraw(canvas);\
        canvas.restoreToCount(saveCount);\
    }\
    // Alice patch end 0036\
\
' "$path17"

# ---------- 15.3) ShrinkExpandHubLayoutAnimatorProvider：动画清理也延后 ----------
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0036\
import android.view.ViewGroup;\
// Alice patch end 0036\
' "$path11"

sed -i '/^    private boolean mLayoutSatisfied;$/a\
    // Alice patch start 0036\
    private static final float ALICE_PREVIEW_BRING_TO_FRONT_FRACTION = 0.75f;\
    // Alice patch end 0036\
' "$path11"

sed -i '/^                        mShrinkExpandImageView.setVisibility(View.VISIBLE);$/a\
                        // Alice patch start 0036\
                        if (isShrink) {\
                            org.chromium.chrome.browser.hub.HubAnimationConstants\
                                    .notifyAliceHubEnterAnimationStart();\
                        } else {\
                            org.chromium.chrome.browser.hub.HubAnimationConstants\
                                    .notifyAliceHubTapAnimationStart();\
                        }\
                        // Alice patch end 0036\
' "$path11"

sed -i 's|^        return Interpolators\.EMPHASIZED;$|        // Alice patch start 0036\n        if (HubAnimationConstants.isAliceHorizontalStyle()) {\n            return HubAnimationConstants.ALICE_STACK_INTERPOLATOR;\n        }\n        return Interpolators.EMPHASIZED;\n        // Alice patch end 0036|' "$path11"

sed -i '/^        shrinkExpandAnimator\.setInterpolator(interpolator);$/a\
        // Alice patch start 0036\
        if (HubAnimationConstants.isAliceHorizontalStyle()) {\
            shrinkExpandAnimator.addUpdateListener(\
                    animation ->\
                            updateAlicePreviewZOrder(animation.getAnimatedFraction()));\
        }\
        // Alice patch end 0036\
' "$path11"

sed -i '/^        ShrinkExpandAnimationData animationData = mAnimationDataSupplier.get();$/a\
        // Alice patch start 0036\
        if (HubAnimationConstants.isAliceHorizontalStyle()) {\
            prepareAlicePreviewLayer(animationData);\
        }\
        // Alice patch end 0036\
' "$path11"

sed -i '/^    private void resetState() {$/i\
    // Alice patch start 0036\
    private void prepareAlicePreviewLayer(ShrinkExpandAnimationData animationData) {\
        if ((mAnimationType != HubLayoutAnimationType.EXPAND_TAB\
                        \&\& mAnimationType != HubLayoutAnimationType.SHRINK_TAB)\
                || !HubAnimationConstants.isAliceHorizontalStyle()\
                || mShrinkExpandImageView == null) {\
            return;\
        }\
        mShrinkExpandImageView.setAliceRightCardViewsSupplier(\
                animationData.getAliceRightCardViewsSupplier());\
    }\
\
    private void updateAlicePreviewZOrder(float fraction) {\
        if (mAnimationType != HubLayoutAnimationType.SHRINK_TAB\
                \&\& fraction >= ALICE_PREVIEW_BRING_TO_FRONT_FRACTION) {\
            clearAliceRightCardClip();\
        }\
    }\
\
    private void clearAliceRightCardClip() {\
        if (mShrinkExpandImageView != null) {\
            mShrinkExpandImageView.setAliceRightCardViewsSupplier(null);\
        }\
    }\
\
    private void restoreAlicePreviewLayer() {\
        clearAliceRightCardClip();\
    }\
\
    private void removeAlicePreviewView(@Nullable View view) {\
        if (view == null) return;\
        if (view.getParent() instanceof ViewGroup parent) {\
            parent.removeView(view);\
        }\
    }\
    // Alice patch end 0036\
\
' "$path11"

sed -i '/^    private void resetState() {$/a\
        // Alice patch start 0036\
        restoreAlicePreviewLayer();\
        // Alice patch end 0036\
' "$path11"

sed -i '/^    private void resetState() {$/,/^    }$/{
    s|^        mHubContainerView.removeView(mShrinkExpandImageView);$|        // Alice patch start 0036\n        // 仅横向样式在布局流程中延后删除预览层。\n        if (HubAnimationConstants.isAliceHorizontalStyle()\n                \&\& mHubContainerView.isInLayout()) {\n            final View aliceShrinkView = assumeNonNull(mShrinkExpandImageView);\n            final @Nullable View aliceFakeView = mFakeBottomControlsView;\n            mHubContainerView.post(\n                    () -> {\n                        removeAlicePreviewView(aliceShrinkView);\n                        removeAlicePreviewView(aliceFakeView);\n                    });\n            mShrinkExpandImageView.setImageBitmap(null);\n            mShrinkExpandImageView = null;\n            mFakeBottomControlsView = null;\n            return;\n        }\n        if (HubAnimationConstants.isAliceHorizontalStyle()) {\n            removeAlicePreviewView(mShrinkExpandImageView);\n        } else {\n            mHubContainerView.removeView(mShrinkExpandImageView);\n        }\n        // Alice patch end 0036|
}' "$path11"
