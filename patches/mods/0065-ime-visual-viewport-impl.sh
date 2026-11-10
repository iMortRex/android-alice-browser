#!/bin/bash
# IME visual viewport 实现层：Java/Content API、compositor offset 和 Blink visual viewport。

set -e

path1="content/public/android/java/src/org/chromium/content/browser/webcontents/WebContentsImpl.java"
path2="content/browser/web_contents/web_contents_android.h"
path3="content/browser/web_contents/web_contents_android.cc"
path4="content/public/android/java/src/org/chromium/content_public/browser/WebContents.java"
path5="cc/trees/layer_tree_host_impl.h"
path6="cc/trees/layer_tree_host_impl.cc"
path7="ui/android/delegated_frame_host_android.h"
path8="content/browser/renderer_host/render_widget_host_view_android.h"
path9="content/browser/renderer_host/render_widget_host_view_android.cc"
path10="third_party/blink/renderer/core/exported/web_view_impl.cc"
path11="third_party/blink/renderer/core/frame/visual_viewport.h"
path12="third_party/blink/renderer/core/frame/visual_viewport.cc"
path13="cc/layers/viewport.h"
path14="cc/layers/viewport.cc"
path15="content/public/android/java/src/org/chromium/content_public/browser/ImeAdapter.java"
path16="content/public/android/java/src/org/chromium/content/browser/input/ImeAdapterImpl.java"

# 检测是否已应用
if grep -q 'Alice patch start 0065' "$path1"; then
    exit 100
fi

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    void scrollFocusedEditableNodeIntoView();$/a\
    // Alice patch start 0065\
    /** Sets the Blink visual viewport IME translation in device-independent pixels. */\
    default void setImeViewportTranslation(float translationY) {}\
    // Alice patch end 0065' "$path4"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/,/^    }$/{/^    }$/a\
\
    // Alice patch start 0065\
    @Override\
    public void setImeViewportTranslation(float translationY) {\
        checkNotDestroyed();\
        WebContentsImplJni.get()\
                .setImeViewportTranslation(\
                        mNativeWebContentsAndroid, translationY);\
    }\
    // Alice patch end 0065
;}' "$path1"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^        void scrollFocusedEditableNodeIntoView(long nativeWebContentsAndroid);$/a\
\
        // Alice patch start 0065\
        void setImeViewportTranslation(\
                long nativeWebContentsAndroid, float translationY);\
        // Alice patch end 0065' "$path1"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  void ScrollFocusedEditableNodeIntoView(JNIEnv\* env);$/a\
  // Alice patch start 0065\
  void SetImeViewportTranslation(JNIEnv* env, jfloat translation_y);\
  // Alice patch end 0065' "$path2"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void WebContentsAndroid::ScrollFocusedEditableNodeIntoView(JNIEnv\* env) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void WebContentsAndroid::SetImeViewportTranslation(JNIEnv* env,\
                                                   jfloat translation_y) {\
  auto* input_handler = web_contents_->GetFocusedFrameWidgetInputHandler();\
  if (input_handler)\
    input_handler->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0065
;}' "$path3"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^#include "content\/browser\/renderer_host\/render_view_host_impl.h"$/a\
// Alice patch start 0065\
#include "content/browser/renderer_host/render_widget_host_impl.h"\
// Alice patch end 0065' "$path3"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  const gfx::Transform& DrawTransform() const;$/a\
  // Alice patch start 0065\
  void SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0065' "$path5"
# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  gfx::Rect viewport_rect_for_tile_priority_;$/a\
  // Alice patch start 0065\
  float ime_viewport_translation_ = 0.f;\
  // Alice patch end 0065' "$path5"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^const gfx::Transform& LayerTreeHostImpl::DrawTransform() const {$/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void LayerTreeHostImpl::SetImeViewportTranslation(float translation_y) {\
  ime_viewport_translation_ = translation_y;\
  viewport().SetInnerViewportOffsetUnclamped(translation_y);\
  SetFullViewportDamage();\
  SetNeedsRedraw(/*animation_only=*/false,\
                 /*skip_if_inside_draw=*/false);\
  SetNeedsOneBeginImplFrame();\
}\
// Alice patch end 0065
;}' "$path6"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  active_tree_->DidBecomeActive();$/i\
  // Alice patch start 0065\
  // Reapply the IME viewport offset after tree activation.\
  if (ime_viewport_translation_ != 0.f) {\
    viewport().SetInnerViewportOffsetUnclamped(ime_viewport_translation_);\
  }\
  // Alice patch end 0065' "$path6"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  mutator_host_->TickWorkletAnimations();$/a\
