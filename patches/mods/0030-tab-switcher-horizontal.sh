#!/bin/bash
# 标签切换器「横向」样式（类 iOS 后台的横向堆叠卡片）
#   - 只有 设置-外观-标签切换器 选中「横向」时生效，且只作用于标签切换器网格
#     （TabComponentId.GRID_TAB_SWITCHER）；标签组对话框 / 标签编辑器 / 底部标签条不受影响。
#   - 卡片高度 = 标签列表可视区高度 × AliceTabStackHelper.CARD_HEIGHT_FRACTION，
#     宽度按窗口（App 窗口）的宽高比算，也就是「窗口高矮比例」。
#   - 后面的卡片压在左边的卡片上（露出卡片宽度的 CARD_PEEK_FRACTION），
#     离屏幕中心越远的卡片越小（透视），当前卡片（正中那张）在最上层；左右整页吸附切换。
#   - 卡片位置不做逐帧位移，只用等比缩放 + Z 序，所以滑动跟手、不会一顿一顿。
#   - 向上滑关闭标签；禁止左右拖拽（左右滑只用来滚动卡片列表）。
#   - 设置里改样式后不用重启浏览器：下次打开标签管理页时会自动切换布局。
#   - 顺带提高缩略图捕获倍率，让预览图更清晰（代价是内存占用上升）。

set -e

# 目标文件路径
path1="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListCoordinator.java"
path2="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabGridItemTouchHelperCallback.java"
path3="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListContainerViewBinder.java"
path4="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabSwitcherPaneBase.java"
path5="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"
path6="alice/chromium_src/chrome/android/chrome_java_ext_sources.gni"
path7="alice/chromium_src/chrome/android/java/src/org/chromium/chrome/browser/tasks/tab_management"
path8="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/pinned_tabs/PinnedTabStripCoordinator.java"
path9="chrome/android/features/tab_ui/java/src/org/chromium/chrome/browser/tasks/tab_management/TabListMediator.java"
path10="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/SingleChildViewManager.java"
path11="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"
path12="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"

# 检测是否已应用
# 用 path2 判断：path1 里还有别的 mod 的标记，用 path1 判断会被误认为已应用。
if grep -q 'Alice patch start' "$path2" \
        || grep -q 'Alice tab-switcher patch start' "$path2"; then
    exit 100
fi

# ---------- 新增文件 ----------
mkdir -p "$path7"

cat > "$path7/AliceTabStackHelper.java" << 'ALICE_EOF'
// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.tasks.tab_management;

import android.app.Activity;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.view.View;

import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.LinearSnapHelper;
import androidx.recyclerview.widget.RecyclerView;

import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;

import java.util.WeakHashMap;

