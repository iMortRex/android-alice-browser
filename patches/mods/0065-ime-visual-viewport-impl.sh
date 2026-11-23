#!/bin/bash
# IME viewport 实现层：Java/Content API 和渲染器实时几何同步。

set -e

path1="content/public/android/java/src/org/chromium/content/browser/webcontents/WebContentsImpl.java"
path2="content/browser/web_contents/web_contents_android.h"
path3="content/browser/web_contents/web_contents_android.cc"
path4="content/public/android/java/src/org/chromium/content_public/browser/WebContents.java"

# 检测是否已应用
if grep -q 'Alice patch start 0065' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    void scrollFocusedEditableNodeIntoView();$/a\
    // Alice patch start 0065\
    /** Synchronizes the Blink IME viewport visual lift. */\
    default void syncImeViewportLift(\
            float imeHeight, float bottomChromeHeight) {}\
\
    /** Sets a callback invoked when the focused editable node requests viewport updates. */\
    default void setImeViewportFocusCallback(@Nullable Runnable callback) {}\
\
    /** Requests an IME viewport recalculation. */\
    default void requestImeViewportUpdate() {}\
    // Alice patch end 0065' "$path4"

sed -i '/^    private @Nullable SmartClipCallback mSmartClipCallback;$/a\
\
    // Alice patch start 0065\
    private @Nullable Runnable mImeViewportFocusCallback;\
    // Alice patch end 0065' "$path1"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/,/^    }$/{/^    }$/a\
\
    // Alice patch start 0065\
    @Override\
    public void syncImeViewportLift(\
            float imeHeight, float bottomChromeHeight) {\
        checkNotDestroyed();\
        WebContentsImplJni.get()\
                .syncImeViewportLift(\
                        mNativeWebContentsAndroid,\
                        imeHeight,\
                        bottomChromeHeight);\
    }\
\
    @Override\
    public void setImeViewportFocusCallback(@Nullable Runnable callback) {\
        mImeViewportFocusCallback = callback;\
    }\
\
    @Override\
    public void requestImeViewportUpdate() {\
        if (mImeViewportFocusCallback != null) mImeViewportFocusCallback.run();\
    }\
    // Alice patch end 0065
;}' "$path1"

sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/a\
        // Alice patch start 0065\
        if (mImeViewportFocusCallback != null) mImeViewportFocusCallback.run();\
        // Alice patch end 0065' "$path1"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^        void scrollFocusedEditableNodeIntoView(long nativeWebContentsAndroid);$/a\
\
        // Alice patch start 0065\
        void syncImeViewportLift(\
                long nativeWebContentsAndroid,\
                float imeHeight,\
                float bottomChromeHeight);\
        // Alice patch end 0065' "$path1"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  void ScrollFocusedEditableNodeIntoView(JNIEnv\* env);$/a\
  // Alice patch start 0065\
  void SyncImeViewportLift(JNIEnv* env,\
                           jfloat ime_height,\
                           jfloat bottom_chrome_height);\
  // Alice patch end 0065' "$path2"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void WebContentsAndroid::ScrollFocusedEditableNodeIntoView(JNIEnv\* env) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void WebContentsAndroid::SyncImeViewportLift(JNIEnv* env,\
                                             jfloat ime_height,\
                                             jfloat bottom_chrome_height) {\
  RenderFrameHost* focused_frame = web_contents_->GetFocusedFrame();\
  if (!focused_frame) {\
    return;\
  }\
  auto* render_widget_host =\
      static_cast<RenderWidgetHostImpl*>(focused_frame->GetRenderWidgetHost());\
  if (render_widget_host) {\
    auto\& frame_widget = render_widget_host->GetAssociatedFrameWidget();\
    if (frame_widget) {\
      frame_widget->SyncImeViewportLift(\
          ime_height, bottom_chrome_height);\
    }\
  }\
}\
// Alice patch end 0065
;}' "$path3"

sed -i '/^#include "content\/browser\/renderer_host\/render_view_host_impl.h"$/i\
// Alice patch start 0065\
#include "content/browser/renderer_host/render_frame_host_impl.h"\
// Alice patch end 0065' "$path3"

sed -i '/^#include "content\/browser\/renderer_host\/render_view_host_impl.h"$/a\
// Alice patch start 0065\
#include "content/browser/renderer_host/render_widget_host_impl.h"\
// Alice patch end 0065' "$path3"
