#!/bin/bash
# 标签预览：在网页快照中合成底部工具栏和系统导航栏区域。

set -e

path1="chrome/browser/tab_ui/android/java/src/org/chromium/chrome/browser/tab_ui/TabContentManager.java"
path2="chrome/browser/android/compositor/tab_content_manager.cc"
path3="chrome/browser/android/compositor/tab_content_manager.h"

# 检测是否已应用
if grep -q 'Alice patch start 0040' "$path1"; then
    exit 100
fi

# 补充工具栏合成所需的 Android import。
# 导入 Activity，用于从 Context 定位当前浏览器窗口。
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0040\
import android.app.Activity;\
// Alice patch end 0040' "$path1"

# 导入绘图、区域和按压态处理类型。
sed -i '/^import android\.graphics\.Matrix;$/a\
// Alice patch start 0040\
import android.graphics.Paint;\
import android.graphics.Rect;\
import android.graphics.drawable.RippleDrawable;\
// Alice patch end 0040' "$path1"

# 导入 ViewGroup，用于递归遍历工具栏视图树。
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0040\
import android.view.ViewGroup;\
// Alice patch end 0040' "$path1"

# 导入窗口 inset 兼容接口，用于同步导航栏高度。
sed -i '/^import androidx\.annotation\.VisibleForTesting;$/a\
// Alice patch start 0040\
import androidx.core.view.ViewCompat;\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0040' "$path1"

# 导入 ContextUtils，用于从上下文获取 Activity。
sed -i '/^import org\.chromium\.base\.CommandLine;$/a\
// Alice patch start 0040\
import org.chromium.base.ContextUtils;\
// Alice patch end 0040' "$path1"

# 导入 ViewUtils，用于离屏捕获工具栏视图。
sed -i '/^import org\.chromium\.ui\.base\.DeviceFormFactor;$/a\
// Alice patch start 0040\
import org.chromium.ui.base.ViewUtils;\
// Alice patch end 0040' "$path1"

# 导入集合类型，用于跟踪合成状态和等待中的请求。
sed -i '/^import java\.util\.List;$/a\
// Alice patch start 0040\
import java.util.HashMap;\
import java.util.HashSet;\
import java.util.Map;\
import java.util.Set;\
// Alice patch end 0040' "$path1"

# 导入有界缓存，用于按标签页保存最近合成结果。
sed -i '/^import android\.util\.Size;$/i\
// Alice patch start 0040\
import android.util.LruCache;\
// Alice patch end 0040' "$path1"

# 声明工具栏预览的垂直拉伸常量。
sed -i '/^    private final ArrayList<ThumbnailChangeListener> mListeners = new ArrayList<>();$/i\
    // Alice patch start 0040\
    public static final float ALICE_TOOLBAR_SWIPE_VERTICAL_STRETCH_PX = 8.0f;\
    // Alice patch end 0040\
' "$path1"

# 增加合成中的标签、待处理请求和最近快照缓存字段。
sed -i '/^    private final ArrayList<ThumbnailChangeListener> mListeners = new ArrayList<>();$/a\
    // Alice patch start 0040\
    private final Set<Integer> mAliceCompositingTabIds = new HashSet<>();\
    private final Map<Integer, List<AlicePendingThumbnailRequest>>\
            mAlicePendingThumbnailRequests = new HashMap<>();\
    private static final int ALICE_COMPOSITED_THUMBNAIL_CACHE_SIZE = 8;\
    private final LruCache<Integer, Bitmap> mAliceCompositedThumbnails =\
            new LruCache<>(ALICE_COMPOSITED_THUMBNAIL_CACHE_SIZE) {\
                @Override\
                protected void entryRemoved(\
                        boolean evicted,\
                        Integer key,\
                        Bitmap oldValue,\
                        @Nullable Bitmap newValue) {\
                    if (!oldValue.isRecycled()) oldValue.recycle();\
                }\
            };\
    private @Nullable Bitmap mAliceLastToolbarBitmap;\
    // Alice patch end 0040' "$path1"