/**
 * Alice: 标签切换器的「横向」样式（iOS 后台 / App Switcher 那样）。
 *
 * <p>卡片高度 = 标签列表可视区高度 × {@link #CARD_HEIGHT_FRACTION}，宽度按窗口的宽高比算
 * （也就是「窗口高矮比例」）；卡片横向排列，
 * 后面的卡片压在左边的卡片上，离屏幕中心越远的卡片越小（透视），当前卡片在最上层，
 * 松手后会吸附到屏幕正中。
 *
 * <p>卡片位置不做逐帧位移（只做等比缩放和 Z 序），所以手指滑动距离和列表滚动距离一致，
 * 不会一顿一顿，也不会和上滑关闭手势打架。
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

    /** 卡片高度 = 标签列表可视区高度 × 这个比例。嫌大/嫌小就改这一个数。 */
    public static final float CARD_HEIGHT_FRACTION = 0.7f;

    /** 后面那张卡片露出来的宽度 = 卡片宽度 × 这个比例（负 inset = 卡片互相重叠）。 */
    private static final float CARD_PEEK_FRACTION = 0.3f;

    /** 离屏幕中心最远的卡片缩小到 {@link #MIN_SCALE}（透视效果）。 */
    private static final float MIN_SCALE = 0.88f;

    /** 竖直居中的微调：正数 = 整组卡片往下挪「可视区高度 × 这个比例」。 */
    private static final float VERTICAL_BIAS_FRACTION = 0.02f;

    /** 主线程 Handler：把可能触发布局的动作挪出当前布局流程。 */
    private static final Handler sMainHandler = new Handler(Looper.getMainLooper());

    /** 已经装到某个标签列表上的横向样式状态，卸载时要还回去。 */
    private static final WeakHashMap<RecyclerView, Installed> sInstalled = new WeakHashMap<>();

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
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (!(layoutManager instanceof LinearLayoutManager)) return false;
        return !(layoutManager instanceof GridLayoutManager);
    }

    /** @return 列表可视区宽度（去掉 padding）。 */
    private static int getContentWidth(RecyclerView recyclerView) {
        return Math.max(
                0,
                recyclerView.getWidth()
                        - recyclerView.getPaddingLeft()
                        - recyclerView.getPaddingRight());
    }

    /** @return 列表可视区高度（去掉 padding）。 */
    private static int getContentHeight(RecyclerView recyclerView) {
        return Math.max(
                0,
                recyclerView.getHeight()
                        - recyclerView.getPaddingTop()
                        - recyclerView.getPaddingBottom());
    }

    /** @return 卡片高度（px）：标签列表可视区高度 × {@link #CARD_HEIGHT_FRACTION}。 */
    public static int getCardHeightPx(RecyclerView recyclerView) {
        return Math.max(1, Math.round(getContentHeight(recyclerView) * CARD_HEIGHT_FRACTION));
    }

    /**
     * @return 卡片宽度（px）：按窗口（App 窗口）的宽高比算，也就是「窗口高矮比例」，
     *         卡片形状和窗口一致。
     */
    public static int getCardWidthPx(Activity activity, int cardHeightPx) {
        return Math.max(1, Math.round(cardHeightPx * getWindowAspectRatio(activity)));
    }

    /** @return 窗口（App 窗口，去掉系统栏）的宽高比。 */
    public static float getWindowAspectRatio(Activity activity) {
        final Rect frame = new Rect();
        activity.getWindow().getDecorView().getWindowVisibleDisplayFrame(frame);
        if (frame.width() <= 0 || frame.height() <= 0) return 0.5f;
        return (float) frame.width() / frame.height();
    }

    /** @return 后面那张卡片露出来的宽度（px）。 */
    private static int getPeekPx(int cardWidthPx) {
        return Math.max(1, Math.round(cardWidthPx * CARD_PEEK_FRACTION));
    }

    /**
     * 装上横向堆叠样式：横向布局管理器 + 卡片间距/竖直居中 + 整页吸附 + 透视缩放。
     *
     * @param recyclerView 标签列表的 RecyclerView。
     * @param onLayoutCompleted 布局完成后的回调（调用方用于 checkAwaitingLayout）。
     */
    public static void setUp(RecyclerView recyclerView, @Nullable Runnable onLayoutCompleted) {
        tearDown(recyclerView);

        LinearLayoutManager layoutManager =
                new LinearLayoutManager(
                        recyclerView.getContext(), LinearLayoutManager.HORIZONTAL, false) {
                    @Override
                    public void onLayoutCompleted(RecyclerView.State state) {
                        super.onLayoutCompleted(state);
                        applyStackTransforms(recyclerView);
                        // 初始滚动偏移不一定正好落在正中，第一次布局完成后修正一次
                        // （这样第一张 / 最后一张卡片也能落在屏幕正中）。
                        postDeferred(() -> snapToCenterIfNeeded(recyclerView));
                        if (onLayoutCompleted != null) onLayoutCompleted.run();
                    }
                };
        recyclerView.setLayoutManager(layoutManager);

        StackItemDecoration decoration = new StackItemDecoration();
        recyclerView.addItemDecoration(decoration);

        // iOS 后台那样吸附：松手后居中那张卡片会吸到屏幕正中。
        // 用 LinearSnapHelper 而不是 PagerSnapHelper，甩得狠可以连续滑好几张，不会一张一张地卡。
        LinearSnapHelper snapHelper = new LinearSnapHelper();
        snapHelper.attachToRecyclerView(recyclerView);

        RecyclerView.OnScrollListener scrollListener =
                new RecyclerView.OnScrollListener() {
                    @Override
                    public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                        applyStackTransforms(recyclerView);
                    }
                };
        recyclerView.addOnScrollListener(scrollListener);

        // Z 序：View 的 translationZ 在 RecyclerView 里不一定会真的改变绘制顺序，
        // 用绘制顺序回调才可靠 —— 把离屏幕中心最近的那张卡片放到最后画（画在最上层）。
        RecyclerView.ChildDrawingOrderCallback orderCallback =
                (childCount, i) -> {
                    Installed state = sInstalled.get(recyclerView);
                    if (state == null || state.mTopChildIndex < 0 || childCount <= 0) return i;
                    final int top = Math.min(state.mTopChildIndex, childCount - 1);
                    if (i == childCount - 1) return top;
                    if (i == top) return childCount - 1;
                    return i;
                };
        recyclerView.setChildDrawingOrderCallback(orderCallback);

        sInstalled.put(
                recyclerView, new Installed(decoration, snapHelper, scrollListener, orderCallback));
        applyStackTransforms(recyclerView);
    }

    /** 卸载横向堆叠样式（切回「默认」样式之前调用）。 */
    public static void tearDown(@Nullable RecyclerView recyclerView) {
        if (recyclerView == null) return;
        Installed installed = sInstalled.remove(recyclerView);
        if (installed == null) return;
        recyclerView.removeItemDecoration(installed.mDecoration);
        installed.mSnapHelper.attachToRecyclerView(null);
        recyclerView.removeOnScrollListener(installed.mScrollListener);
        recyclerView.setChildDrawingOrderCallback(null);
        for (int i = 0; i < recyclerView.getChildCount(); i++) {
            View child = recyclerView.getChildAt(i);
            if (child == null) continue;
            child.setScaleX(1f);
            child.setScaleY(1f);
            child.setTranslationX(0f);
        }
    }

    /**
     * 按卡片离屏幕中心的距离做透视缩放，并调整 Z 序（居中那张在最上层）。
     *
     * <p>只改缩放和 Z 序，不改位置：滑动距离和手指一致，不会一顿一顿的。
     */
    public static void applyStackTransforms(RecyclerView recyclerView) {
        if (!isStackLayout(recyclerView)) return;
        if (getContentWidth(recyclerView) <= 0 || recyclerView.getChildCount() == 0) return;
        final float center =
                (recyclerView.getPaddingLeft()
                                + recyclerView.getWidth()
                                - recyclerView.getPaddingRight())
                        / 2f;
        int topChildIndex = -1;
        float topDistance = Float.MAX_VALUE;
        for (int i = 0; i < recyclerView.getChildCount(); i++) {
            View child = recyclerView.getChildAt(i);
            if (child == null || child.getWidth() <= 0) continue;
            // 相邻两张卡片在布局上只隔 (卡片宽 - 露出来的宽度)，用这个当缩放的距离单位。
            final float stride = Math.max(1f, child.getWidth() - getPeekPx(child.getWidth()));
            final float dx = (child.getLeft() + child.getRight()) / 2f - center;
            final float distance = Math.abs(dx);
            final float scale = 1f - (1f - MIN_SCALE) * Math.min(1f, distance / stride);
            child.setScaleX(scale);
            child.setScaleY(scale);
            if (distance < topDistance) {
                topDistance = distance;
                topChildIndex = i;
            }
        }
        // 居中的那张卡片画在最上层（见 setUp 里的 ChildDrawingOrderCallback）。
        Installed state = sInstalled.get(recyclerView);
        if (state != null) state.mTopChildIndex = topChildIndex;
    }

    /** 把离屏幕中心最近的那张卡片吸到正中（只在第一次布局之后做一次）。 */
    private static void snapToCenterIfNeeded(RecyclerView recyclerView) {
        Installed state = sInstalled.get(recyclerView);
        if (state == null || state.mDidInitialSnap) return;
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager == null) return;
        View snapView = state.mSnapHelper.findSnapView(layoutManager);
        if (snapView == null) return;
        state.mDidInitialSnap = true;
        final int[] distance =
                state.mSnapHelper.calculateDistanceToFinalSnap(layoutManager, snapView);
        if (distance != null && (distance[0] != 0 || distance[1] != 0)) {
            recyclerView.smoothScrollBy(distance[0], distance[1]);
        }
    }

    /** 已经装到某个 RecyclerView 上的东西，卸载时要还回去。 */
    private static final class Installed {
        final StackItemDecoration mDecoration;
        final LinearSnapHelper mSnapHelper;
        final RecyclerView.OnScrollListener mScrollListener;
        final RecyclerView.ChildDrawingOrderCallback mOrderCallback;

        /** 当前离屏幕中心最近的卡片下标（画在最上层）。 */
        int mTopChildIndex = -1;

        /** 第一次布局后是不是已经吸到正中过了。 */
        boolean mDidInitialSnap;

        Installed(
                StackItemDecoration decoration,
                LinearSnapHelper snapHelper,
                RecyclerView.OnScrollListener scrollListener,
                RecyclerView.ChildDrawingOrderCallback orderCallback) {
            mDecoration = decoration;
            mSnapHelper = snapHelper;
            mScrollListener = scrollListener;
            mOrderCallback = orderCallback;
        }
    }

    /** 卡片之间的横向间距（露出后面那张卡片的边）+ 竖直方向居中。 */
    private static final class StackItemDecoration extends RecyclerView.ItemDecoration {
        @Override
        public void getItemOffsets(
                Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
            outRect.set(0, 0, 0, 0);
            if (!isStackLayout(parent)) return;
            final int contentHeight = getContentHeight(parent);
            if (contentHeight <= 0) return;
            // 卡片宽度：绑定的时候已经按 GRID_CARD_SIZE 写进 LayoutParams 了。
            int cardWidthPx = view.getWidth();
            if (cardWidthPx <= 0 && view.getLayoutParams() != null) {
                cardWidthPx = view.getLayoutParams().width;
            }
            if (cardWidthPx > 0) {
                // 负 inset = 后面的卡片压在前面的卡片上（互相重叠），露出 CARD_PEEK_FRACTION。
                // 左右对称，所以卡片自身的中心仍然是视口中心（吸附和缩放都按它算）。
                int inset = -Math.round(getPeekPx(cardWidthPx) / 2f);
                // 第一张 / 最后一张再各留一段空白，这样它们也能滑到屏幕正中，
                // 不会像现在这样被顶在边上显示不全。
                final int position = parent.getChildAdapterPosition(view);
                if (position == 0 || position == state.getItemCount() - 1) {
                    inset += Math.max(0, (getContentWidth(parent) - cardWidthPx) / 2);
                }
                outRect.left = inset;
                outRect.right = inset;
            }
            // 竖直方向居中：横向列表里卡片的上下位置由这里的 inset 决定
            // （不能改 RecyclerView 的 paddingTop，上游会把它清成 0）。
            outRect.top =
                    Math.max(
                            0,
                            (contentHeight - getCardHeightPx(parent)) / 2
                                    + Math.round(contentHeight * VERTICAL_BIAS_FRACTION));
        }
    }
}
ALICE_EOF

