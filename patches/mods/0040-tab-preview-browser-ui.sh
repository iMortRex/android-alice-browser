#!/bin/bash
# 捕获网页快照时合成工具栏和系统导航栏区域。

set -e

path1="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabThumbnailView.java"
path2="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"
path3="chrome/browser/android/compositor/tab_content_manager.cc"
path4="chrome/browser/android/compositor/tab_content_manager.h"
path5="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/compositor/layouts/ToolbarSwipeLayout.java"

# 检测是否已应用
if grep -q 'Alice patch start 0040' "$path1"; then
    exit 100
fi

# 1) TabThumbnailView 只保留说明标记，工具栏在网页快照捕获阶段处理
sed -i '/^import android\.widget\.ImageView;$/a\
// Alice patch start 0040\
// Alice: 工具栏在网页快照捕获阶段合成，不在标签管理页卡片中实时叠加。\
// Alice patch end 0040' "$path1"

# 2) TabContentManager：补 import
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0040\
import android.app.Activity;\
// Alice patch end 0040' "$path2"

sed -i '/^import android\.graphics\.Matrix;$/a\
// Alice patch start 0040\
import android.graphics.Paint;\
import android.graphics.Rect;\
import android.graphics.RectF;\
import android.graphics.drawable.RippleDrawable;\
// Alice patch end 0040' "$path2"

sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0040\
import android.view.ViewGroup;\
// Alice patch end 0040' "$path2"

sed -i '/^import androidx\.annotation\.VisibleForTesting;$/a\
// Alice patch start 0040\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0040' "$path2"

sed -i '/^import org\.chromium\.base\.CommandLine;$/a\
// Alice patch start 0040\
import org.chromium.base.ContextUtils;\
// Alice patch end 0040' "$path2"

sed -i '/^import org\.chromium\.ui\.base\.DeviceFormFactor;$/a\
// Alice patch start 0040\
import org.chromium.ui.base.ViewUtils;\
// Alice patch end 0040' "$path2"

sed -i '/^import java\.util\.List;$/a\
// Alice patch start 0040\
import java.util.HashMap;\
import java.util.HashSet;\
import java.util.Map;\
import java.util.Set;\
// Alice patch end 0040' "$path2"

sed -i '/^    private final ArrayList<ThumbnailChangeListener> mListeners = new ArrayList<>();$/a\
    // Alice patch start 0040\
    private final Set<Integer> mAliceCompositingTabIds = new HashSet<>();\
    private final Map<Integer, List<AlicePendingThumbnailRequest>>\
            mAlicePendingThumbnailRequests = new HashMap<>();\
    private int mAliceRecentCompositedTabId = Tab.INVALID_TAB_ID;\
    private @Nullable Bitmap mAliceRecentCompositedThumbnail;\
    private @Nullable Bitmap mAliceLastToolbarBitmap;\
    // Alice patch end 0040' "$path2"