# 注入工具栏查找、捕获、合成和异步回读辅助方法。
sed -i '/^    private @Nullable Bitmap cacheNativeTabThumbnail(/i\
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
            mAliceCompositedThumbnails.put(tabId, immediateBitmap);\
        }\
        if (requests == null || requests.isEmpty()) return;\
        for (AlicePendingThumbnailRequest request : requests) {\
            if (immediateBitmap == null) {\
                getTabThumbnailFromDisk(\
                        tabId, request.mThumbnailSize, request.mCallback);\
            } else {\
                @Nullable Bitmap callbackBitmap =\
                        copyAliceCompositedThumbnail(immediateBitmap);\
                if (callbackBitmap == null) {\
                    getTabThumbnailFromDisk(\
                            tabId, request.mThumbnailSize, request.mCallback);\
                } else {\
                    Callback.runNullSafe(request.mCallback, callbackBitmap);\
                }\
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
    private boolean isAliceHorizontalTabSwitcher() {\
        int style =\
                ContextUtils.getAppSharedPreferences()\
                        .getInt("alice_tab_switcher_style", 3);\
        return style == 2 || style == 3;\
    }\
\
    private boolean shouldCaptureAliceToolbar() {\
        return mBrowserControlsStateProvider != null\
                \&\& mBrowserControlsStateProvider.getControlsPosition()\
                        == BrowserControlsStateProvider.ControlsPosition.BOTTOM;\
    }\
\
    private @Nullable View getAliceToolbarView(Tab tab) {\
        if (!shouldCaptureAliceToolbar()) return null;\
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
            int resultHeight =\
                    toolbarOnBottom\
                            ? toolbarTop + toolbarHeight + navigationHeight\
                            : toolbarHeight + alicePageBottom;\
\
            int navigationColor = 0;\
            if (toolbarOnBottom \&\& navigationHeight > 0) {\
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
            }\
\
            Bitmap result =\
                    Bitmap.createBitmap(\
                            thumbnail.getWidth(), resultHeight, Bitmap.Config.ARGB_8888);\
            result.eraseColor(\
                    toolbarOnBottom \&\& navigationHeight > 0\
                            ? navigationColor\
                            : toolbarBitmap.getPixel(\
                                    0, Math.max(0, toolbarBitmap.getHeight() - 1)));\
            Canvas canvas = new Canvas(result);\
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);\
            canvas.drawBitmap(thumbnail, 0, contentTop, paint);\
            Rect destination = new Rect();\
            destination.set(0, toolbarTop, thumbnail.getWidth(), toolbarTop + toolbarHeight);\
            canvas.drawBitmap(toolbarBitmap, null, destination, paint);\
\
            if (navigationHeight > 0) {\
                paint.setColor(navigationColor);\
                canvas.drawRect(\
                        0,\
                        resultHeight - navigationHeight,\
                        thumbnail.getWidth(),\
                        resultHeight,\
                        paint);\
            }\
            return result;\
        } catch (OutOfMemoryError ex) {\
            return null;\
        }\
    }\
    // Alice patch end 0040\
\
' "$path1"

# 底置工具栏动画优先使用带工具栏的合成缩略图，避免退回旧的 ETC1。
sed -i '/^    public void getEtc1TabThumbnailWithCallback(int tabId, Callback<@Nullable Bitmap> callback) {$/,/^    }$/c\
    public void getEtc1TabThumbnailWithCallback(int tabId, Callback<@Nullable Bitmap> callback) {\
        if (!mSnapshotsEnabled || mNativeTabContentManager == 0) {\
            callback.onResult(null);\
            return;\
        }\
\
        // Alice patch start 0040\
        @Nullable Bitmap compositedThumbnail = mAliceCompositedThumbnails.get(tabId);\
        if (compositedThumbnail != null \&\& !compositedThumbnail.isRecycled()) {\
            @Nullable Bitmap immediateBitmap = copyAliceCompositedThumbnail(compositedThumbnail);\
            if (immediateBitmap != null) {\
                callback.onResult(immediateBitmap);\
                return;\
            }\
        }\
        if (shouldCaptureAliceToolbar()) {\
            getTabThumbnailWithCallback(\
                    tabId,\
                    new Size(0, 0),\
                    (bitmap) -> {\
                        if (bitmap != null) {\
                            callback.onResult(bitmap);\
                            return;\
                        }\
                        TabContentManagerJni.get()\
                                .getEtc1TabThumbnail(\
                                        mNativeTabContentManager, tabId, callback);\
                    });\
            return;\
        }\
        // Alice patch end 0040\
\
        // Do not capture a JPEG here because we likely already created one when capturing. We just\
        // want to fetch the ETC1 off of disk for a higher resolution image to use for animations.\
        TabContentManagerJni.get().getEtc1TabThumbnail(mNativeTabContentManager, tabId, callback);\
    }' "$path1"