# ---------- 注册新增源文件（chrome_java 目标） ----------
sed -i 's|^  "java/src/org/chromium/chrome/browser/ChromeApplicationImplHooks.java",$|&\n  # Alice patch start\n  "java/src/org/chromium/chrome/browser/tasks/tab_management/AliceTabStackHelper.java",\n  # Alice patch end|' "$path6"

# ---------- 1) TabListCoordinator：GRID 分支记下网格布局管理器并应用当前样式 ----------
# 上游的网格分支照常创建（这样切回「默认」样式时可以直接还原这个 LayoutManager），
# 建完再按设置看要不要换成横向堆叠布局。
sed -i '/^                updateGridCardLayout(frame.width());$/a\
                // Alice patch start\
                // 记住上游的网格布局管理器：切回「默认」样式时用它还原。\
                mAliceGridLayoutManager = gridLayoutManager;\
                if (AliceTabStackHelper.isGridTabSwitcher(componentId)) {\
                    mAliceTabSwitcherGrid = true;\
                    updateAliceTabSwitcherStyleIfNeeded();\
                }\
                // Alice patch end\
' "$path1"

# ---------- 2) TabListCoordinator：记录横向样式相关的状态 ----------
sed -i '/^    private @Nullable OnLayoutChangeListener mListLayoutListener;$/a\
    // Alice patch start\
    /** 上游 GRID 模式创建的网格布局管理器（切回「默认」样式时还原用）。 */\
    private @Nullable GridLayoutManager mAliceGridLayoutManager;\
\
    /** 本协调器是不是标签切换器网格（只有它对「标签切换器」设置生效）。 */\
    private boolean mAliceTabSwitcherGrid;\
\
    /** 已经应用到界面上的样式（-1 = 还没应用过）。 */\
    private int mAliceAppliedStyle = -1;\
    // Alice patch end\
' "$path1"