# 3) TabContentManager：捕获工具栏并合成到网页 Bitmap
sed -i '/^    private @Nullable Bitmap cacheNativeTabThumbnail(final Tab tab) {$/i\
    // Alice patch start 0040\
    private static class AlicePendingThumbnailRequest {\
        final Size mThumbnailSize;\
        final Callback<@Nullable Bitmap> mCallback;\
\
        AlicePendingThumbnailRequest(\
                Size thumbnailSize, Callback<@Nullable Bitmap> callback) {\
            mThumbnailSize = thumbnailSize;\
            mCallback = callback;\
        }\
    }\
\
    private @Nullable Bitmap copyAliceCompositedThumbnail(Bitmap bitmap) {\
        try {\
            return bitmap.copy(Bitmap.Config.ARGB_8888, false);\
        } catch (OutOfMemoryError ex) {\
            return null;\
        }\
    }\
\
    private void rememberAliceToolbarBitmap(Bitmap bitmap) {\
        @Nullable Bitmap copy = copyAliceCompositedThumbnail(bitmap);\
        if (copy == null) return;\
        @Nullable Bitmap previous = mAliceLastToolbarBitmap;\
        mAliceLastToolbarBitmap = copy;\
        if (previous != null) previous.recycle();\
    }\
\
    private void finishAliceCompositedThumbnail(Tab tab, @Nullable Bitmap bitmap) {\
        int tabId = tab.getId();\
        mAliceCompositingTabIds.remove(tabId);\
        List<AlicePendingThumbnailRequest> requests =\
                mAlicePendingThumbnailRequests.remove(tabId);\
        @Nullable Bitmap immediateBitmap = null;\
        if (bitmap != null) {\
            immediateBitmap = copyAliceCompositedThumbnail(bitmap);\
        }\
        if (immediateBitmap != null) {\
            mAliceRecentCompositedTabId = tabId;\
            mAliceRecentCompositedThumbnail = immediateBitmap;\
        }\
        if (requests == null || requests.isEmpty()) return;\
        for (AlicePendingThumbnailRequest request : requests) {\
            if (immediateBitmap == null) {\
                getTabThumbnailFromDisk(\
                        tabId, request.mThumbnailSize, request.mCallback);\
            } else {\
                Callback.runNullSafe(request.mCallback, immediateBitmap);\
            }\
        }\
    }\
\
    private @Nullable View findAliceToolbarView(View view) {\
        @Nullable View best = null;\
        long bestArea = 0;\
        if (view.getClass().getName().endsWith(".ToolbarControlContainer")\
                \&\& view.isAttachedToWindow()\
                \&\& view.isShown()\
                \&\& view.getWidth() > 0\
                \&\& view.getHeight() > 0) {\
            best = view;\
            bestArea = (long) view.getWidth() * view.getHeight();\
        }\
        if (!(view instanceof ViewGroup)) return best;\
        ViewGroup group = (ViewGroup) view;\
        for (int i = 0; i < group.getChildCount(); i++) {\
            @Nullable View result = findAliceToolbarView(group.getChildAt(i));\
            if (result == null) continue;\
            long area = (long) result.getWidth() * result.getHeight();\
            if (area > bestArea) {\
                best = result;\
                bestArea = area;\
            }\
        }\
        return best;\
    }\
\
    private boolean isAliceToolbarBitmapUsable(Bitmap bitmap) {\
        if (bitmap.getWidth() <= 0 || bitmap.getHeight() <= 0) return false;\
        int firstColor = 0;\
        boolean hasFirst = false;\
        boolean hasVisible = false;\
        boolean hasVariation = false;\
        for (int y = 0; y < 3; y++) {\
            int sampleY = Math.min(bitmap.getHeight() - 1, y * bitmap.getHeight() / 2);\
            for (int x = 0; x < 5; x++) {\
                int sampleX = Math.min(bitmap.getWidth() - 1, x * bitmap.getWidth() / 4);\
                int color = bitmap.getPixel(sampleX, sampleY);\
                if (android.graphics.Color.alpha(color) == 0) continue;\
                hasVisible = true;\
                if (!hasFirst) {\
                    firstColor = color;\
                    hasFirst = true;\
                } else if (color != firstColor) {\
                    hasVariation = true;\
                }\
            }\
        }\
        return hasVisible \&\& hasVariation;\
    }\
\
    private void prepareAliceToolbarForCapture(View view, List<View> pressedViews) {\
        boolean wasPressed = view.isPressed();\
        if (wasPressed) {\
            view.setPressed(false);\
            pressedViews.add(view);\
        }\
        if (wasPressed\
                || view.getBackground() instanceof RippleDrawable\
                || view.getForeground() instanceof RippleDrawable) {\
            view.jumpDrawablesToCurrentState();\
        }\
        if (!(view instanceof ViewGroup)) return;\
        ViewGroup group = (ViewGroup) view;\
        for (int i = 0; i < group.getChildCount(); i++) {\
            prepareAliceToolbarForCapture(group.getChildAt(i), pressedViews);\
        }\
    }\
\
    private void restoreAliceToolbarPressState(List<View> pressedViews) {\
        for (View view : pressedViews) {\
            view.setPressed(true);\
        }\
    }\
\
    private @Nullable View getAliceToolbarView(Tab tab) {\
        Activity activity = ContextUtils.activityFromContext(mContext);\
        if (activity == null) return null;\
        return findAliceToolbarView(activity.getWindow().getDecorView());\
    }\
\
    private @Nullable Bitmap captureAliceToolbarBitmap(@Nullable View toolbar) {\
        if (toolbar == null\
                || !toolbar.isAttachedToWindow()\
                || toolbar.getWidth() <= 0\
                || toolbar.getHeight() <= 0) {\
            return null;\
        }\
        try {\
            Bitmap bitmap =\
                    Bitmap.createBitmap(\
                            toolbar.getWidth(), toolbar.getHeight(), Bitmap.Config.ARGB_8888);\
            // Do not persist pressed/ripple effects from the click that opens the switcher.\
            List<View> pressedViews = new ArrayList<>();\
            prepareAliceToolbarForCapture(toolbar, pressedViews);\
            try {\
                ViewUtils.captureBitmap(toolbar, new Canvas(bitmap));\
                if (isAliceToolbarBitmapUsable(bitmap)) return bitmap;\
                bitmap.recycle();\
                return null;\
            } finally {\
                restoreAliceToolbarPressState(pressedViews);\
            }\
        } catch (OutOfMemoryError ex) {\
            return null;\
        }\
    }\
\
    private @Nullable Bitmap addAliceToolbarToThumbnail(\
            Bitmap thumbnail, @Nullable View toolbarView, Bitmap toolbarBitmap) {\
        try {\
            float scale = thumbnail.getWidth() / (float) toolbarBitmap.getWidth();\
            int navigationHeight = 0;\
            @Nullable Activity aliceActivity = ContextUtils.activityFromContext(mContext);\
            @Nullable View aliceInsetRoot =\
                    toolbarView != null\
                            ? toolbarView.getRootView()\
                            : aliceActivity == null\
                                    ? null\
                                    : aliceActivity.getWindow().getDecorView();\
            WindowInsetsCompat insets =\
                    aliceInsetRoot == null ? null : ViewCompat.getRootWindowInsets(aliceInsetRoot);\
            if (insets != null) {\
                navigationHeight =\
                        Math.round(\
                                insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom\
                                        * scale);\
            }\
            navigationHeight = Math.min(navigationHeight, thumbnail.getHeight());\
\
            int toolbarHeight =\
                    Math.max(1, Math.round(toolbarBitmap.getHeight() * scale));\
            boolean toolbarOnBottom = false;\
            if (mBrowserControlsStateProvider != null) {\
                toolbarOnBottom =\
                        mBrowserControlsStateProvider.getControlsPosition()\
                                == BrowserControlsStateProvider.ControlsPosition.BOTTOM;\
            }\
            if (!toolbarOnBottom) navigationHeight = 0;\
            int alicePageBottom = thumbnail.getHeight();\
            int contentTop = toolbarOnBottom ? 0 : toolbarHeight;\
            int toolbarTop = toolbarOnBottom ? alicePageBottom : 0;\
            int baseResultHeight =\
                    toolbarOnBottom\
                            ? toolbarTop + toolbarHeight + navigationHeight\
                            : toolbarHeight + thumbnail.getHeight() + navigationHeight;\
\
            Bitmap baseResult =\
                    Bitmap.createBitmap(\
                            thumbnail.getWidth(), baseResultHeight, Bitmap.Config.ARGB_8888);\
            Canvas canvas = new Canvas(baseResult);\
            if (toolbarOnBottom) {\
                Rect alicePageDestination =\
                        new Rect(\
                                0,\
                                0,\
                                thumbnail.getWidth(),\
                                alicePageBottom);\
                Paint alicePagePaint = new Paint(Paint.FILTER_BITMAP_FLAG);\
                canvas.drawBitmap(thumbnail, null, alicePageDestination, alicePagePaint);\
            } else {\
                canvas.drawBitmap(thumbnail, 0, contentTop, null);\
            }\
\
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);\
            Rect destination = new Rect();\
            destination.set(0, toolbarTop, thumbnail.getWidth(), toolbarTop + toolbarHeight);\
            canvas.drawBitmap(toolbarBitmap, null, destination, paint);\
\
            if (navigationHeight > 0) {\
                int navigationColor = 0;\
                if (toolbarView != null\
                        \&\& toolbarView.getBackground()\
                                instanceof android.graphics.drawable.ColorDrawable) {\
                    navigationColor =\
                            ((android.graphics.drawable.ColorDrawable)\
                                            toolbarView.getBackground())\
                                    .getColor();\
                }\
                if (android.graphics.Color.alpha(navigationColor) == 0) {\
                    navigationColor =\
                            toolbarBitmap.getPixel(\
                                    0, Math.max(0, toolbarBitmap.getHeight() - 1));\
                }\
                paint.setColor(navigationColor);\
                canvas.drawRect(\
                        0,\
                        baseResultHeight - navigationHeight,\
                        thumbnail.getWidth(),\
                        baseResultHeight,\
                        paint);\
            }\
            if (!toolbarOnBottom) return baseResult;\
\
            // Stretch the merged page and toolbar downward by 1px.\
            int resultHeight = baseResultHeight + 1;\
            Bitmap result =\
                    Bitmap.createBitmap(\
                            thumbnail.getWidth(), resultHeight, Bitmap.Config.ARGB_8888);\
            result.eraseColor(baseResult.getPixel(0, baseResultHeight - 1));\
            Canvas stretchedCanvas = new Canvas(result);\
            RectF stretchedDestination =\
                    new RectF(\
                            0,\
                            0,\
                            thumbnail.getWidth(),\
                            baseResultHeight + 1.0f);\
            Paint stretchedPaint = new Paint(Paint.FILTER_BITMAP_FLAG);\
            stretchedCanvas.drawBitmap(baseResult, null, stretchedDestination, stretchedPaint);\
            baseResult.recycle();\
            return result;\
        } catch (OutOfMemoryError ex) {\
            return null;\
        }\
    }\
    // Alice patch end 0040\
\
' "$path2"