# 拦截缩略图读取：合成期间排队请求，优先返回最近合成结果。
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
        @Nullable Bitmap compositedThumbnail = mAliceCompositedThumbnails.get(tabId);\
        if (compositedThumbnail != null \&\& !compositedThumbnail.isRecycled()) {\
            @Nullable Bitmap immediateBitmap = copyAliceCompositedThumbnail(compositedThumbnail);\
            if (immediateBitmap != null) {\
                callback.onResult(immediateBitmap);\
                return;\
            }\
        }\
        getTabThumbnailFromDisk(tabId, thumbnailSize, callback);\
        // Alice patch end 0040' "$path1"

# 销毁时清理合成状态、缓存位图和等待中的请求。
sed -i '/^    public void destroy() {$/,/^    }$/c\
    // Alice patch start 0040\
    public void destroy() {\
        mAliceCompositingTabIds.clear();\
        mAlicePendingThumbnailRequests.clear();\
        mAliceCompositedThumbnails.evictAll();\
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
    // Alice patch end 0040' "$path1"

# 网页内容回读完成后合成工具栏并刷新缩略图缓存。
sed -i '/^            Callback<@Nullable Bitmap> wrappedCallback =$/,/^                            wrappedCallback);$/c\
            // Alice patch start 0040\
            if (!shouldCaptureAliceToolbar() \&\& mAliceLastToolbarBitmap != null) {\
                mAliceLastToolbarBitmap.recycle();\
                mAliceLastToolbarBitmap = null;\
            }\
            final boolean aliceCaptureToolbarForTab =\
                    shouldCaptureAliceToolbar()\
                            \&\& !tab.isLoading()\
                            \&\& (!tab.isHidden()\
                                    ? tab.isUserInteractable()\
                                    : isAliceHorizontalTabSwitcher());\
            @Nullable View toolbarView =\
                    aliceCaptureToolbarForTab ? getAliceToolbarView(tab) : null;\
            @Nullable Bitmap toolbarBitmap =\
                    aliceCaptureToolbarForTab ? captureAliceToolbarBitmap(toolbarView) : null;\
            if (toolbarBitmap != null) rememberAliceToolbarBitmap(toolbarBitmap);\
            final boolean deferCache =\
                    toolbarView != null\
                            || (aliceCaptureToolbarForTab \&\& mAliceLastToolbarBitmap != null);\
            if (deferCache) {\
                mAliceCompositingTabIds.add(tab.getId());\
            }\
            // Alice patch end 0040\
            Callback<@Nullable Bitmap> wrappedCallback =\
                    (@Nullable Bitmap bitmap) -> {\
                        @Nullable Bitmap finalBitmap = bitmap;\
                        // Alice patch start 0040\
                        boolean aliceCaptureToolbar =\
                                aliceCaptureToolbarForTab \&\& shouldCaptureAliceToolbar();\
                        Bitmap aliceToolbarForComposition =\
                                aliceCaptureToolbar ? toolbarBitmap : null;\
                        if (!aliceCaptureToolbar \&\& toolbarBitmap != null) {\
                            toolbarBitmap.recycle();\
                        }\
                        if (aliceToolbarForComposition == null\
                                \&\& aliceCaptureToolbar\
                                \&\& toolbarView != null) {\
                            aliceToolbarForComposition = captureAliceToolbarBitmap(toolbarView);\
                            if (aliceToolbarForComposition != null) {\
                                rememberAliceToolbarBitmap(aliceToolbarForComposition);\
                            }\
                        }\
                        if (aliceToolbarForComposition == null\
                                \&\& aliceCaptureToolbar\
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
                            wrappedCallback);' "$path1"

# 删除缩略图时同步移除该标签的合成状态和等待请求。
sed -i '/^        if (!forceRemoval \&\& !mTabWindowManager\.canTabThumbnailBeDeleted(tabId)) {$/,/^        }$/c\
        if (!forceRemoval \&\& !mTabWindowManager.canTabThumbnailBeDeleted(tabId)) {\
            return;\
        }\
        // Alice patch start 0040\
        mAliceCompositingTabIds.remove(tabId);\
        mAliceCompositedThumbnails.remove(tabId);\
        List<AlicePendingThumbnailRequest> pendingRequests =\
                mAlicePendingThumbnailRequests.remove(tabId);\
        if (pendingRequests != null) {\
            for (AlicePendingThumbnailRequest request : pendingRequests) {\
                Callback.runNullSafe(request.mCallback, null);\
            }\
        }\
        // Alice patch end 0040' "$path1"