# ---------- 3) TabListCoordinator：改设置后不用重启浏览器 ----------
sed -i '/^        return mMediator.resetWithListOfTabs(tabs, tabGroupSyncIds, quickMode);$/i\
        // Alice patch start\
        // 设置里换过「标签切换器」样式的话，这里就把布局换过来（不用重启浏览器）。\
        updateAliceTabSwitcherStyleIfNeeded();\
        // Alice patch end\
' "$path1"


# ---------- 4) TabListCoordinator：横向样式的卡片尺寸 ----------
sed -i '/^    private void updateGridCardLayout(int viewWidth) {$/i\
    // Alice patch start\
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
            AliceTabStackHelper.setUp(mRecyclerView, this::checkAwaitingLayout);\
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
     * 横向样式的卡片尺寸：高度 = 标签列表可视区高度 × CARD_HEIGHT_FRACTION，宽度按窗口内容区\
     * （也就是标签预览图）的宽高比算，所以卡片就是窗口的形状、预览图不会被裁掉。\
     * 竖直方向的位置由 AliceTabStackHelper 的 ItemDecoration 居中。\
     */\
    private void updateAliceStackCardLayout(int viewWidth) {\
        if (mRecyclerView.getWidth() <= 0 || mRecyclerView.getHeight() <= 0) return;\
        final int cardHeightPx = AliceTabStackHelper.getCardHeightPx(mRecyclerView);\
        final int cardWidthPx = AliceTabStackHelper.getCardWidthPx(mActivity, cardHeightPx);\
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
    // Alice patch end\
' "$path1"


# ---------- 5) TabListCoordinator：横向样式不去算网格空位布局 ----------
sed -i '/^        final GridLayoutManager layoutManager =$/i\
        // Alice patch start\
        // 横向堆叠样式下卡片大小是固定的（见 updateAliceStackCardLayout），不走网格那套。\
        if (AliceTabStackHelper.isStackLayout(mRecyclerView)) {\
            updateAliceStackCardLayout(viewWidth);\
            return;\
        }\
        // Alice patch end\
' "$path1"

# ---------- 6) TabGridItemTouchHelperCallback：上滑关闭、禁用左右拖拽 ----------
sed -i '/^    public int getMovementFlags(RecyclerView recyclerView, RecyclerView.ViewHolder viewHolder) {$/a\
        // Alice patch start\
        // 横向堆叠样式：卡片不参与拖拽排序，只支持上滑关闭。\
        if (AliceTabStackHelper.isStackLayout(recyclerView)) {\
            return makeMovementFlags(0, isSwipeable(viewHolder) ? ItemTouchHelper.UP : 0);\
        }\
        // Alice patch end\
' "$path2"

sed -i '/^    public float getSwipeThreshold(RecyclerView.ViewHolder viewHolder) {$/a\
        // Alice patch start\
        // 上滑关闭：阈值按卡片高度的五分之一左右。\
        if (AliceTabStackHelper.isStackLayout(mRecyclerViewSupplier.get())) return 0.2f;\
        // Alice patch end\
' "$path2"

# ---------- 7) TabListContainerViewBinder：初始滚动偏移（当前卡片居中） ----------
sed -i '/^        LinearLayoutManager layoutManager = (LinearLayoutManager) view.getLayoutManager();$/i\
        // Alice patch start\
        // 横向样式：卡片比视口窄，初始位置居中（随后由吸附助手吸到正中）。\
        if (AliceTabStackHelper.isStackLayout(view)) {\
            return Math.max(\
                    0,\
                    (view.getWidth()\
                                    - AliceTabStackHelper.getCardWidthPx(\
                                            (Activity) view.getContext(),\
                                            AliceTabStackHelper.getCardHeightPx(view)))\
                            / 2);\
        }\
        // Alice patch end\
' "$path3"

# ---------- 8) TabSwitcherPaneBase：允许非 GridLayoutManager ----------
# 这里原来直接强转 GridLayoutManager，横向样式下会 ClassCastException。
sed -i 's|^import androidx.recyclerview.widget.GridLayoutManager;$|// Alice patch start\nimport androidx.recyclerview.widget.LinearLayoutManager;\n// Alice patch end|' "$path4"
sed -i 's|^                    GridLayoutManager lm =$|                    // Alice patch start\n                    LinearLayoutManager lm =|' "$path4"
sed -i 's|^                            (GridLayoutManager) tabListRecyclerView.getLayoutManager();$|                            (LinearLayoutManager) tabListRecyclerView.getLayoutManager();\n                    // Alice patch end|' "$path4"

# ---------- 9) 缩略图更清晰 ----------
sed -i 's|^\( *\)thumbnailScale = 1.5f / deviceDensity;$|\1// Alice patch start\n\1// Alice: 提高缩略图捕获倍率，标签预览更清晰（代价是内存占用上升）。\n\1thumbnailScale = 3.0f / deviceDensity;\n\1// Alice patch end|' "$path5"

# ---------- 10) 固定标签条：横向样式下主标签列表不是 GridLayoutManager ----------
# 原来这里直接强转，横向样式下会 ClassCastException（打开标签管理页时崩在固定标签条构造里）。
# 退化成没挂到 RecyclerView 上的 GridLayoutManager(span=1)，固定标签条查不到可见项会自动隐藏。
sed -i 's|^        GridLayoutManager tabGridListLayoutManager =$|        // Alice patch start\n        RecyclerView.LayoutManager aliceTabGridListLayoutManager =\n                tabGridListRecyclerView.getLayoutManager();\n        GridLayoutManager tabGridListLayoutManager =\n                aliceTabGridListLayoutManager instanceof GridLayoutManager\n                        ? (GridLayoutManager) aliceTabGridListLayoutManager\n                        : new GridLayoutManager(activity, 1);\n        // Alice patch end|' "$path8"

sed -i '/^                (GridLayoutManager) tabGridListRecyclerView.getLayoutManager();$/d' "$path8"

# ---------- 11) TabListMediator：横向样式下没有网格布局，跳过网格相关逻辑 ----------
sed -i '/^    private @Nullable GridLayoutManager mGridLayoutManager;$/a\
    // Alice patch start\
    /** 横向堆叠样式下没有可用的网格布局，跳过所有网格相关逻辑。 */\
    private boolean mAliceStackStyle;\
\
    void setAliceStackStyle(boolean enabled) {\
        mAliceStackStyle = enabled;\
    }\
    // Alice patch end\
' "$path9"

sed -i '/^    int getPriceWelcomeMessageInsertionIndex() {$/a\
        // Alice patch start\
        // 横向堆叠样式下没有网格布局，不做消息卡片定位。\
        if (mAliceStackStyle || mGridLayoutManager == null) return TabList.INVALID_TAB_INDEX;\
        // Alice patch end\
' "$path9"

sed -i '/^    void updateLayout() {$/a\
        // Alice patch start\
        // 横向堆叠样式下没有网格布局，跳过网格空位整理。\
        if (mAliceStackStyle || mGridLayoutManager == null) return;\
        // Alice patch end\
' "$path9"

# ---------- 12) TabListCoordinator：尺寸还没算出来时不要用 null 通知/取缩略图尺寸 ----------
sed -i '/^    public void addTabListItemSizeChangedObserver(TabListItemSizeChangedObserver observer) {$/,/^    }$/ s|^        Size size = mMediator.getDefaultGridCardSize();$|&\n        // Alice patch start\n        // 横向样式的卡片尺寸要等第一次布局之后才算得出来，这里先跳过。\n        if (size == null) return;\n        // Alice patch end|' "$path1"

sed -i '/^    Size getThumbnailSize() {$/,/^    }$/ s|^        Size size = mMediator.getDefaultGridCardSize();$|&\n        // Alice patch start\n        if (size == null) {\n            updateAliceStackCardLayout(mRecyclerView.getWidth());\n            size = mMediator.getDefaultGridCardSize();\n            if (size == null) return new Size(1, 1);\n        }\n        // Alice patch end|' "$path1"

# ---------- 13) SingleChildViewManager：布局过程中改子视图一律延后（修 HubContainerView null child 崩溃） ----------
sed -i '/^    private void onViewChanged(@Nullable View view) {$/,/^    }$/{
    s|^    private void onViewChanged(@Nullable View view) {$|&\n        // Alice patch start\n        // 布局过程中直接增删子视图，会让父容器（HubContainerView）的 children 出现 null 而崩溃；\n        // 这里统一延后一帧，并打一条带调用栈的日志便于定位。\n        if (mContainerView.isInLayout()) {\n            final @Nullable View pendingView = view;\n            android.util.Log.w("AliceHub", "defer onViewChanged in layout: " + view, new Throwable());\n            mContainerView.post(() -> onViewChanged(pendingView));\n            return;\n        }\n        // Alice patch end|
}' "$path10"

# ---------- 14) HubManagerImpl：合成器布局流程中删 HubContainerView 子视图会崩，延后一帧 ----------
sed -i 's|^    public void onHubLayoutDoneHiding() {$|&\n        // Alice patch start\n        // 本方法在合成器布局流程（即 View 布局过程中）被调用，直接 removeAllViews() 会让\n        // HubContainerView 的 children 出现 null 而崩溃（点卡片关闭 Hub 时必现）；延后一帧。\n        if (mHubContainerView.isInLayout()) {\n            android.util.Log.w("AliceHub", "defer onHubLayoutDoneHiding", new Throwable());\n            mHubContainerView.post(this::onHubLayoutDoneHiding);\n            return;\n        }\n        // Alice patch end|' "$path11"

# ---------- 15) ShrinkExpandHubLayoutAnimatorProvider：动画清理也延后 ----------
sed -i '/^    private void resetState() {$/,/^    }$/{
    s|^        mHubContainerView.removeView(mShrinkExpandImageView);$|        // Alice patch start\n        // 布局过程中不要直接移除 HubContainerView 的子视图（会崩）；把删除延后一帧，状态照常清理。\n        if (mHubContainerView.isInLayout()) {\n            final View aliceShrinkView = assumeNonNull(mShrinkExpandImageView);\n            final @Nullable View aliceFakeView = mFakeBottomControlsView;\n            android.util.Log.w("AliceHub", "defer resetState removals", new Throwable());\n            mHubContainerView.post(\n                    () -> {\n                        mHubContainerView.removeView(aliceShrinkView);\n                        if (aliceFakeView != null) {\n                            mHubContainerView.removeView(aliceFakeView);\n                        }\n                    });\n            mShrinkExpandImageView.setImageBitmap(null);\n            mShrinkExpandImageView = null;\n            mFakeBottomControlsView = null;\n            return;\n        }\n        // Alice patch end\n        mHubContainerView.removeView(mShrinkExpandImageView);|
}' "$path12"