sed -i '/^        getTabThumbnailFromDisk(tabId, thumbnailSize, callback);$/c\
        // Alice patch start 0040\
        if (mAliceCompositingTabIds.contains(tabId)) {\
            List<AlicePendingThumbnailRequest> requests =\
                    mAlicePendingThumbnailRequests.get(tabId);\
            if (requests == null) {\
                requests = new ArrayList<>();\
                mAlicePendingThumbnailRequests.put(tabId, requests);\
            }\
            requests.add(new AlicePendingThumbnailRequest(thumbnailSize, callback));\
            return;\
        }\
        @Nullable Bitmap recentCompositedThumbnail = mAliceRecentCompositedThumbnail;\
        if (mAliceRecentCompositedTabId == tabId\
                \&\& recentCompositedThumbnail != null\
                \&\& !recentCompositedThumbnail.isRecycled()) {\
            @Nullable Bitmap immediateBitmap =\
                    copyAliceCompositedThumbnail(recentCompositedThumbnail);\
            if (immediateBitmap != null) {\
                callback.onResult(immediateBitmap);\
                return;\
            }\
        }\
        getTabThumbnailFromDisk(tabId, thumbnailSize, callback);\
        // Alice patch end 0040' "$path2"

sed -i '/^    public void destroy() {$/,/^    }$/c\
    // Alice patch start 0040\
    public void destroy() {\
        mAliceCompositingTabIds.clear();\
        mAlicePendingThumbnailRequests.clear();\
        mAliceRecentCompositedTabId = Tab.INVALID_TAB_ID;\
        mAliceRecentCompositedThumbnail = null;\
        if (mAliceLastToolbarBitmap != null) {\
            mAliceLastToolbarBitmap.recycle();\
            mAliceLastToolbarBitmap = null;\
        }\
\
        if (mNativeTabContentManager != 0) {\
            TabContentManagerJni.get().destroy(mNativeTabContentManager);\
            mNativeTabContentManager = 0;\
        }\
    }\
    // Alice patch end 0040' "$path2"