\
  // Alice patch start 0065\
  // Reapply the compositor-only IME offset before draw-property updates.\
  if (ime_viewport_translation_ != 0.f) {\
    viewport().SetInnerViewportOffsetUnclamped(ime_viewport_translation_);\
    SetFullViewportDamage();\
  }\
  // Alice patch end 0065' "$path6"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  const cc::slim::SurfaceLayer\* content_layer() const {$/,/^  }$/ { /^  }$/a\
  // Alice patch start 0065\
  cc::slim::SurfaceLayer* content_layer() { return content_layer_.get(); }\
  // Alice patch end 0065
; }' "$path7"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  void SetNeedsBeginFrameForFlingProgress();$/a\
  // Alice patch start 0065\
  void SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0065' "$path8"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  float page_scale_;$/a\
  // Alice patch start 0065\
  float ime_viewport_translation_y_ = 0.f;\
  // Alice patch end 0065' "$path8"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    boolean focusedNodeEditable();$/a\
\
    // Alice patch start 0065\
    /** Returns the focused editable node bottom edge in screen pixels, or 0 if unfocused. */\
    int getFocusedNodeBottomPx();\
    // Alice patch end 0065' "$path15"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    private boolean mNodePassword;$/a\
    // Alice patch start 0065\
    private boolean mFocusedNodeEditable;\
    private int mFocusedNodeBottomPx;\
    // Alice patch end 0065' "$path16"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^        if (DEBUG_LOGS) Log.i(TAG, "focusedNodeChanged: isEditable \[%b\]", isEditable);$/a\
        // Alice patch start 0065\
        mFocusedNodeEditable = isEditable;\
        mFocusedNodeBottomPx =\
                isEditable\
                        ? Math.round(\
                                nodeBottomDip\
                                        * mWebContents\
                                                .getRenderCoordinates()\
                                                .getDeviceScaleFactor())\
                        : 0;\
        // Alice patch end 0065' "$path16"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    \/\*package\*\/ void focusedNodeChanged($/,/^    }$/ { /^    }$/a\
\
    // Alice patch start 0065\
    @Override\
    public int getFocusedNodeBottomPx() {\
        return mFocusedNodeEditable ? mFocusedNodeBottomPx : 0;\
    }\
    // Alice patch end 0065
; }' "$path16"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void RenderWidgetHostViewAndroid::SetNeedsBeginFrameForFlingProgress() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void RenderWidgetHostViewAndroid::SetImeViewportTranslation(\
    float translation_y) {\
  SetImeViewportTouchTranslation(translation_y);\
  if (!delegated_frame_host_)\
    return;\
  auto* layer = delegated_frame_host_->content_layer();\
  if (layer) {\
    layer->SetTransform(gfx::Transform::MakeTranslation(0, -translation_y));\
    SetNeedsAnimate();\
  }\
}\
// Alice patch end 0065
;}' "$path9"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  void SetImeViewportTranslation(float translation_y);$/a\
  // Alice patch start 0065\
  void SetImeViewportTouchTranslation(float translation_y);\
  // Alice patch end 0065' "$path8"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void RenderWidgetHostViewAndroid::SetImeViewportTranslation($/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void RenderWidgetHostViewAndroid::SetImeViewportTouchTranslation(\
    float translation_y) {\
  const float scale = GetDeviceScaleFactor();\
  ime_viewport_translation_y_ =\
      scale > 0.f ? translation_y / scale : translation_y;\
}\
// Alice patch end 0065
;}' "$path9"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void WebContentsAndroid::SetImeViewportTranslation(JNIEnv\* env,$/,/^}$/{/^  auto\* input_handler = web_contents_->GetFocusedFrameWidgetInputHandler();$/i\
  // Alice patch start 0065\
  if (auto* rwhva = GetRenderWidgetHostViewAndroid())\
    rwhva->SetImeViewportTouchTranslation(translation_y);\
  // Alice patch end 0065
;}' "$path3"

# 只在 OnTouchEvent 内保存原始事件，并让后续逻辑使用调整后的 event。
sed -i '/^bool RenderWidgetHostViewAndroid::OnTouchEvent($/,/^    const ui::MotionEventAndroid\& event) {$/c\
bool RenderWidgetHostViewAndroid::OnTouchEvent(\
    const ui::MotionEventAndroid\& original_event) {\
  // Alice patch start 0065\
  std::unique_ptr<ui::MotionEventAndroid> adjusted_event;\
  if (ime_viewport_translation_y_ != 0.f) {\
    adjusted_event = original_event.CreateFor(\
        gfx::PointF(original_event.GetX(0),\
                    original_event.GetY(0) + ime_viewport_translation_y_));\
  }\
  const ui::MotionEventAndroid\& event =\
      adjusted_event ? *adjusted_event : original_event;\
  // Alice patch end 0065' "$path9"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^#include "ui\/gfx\/geometry\/size_conversions.h"$/a\