# 为 JNI 捕获接口增加延迟缓存参数。
sed -i '/^        void captureThumbnail($/,/^                Callback<@Nullable Bitmap> callback);$/c\
        // Alice patch start 0040\
        void captureThumbnail(\
                long nativeTabContentManager,\
                @JniType("TabAndroid*") Tab tab,\
                float thumbnailScale,\
                boolean returnBitmap,\
                boolean deferCache,\
                Callback<@Nullable Bitmap> callback);\
        // Alice patch end 0040' "$path1"

# 同步 C++ 捕获接口签名。
sed -i '/^void TabContentManager::CaptureThumbnail($/,/^    const base::android::JavaRef<jobject>& j_callback) {$/c\
  // Alice patch start 0040\
void TabContentManager::CaptureThumbnail(\
    JNIEnv* env,\
    TabAndroid* tab_android,\
    float thumbnail_scale,\
    bool return_bitmap,\
    bool defer_cache,\
    const base::android::JavaRef<jobject>& j_callback) {\
  // Alice patch end 0040' "$path2"

# 将延迟缓存参数绑定到网页内容回读完成回调。
sed -i '/^  TabReadbackCallback readback_done_callback =$/,/^                     return_bitmap);$/c\
  // Alice patch start 0040\
  TabReadbackCallback readback_done_callback =\
      base::BindOnce(&TabContentManager::OnTabReadback,\
                     weak_factory_.GetWeakPtr(), tab_id, std::move(tracker),\
                     base::BindOnce(&RunObjectCallbackAndroid,\
                                    ScopedJavaGlobalRef<jobject>(j_callback)),\
                     return_bitmap, defer_cache);\
  // Alice patch end 0040' "$path2"

# 合成后的 Bitmap 强制替换未带工具栏的原始回读快照。
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
  // Alice patch end 0040' "$path2"

# 延迟缓存时保留完整分辨率，并交给 Java 合成工具栏。
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
  // Alice patch end 0040' "$path2"

# 延迟缓存时保存 capture tracker，并让 Java 合成后写入缩略图缓存。
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
  // Alice patch end 0040' "$path2"

# 同步 C++ 头文件中的 CaptureThumbnail 声明。
sed -i '/^  void CaptureThumbnail(JNIEnv\* env,$/,/^                        const base::android::JavaRef<jobject>& j_callback);$/c\
  // Alice patch start 0040\
  void CaptureThumbnail(JNIEnv* env,\
                        TabAndroid* tab_android,\
                        float thumbnail_scale,\
                        bool return_bitmap,\
                        bool defer_cache,\
                        const base::android::JavaRef<jobject>& j_callback);\
  // Alice patch end 0040' "$path3"

# 同步 C++ 头文件中的 OnTabReadback 声明和延迟 tracker 字段。
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
  // Alice patch end 0040' "$path3"

# 导入四舍五入函数，用于按整数目标宽度计算缩略图尺寸。
sed -i '/^#include <cstdint>$/i\
// Alice patch start 0040\
#include <cmath>\
// Alice patch end 0040' "$path2"

# 用整数目标宽度的实际比例计算缩略图宽高，统一网页和工具栏缩放基准。
sed -i '/^    gfx::Size thumbnail_size($/,/^        gfx::ScaleToCeiledSize(view_size_in_pixels, thumbnail_scale_));$/c\
        // Alice patch start 0040\
        const int thumbnail_width =\
            std::lround(view_size_in_pixels.width() * thumbnail_scale_);\
        const float aligned_scale =\
            static_cast<float>(thumbnail_width) / view_size_in_pixels.width();\
        const int thumbnail_height =\
            std::lround(view_size_in_pixels.height() * aligned_scale);\
        gfx::Size thumbnail_size(thumbnail_width, thumbnail_height);\
        // Alice patch end 0040' "$path2"

# 不降采样时直接桥接原始 Bitmap，避免同尺寸 Resize 让网页底边发糊。
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
    // Alice patch end 0040' "$path2"

# 删除标签时清理等待 Java 合成的 capture tracker。
sed -i '/^  in_flight_captures_\.erase(tab_id);$/a\
  // Alice patch start 0040\
  deferred_capture_trackers_.erase(tab_id);\
  // Alice patch end 0040' "$path2"