# 4) TabContentManager：网页内容回读完成后合成浏览器界面并刷新缓存
sed -i '/^            Callback<@Nullable Bitmap> wrappedCallback =$/,/^                            wrappedCallback);$/c\
            // Alice patch start 0040\
            if (mAliceRecentCompositedTabId == tab.getId()) {\
                mAliceRecentCompositedTabId = Tab.INVALID_TAB_ID;\
                mAliceRecentCompositedThumbnail = null;\
            }\
            @Nullable View toolbarView = getAliceToolbarView(tab);\
            @Nullable Bitmap toolbarBitmap = captureAliceToolbarBitmap(toolbarView);\
            if (toolbarBitmap != null) rememberAliceToolbarBitmap(toolbarBitmap);\
            final boolean deferCache = toolbarView != null || mAliceLastToolbarBitmap != null;\
            if (deferCache) {\
                mAliceCompositingTabIds.add(tab.getId());\
            }\
            // Alice patch end 0040\
            Callback<@Nullable Bitmap> wrappedCallback =\
                    (@Nullable Bitmap bitmap) -> {\
                        @Nullable Bitmap finalBitmap = bitmap;\
                        // Alice patch start 0040\
                        Bitmap aliceToolbarForComposition = toolbarBitmap;\
                        if (aliceToolbarForComposition == null \&\& toolbarView != null) {\
                            aliceToolbarForComposition = captureAliceToolbarBitmap(toolbarView);\
                            if (aliceToolbarForComposition != null) {\
                                rememberAliceToolbarBitmap(aliceToolbarForComposition);\
                            }\
                        }\
                        if (aliceToolbarForComposition == null\
                                \&\& mAliceLastToolbarBitmap != null\
                                \&\& !mAliceLastToolbarBitmap.isRecycled()) {\
                            aliceToolbarForComposition =\
                                    copyAliceCompositedThumbnail(mAliceLastToolbarBitmap);\
                        }\
                        if (bitmap != null \&\& aliceToolbarForComposition != null) {\
                            @Nullable Bitmap composited =\
                                    addAliceToolbarToThumbnail(\
                                            bitmap, toolbarView, aliceToolbarForComposition);\
                            if (composited != null) {\
                                bitmap.recycle();\
                                finalBitmap = composited;\
                            }\
                        }\
                        if (finalBitmap != null \&\& deferCache) {\
                            TabContentManagerJni.get()\
                                    .cacheTabWithBitmap(\
                                            mNativeTabContentManager,\
                                            tab,\
                                            finalBitmap,\
                                            mThumbnailScale);\
                        }\
                        if (deferCache) finishAliceCompositedThumbnail(tab, finalBitmap);\
                        if (aliceToolbarForComposition != null) {\
                            aliceToolbarForComposition.recycle();\
                        }\
                        // Alice patch end 0040\
                        if (finalBitmap != null) {\
                            long durationMs = SystemClock.elapsedRealtime() - startTime;\
                            RecordHistogram.recordTimesHistogram(\
                                    String.format(\
                                            UMA_THUMBNAIL_CAPTURE_DURATION_FORMAT, "WebContent"),\
                                    durationMs);\
                        }\
                        Callback.runNullSafe(callback, returnBitmap ? finalBitmap : null);\
                        // Alice patch start 0040\
                        if (!returnBitmap \&\& finalBitmap != null) finalBitmap.recycle();\
                        // Alice patch end 0040\
                    };\
            TabContentManagerJni.get()\
                    .captureThumbnail(\
                            mNativeTabContentManager,\
                            tab,\
                            mThumbnailScale,\
                            /* returnBitmap= */ deferCache || returnBitmap,\
                            /* deferCache= */ deferCache,\
                            wrappedCallback);' "$path2"