// Alice patch start 0065\
#include "ui/gfx/geometry/transform.h"\
// Alice patch end 0065' "$path9"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    void scrollFocusedEditableNodeIntoView();$/a\
    // Alice patch start 0065\
    /** Scrolls the focused editable node for an IME animation frame. */\
    default void scrollFocusedEditableNodeIntoViewForIme() {}\
    // Alice patch end 0065' "$path4"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/,/^    }$/{/^    }$/a\
\
    // Alice patch start 0065\
    @Override\
    public void scrollFocusedEditableNodeIntoViewForIme() {\
        checkNotDestroyed();\
        WebContentsImplJni.get().scrollFocusedEditableNodeIntoView(\
                mNativeWebContentsAndroid);\
    }\
    // Alice patch end 0065
;}' "$path1"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^static constexpr base::TimeDelta kScrollAndScaleAnimationDuration =$/,/^    base::Milliseconds(200);$/c\
// Alice patch start 0065\
// Focus scrolling is driven by Android IME visual viewport animation.\
// Alice patch end 0065' "$path10"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  if (need_animation) {$/,/^  }$/c\
  if (need_animation) {\
    // Alice patch start 0065\
    // Android IME animation owns focused-editable positioning.\
    // Alice patch end 0065\
  }' "$path10"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  void SetLocation($/,/^      mojom::blink::ScrollType = mojom::blink::ScrollType::kProgrammatic);$/ { /^      mojom::blink::ScrollType = mojom::blink::ScrollType::kProgrammatic);$/a\
  // Alice patch start 0065\
  void SetImeScrollOffset(float offset_y);\
  // Alice patch end 0065
; }' "$path11"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void VisualViewport::SetLocation(const gfx::PointF\& new_location,$/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void VisualViewport::SetImeScrollOffset(float offset_y) {\
  if (!IsActiveViewport() || !std::isfinite(offset_y)) {\
    return;\
  }\
\
  ScrollOffset new_offset(0, offset_y);\
  if (new_offset == offset_) {\
    return;\
  }\
\
  DCHECK(LocalMainFrame().View());\
  offset_ = new_offset;\
  GetScrollAnimator().SetCurrentOffset(offset_);\
  if (auto* coordinator = GetPage().GetScrollingCoordinator()) {\
    if (scroll_layer_)\
      coordinator->UpdateCompositorScrollOffset(LocalMainFrame(), *this);\
  }\
  EnqueueScrollEvent();\
  LocalMainFrame().View()->DidChangeScrollOffset(\
      mojom::blink::ScrollType::kProgrammatic);\
  NotifyRootFrameViewport();\
  LocalMainFrame().Loader().SaveScrollState();\
  needs_paint_property_update_ = true;\
  LocalMainFrame().View()->SetVisualViewportOrOverlayNeedsRepaint();\
  ScheduleAnimation();\
}\
// Alice patch end 0065
;}' "$path12"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^  void Pan(const gfx::Vector2dF\& delta);$/a\
\
  // Alice patch start 0065\
  // Sets the inner visual viewport Y offset without applying scroll limits.\
  void SetInnerViewportOffsetUnclamped(float offset_y);\
  // Alice patch end 0065' "$path13"

# 执行对应的 IME visual viewport 源码修改。
sed -i '/^void Viewport::Pan(const gfx::Vector2dF\& delta) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0065\
void Viewport::SetInnerViewportOffsetUnclamped(float offset_y) {\
  ScrollNode* scroll_node = InnerScrollNode();\
  if (!scroll_node)\
    return;\
\
  float page_scale =\
      host_impl_->active_tree()->current_page_scale_factor();\
  if (page_scale <= 0.f)\
    return;\
\
  ScrollTree\& tree = scroll_tree();\
  gfx::PointF new_offset(0.f, offset_y / page_scale);\
  if (tree.SetScrollOffset(scroll_node->element_id, new_offset)) {\
    host_impl_->active_tree()->DidUpdateScrollOffset(\
        scroll_node->element_id,\
        /*pushed_from_main_or_pending_tree=*/false);\
  }\
}\
// Alice patch end 0065
;}' "$path14"