sed -i '/^        if (!forceRemoval \&\& !mTabWindowManager\.canTabThumbnailBeDeleted(tabId)) {$/,/^        }$/c\
        if (!forceRemoval \&\& !mTabWindowManager.canTabThumbnailBeDeleted(tabId)) {\
            return;\
        }\
        // Alice patch start 0040\
        mAliceCompositingTabIds.remove(tabId);\
        if (mAliceRecentCompositedTabId == tabId) {\
            mAliceRecentCompositedTabId = Tab.INVALID_TAB_ID;\
            mAliceRecentCompositedThumbnail = null;\
        }\
        List<AlicePendingThumbnailRequest> pendingRequests =\
                mAlicePendingThumbnailRequests.remove(tabId);\
        if (pendingRequests != null) {\
            for (AlicePendingThumbnailRequest request : pendingRequests) {\
                Callback.runNullSafe(request.mCallback, null);\
            }\
        }\
        // Alice patch end 0040' "$path2"

# 5) TabContentManager：JNI 捕获接口增加延迟缓存参数
sed -i '/^        void captureThumbnail($/,/^                Callback<@Nullable Bitmap> callback);$/c\
        // Alice patch start 0040\
        void captureThumbnail(\
                long nativeTabContentManager,\
                @JniType("TabAndroid*") Tab tab,\
                float thumbnailScale,\
                boolean returnBitmap,\
                boolean deferCache,\
                Callback<@Nullable Bitmap> callback);\
        // Alice patch end 0040' "$path2"

# 6) TabContentManager：JNI 实现增加延迟缓存参数
sed -i '/^void TabContentManager::CaptureThumbnail($/,/^    const base::android::JavaRef<jobject>& j_callback) {$/c\
  // Alice patch start 0040\
void TabContentManager::CaptureThumbnail(\
    JNIEnv* env,\
    TabAndroid* tab_android,\
    float thumbnail_scale,\
    bool return_bitmap,\
    bool defer_cache,\
    const base::android::JavaRef<jobject>& j_callback) {\
  // Alice patch end 0040' "$path3"

sed -i '/^  TabReadbackCallback readback_done_callback =$/,/^                     return_bitmap);$/c\
  // Alice patch start 0040\
  TabReadbackCallback readback_done_callback =\
      base::BindOnce(&TabContentManager::OnTabReadback,\
                     weak_factory_.GetWeakPtr(), tab_id, std::move(tracker),\
                     base::BindOnce(&RunObjectCallbackAndroid,\
                                    ScopedJavaGlobalRef<jobject>(j_callback)),\
                     return_bitmap, defer_cache);\
  // Alice patch end 0040' "$path3"

# 7) 合成后的 Bitmap 可以强制替换刚回读的无工具栏快照
sed -i '/^  \/\/ Native pages have their own throttling behavior so force the update if that$/,/^                  \/\*return_bitmap=\*\/false, thumbnail_scale, skbitmap);$/c\
  // Alice patch start 0040\
  // Deferred snapshots compose the toolbar in Java and must replace the raw\
  // readback in the thumbnail cache.\
  ThumbnailCaptureTrackerPtr deferred_tracker(\
      nullptr,\
      base::OnTaskRunnerDeleter(\
          base::SequencedTaskRunner::GetCurrentDefault()));\
  auto deferred_it = deferred_capture_trackers_.find(tab_id);\
  if (deferred_it != deferred_capture_trackers_.end()) {\
    deferred_tracker = std::move(deferred_it->second);\
    deferred_capture_trackers_.erase(deferred_it);\
  }\
  if (thumbnail_cache_.CheckAndUpdateThumbnailMetaData(tab_id, url,\
                                                       /*force_update=*/true)) {\
    if (!deferred_tracker) {\
      deferred_tracker = TrackCapture(tab_id);\
    }\
    OnTabReadback(tab_id, std::move(deferred_tracker), JavaBitmapCallback(),\
                  /*return_bitmap=*/false,\
                  /*defer_cache=*/false, thumbnail_scale, skbitmap);\
    OnFinishedThumbnailRead(tab_id);\
  } else if (deferred_tracker) {\
    deferred_tracker->MarkCaptureFailed();\
  // Alice patch end 0040' "$path3"

# 8) 延迟缓存时保留完整分辨率，并交给 Java 合成工具栏
sed -i '/^void TabContentManager::OnTabReadback(int tab_id,$/,/^                                      const SkBitmap& bitmap) {$/c\
  // Alice patch start 0040\
void TabContentManager::OnTabReadback(\
                                      int tab_id,\
                                      ThumbnailCaptureTrackerPtr tracker,\
                                      JavaBitmapCallback callback,\
                                      bool return_bitmap,\
                                      bool defer_cache,\
                                      float thumbnail_scale,\
                                      const SkBitmap& bitmap) {\
  // Alice patch end 0040' "$path3"

sed -i '/^  SendThumbnailToJava(std::move(callback), \/\*need_downsampling=\*\/true,$/,/^                      return_bitmap, bitmap);$/c\
  // Alice patch start 0040\
  if (defer_cache) {\
    if (tracker) {\
      if (bitmap.empty()) {\
        tracker->MarkCaptureFailed();\
      } else {\
        deferred_capture_trackers_.insert_or_assign(tab_id, std::move(tracker));\
      }\
    }\
  }\
\
  SendThumbnailToJava(std::move(callback), /*need_downsampling=*/!defer_cache,\
                      return_bitmap, bitmap);\
\
  if (defer_cache) return;\
  // Alice patch end 0040' "$path3"

# 9) 同步更新 C++ 头文件声明
sed -i '/^  void CaptureThumbnail(JNIEnv\* env,$/,/^                        const base::android::JavaRef<jobject>& j_callback);$/c\
  // Alice patch start 0040\
  void CaptureThumbnail(JNIEnv* env,\
                        TabAndroid* tab_android,\
                        float thumbnail_scale,\
                        bool return_bitmap,\
                        bool defer_cache,\
                        const base::android::JavaRef<jobject>& j_callback);\
  // Alice patch end 0040' "$path4"

sed -i '/^  void OnTabReadback(int tab_id,$/,/^                     const SkBitmap& bitmap);$/c\
  // Alice patch start 0040\
  void OnTabReadback(int tab_id,\
                     ThumbnailCaptureTrackerPtr tracker,\
                     JavaBitmapCallback callback,\
                     bool return_bitmap,\
                     bool defer_cache,\
                     float thumbnail_scale,\
                     const SkBitmap& bitmap);\
  absl::flat_hash_map<thumbnail::TabId, ThumbnailCaptureTrackerPtr>\
      deferred_capture_trackers_;\
  // Alice patch end 0040' "$path4"

# 10) 工具栏已经包含在快照中，不再创建会遮挡它的底部纯色动画
sed -i '/^        int aliceToolbarHeight = toolbarView == null ? 0 : toolbarView.getHeight();$/,/^                                : Math.max(0, bottomControlsHeight - bottomMargin);$/c\
        // Alice patch start 0040\
        boolean aliceUseBottomToolbarGeometry =\
                toolbarView != null \&\& !animationData.isTopToolbar();\
        int animatingHeight =\
                mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB\
                                || animationData.isTopToolbar()\
                        ? 0\
                        : aliceUseBottomToolbarGeometry\
                                ? 0\
                                : Math.max(0, bottomControlsHeight - bottomMargin);\
        // Alice patch end 0040' "$path5"

# 11) 缩略图尺寸向下取整，避免底边因非整数缩放而发糊
sed -i '/^        gfx::Size thumbnail_size($/,/^        gfx::ScaleToCeiledSize(view_size_in_pixels, thumbnail_scale_));$/c\
        // Alice patch start 0040\
        gfx::Size thumbnail_size(\
            gfx::ScaleToFlooredSize(view_size_in_pixels, thumbnail_scale_));\
        // Alice patch end 0040' "$path3"

# 12) 不降采样时直接桥接原始 Bitmap，避免同尺寸 Resize 把网页底边重采样发糊
sed -i '/^    SkIRect dest_subset = {0, 0, width, height};$/,/^        dest_subset));$/c\
    // Alice patch start 0040\
    bool needs_resize = width != bitmap.width() || height != bitmap.height();\
    if (!needs_resize) {\
      j_bitmap = gfx::ConvertToJavaBitmap(bitmap);\
    } else {\
      SkIRect dest_subset = {0, 0, width, height};\
      j_bitmap = gfx::ConvertToJavaBitmap(skia::ImageOperations::Resize(\
          bitmap, skia::ImageOperations::RESIZE_BETTER, width, height,\
          dest_subset));\
    }\
    // Alice patch end 0040' "$path3"

# 13) 删除标签时同时清理等待 Java 合成的 capture tracker
sed -i '/^  in_flight_captures_\.erase(tab_id);$/a\
  // Alice patch start 0040\
  deferred_capture_trackers_.erase(tab_id);\
  // Alice patch end 0040' "$path3"

# 14) 工具栏横滑切换前缓存当前网页标签，避免离开后缩略图仍为空
sed -i '/^        if (tab != null \&\& tab\.isNativePage\(\)) {$/,/^        }$/c\
        // Alice patch start 0040\
        if (tab != null) {\
            assumeNonNull(mTabContentManager);\
            mTabContentManager.cacheTabThumbnail(tab);\
        }\
        // Alice patch end 0040' "$path6"
