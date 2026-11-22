#!/bin/bash
# IME visual viewport 接口层：只同步独立视觉 transform，不修改滚动 offset。

set -e

path1="content/public/android/java/src/org/chromium/content/browser/webcontents/WebContentsImpl.java"
path5="third_party/blink/renderer/core/frame/web_frame_widget_impl.h"
path6="third_party/blink/renderer/core/frame/web_frame_widget_impl.cc"
path11="third_party/blink/renderer/core/frame/visual_viewport.h"
path12="third_party/blink/renderer/core/frame/visual_viewport.cc"
path13="third_party/blink/renderer/core/events/web_input_event_conversion.cc"
path14="third_party/blink/renderer/platform/graphics/compositing/paint_artifact_compositor.h"
path15="third_party/blink/renderer/platform/graphics/compositing/paint_artifact_compositor.cc"
path16="third_party/blink/renderer/platform/graphics/compositing/property_tree_manager.h"
path17="third_party/blink/renderer/platform/graphics/compositing/property_tree_manager.cc"
path18="third_party/blink/public/mojom/page/widget.mojom"
path19="content/public/test/fake_frame_widget.h"

# 检测是否已应用
if grep -q 'Alice patch start 0064' "$path1"; then
    exit 100
fi

# 在 ADJUST_NOTHING 模式下拦截原有焦点滚动。
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0064\
import android.app.Activity;\
// Alice patch end 0064' "$path1"

sed -i '/^import android\.view\.ViewStructure;$/a\
// Alice patch start 0064\
import android.view.WindowManager;\
// Alice patch end 0064' "$path1"

sed -i '/^    public void scrollFocusedEditableNodeIntoView() {$/a\
        // Alice patch start 0064\
        WindowAndroid window = getTopLevelNativeWindow();\
        Activity activity = window == null ? null : window.getActivity().get();\
        if (activity != null) {\
            int adjustMode =\
                    activity.getWindow().getAttributes().softInputMode\
                            \& WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST;\
            if (adjustMode == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING) {\
                return;\
            }\
        }\
        // Alice patch end 0064\
' "$path1"

# 从浏览器直接调用 renderer 主线程，避免 compositor input queue 的额外投递。
sed -i '/^  PassImeRenderWidgetHost(pending_remote<ImeRenderWidgetHost> remote);$/a\
\
  // Alice patch start 0064\
  SyncImeViewportLift(float ime_height, float bottom_chrome_height);\
  // Alice patch end 0064' "$path18"

sed -i '/^  void SetBackgroundOpaque(bool value) override {}$/i\
  // Alice patch start 0064\
  void SyncImeViewportLift(float ime_height,\
                           float bottom_chrome_height) override {}\
  // Alice patch end 0064' "$path19"

sed -i '/^  void ScrollFocusedEditableNodeIntoView() override;$/a\
  // Alice patch start 0064\
  void SyncImeViewportLift(float ime_height,\
                           float bottom_chrome_height) override;\
  // Alice patch end 0064' "$path5"

sed -i '/^  std::optional<gfx::Point> host_context_menu_location_;$/a\
  // Alice patch start 0064\
  float ime_viewport_ime_height_ = 0.f;\
  float ime_viewport_bottom_chrome_height_ = 0.f;\
  bool ime_viewport_sync_received_ = false;\
  // Alice patch end 0064' "$path5"

sed -i '/^  View()->UpdatePagePopup();$/a\
\
  // Alice patch start 0064\
  if (ForMainFrame()) {\
    if (ime_viewport_ime_height_ > 0.f \&\& !ime_viewport_sync_received_) {\
      SyncImeViewportLift(\
          ime_viewport_ime_height_, ime_viewport_bottom_chrome_height_);\
    }\
    ime_viewport_sync_received_ = false;\
  }\
  // Alice patch end 0064' "$path6"

# WebFrameWidgetImpl 直接同步 VisualViewport 视觉 transform。
sed -i '/^void WebFrameWidgetImpl::ScrollFocusedEditableNodeIntoView() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void WebFrameWidgetImpl::SyncImeViewportLift(float ime_height,\
                                             float bottom_chrome_height) {\
  if (!ForMainFrame())\
    return;\
\
  ime_viewport_ime_height_ = ime_height;\
  ime_viewport_bottom_chrome_height_ = bottom_chrome_height;\
  ime_viewport_sync_received_ = ime_height > 0.f;\
\
  float lift_height = 0.f;\
  Element* focused_element = FocusedElement();\
  if (focused_element \&\& ime_height > 0.f) {\
    float current_lift = GetPage()->GetVisualViewport().ImeViewportLift();\
    gfx::Rect focused_bounds = focused_element->BoundsInWidget();\
    focused_bounds.Offset(0, base::ClampRound<int>(current_lift));\
    LocalFrameView* frame_view = LocalRootImpl()->GetFrameView();\
    int viewport_height = frame_view ? frame_view->Size().height() : 0;\
    bool is_large_editor = focused_bounds.height() > viewport_height / 2;\
    Element* bounds_element = focused_element;\
    bool use_container_bounds = false;\
    if (!is_large_editor) {\
      Element* candidate = focused_element->ParentOrShadowHostElement();\
      Element* selected_container = nullptr;\
      gfx::Rect selected_container_bounds;\
      int candidate_index = 0;\
      while (candidate \&\& candidate_index < 2) {\
        gfx::Rect candidate_bounds = candidate->BoundsInWidget();\
        candidate_bounds.Offset(0, base::ClampRound<int>(current_lift));\
        bool height_ok = candidate_bounds.height() <= viewport_height / 2;\
        bool size_ok = candidate_bounds.height() >= focused_bounds.height();\
        bool contains_focus = candidate_bounds.Contains(focused_bounds);\
        bool extends_below =\
            candidate_bounds.bottom() > focused_bounds.bottom();\
        bool accepted =\
            !candidate_bounds.IsEmpty() \&\& height_ok \&\& size_ok\
            \&\& contains_focus \&\& extends_below;\
        if (accepted \&\&\
            (!selected_container\
             || candidate_bounds.bottom() > selected_container_bounds.bottom())) {\
          selected_container = candidate;\
          selected_container_bounds = candidate_bounds;\
        }\
        candidate = candidate->ParentOrShadowHostElement();\
        ++candidate_index;\
      }\
      if (selected_container) {\
        bounds_element = selected_container;\
        use_container_bounds = true;\
      }\
    }\
\
    gfx::Rect bounds_in_widget;\
    if (use_container_bounds) {\
      bounds_in_widget = bounds_element->BoundsInWidget();\
    } else if (bounds_element->IsSVGElement()) {\
      bounds_in_widget = bounds_element->BoundsInWidget();\
    } else {\
      Vector<gfx::Rect> outline_rects =\
          bounds_element->OutlineRectsInWidget(\
              DocumentUpdateReason::kFocus);\
      for (auto\& outline_rect : outline_rects)\
        bounds_in_widget.Union(outline_rect);\
    }\
    bounds_in_widget.Offset(0, base::ClampRound<int>(current_lift));\
\
    gfx::Rect bounds_in_dips =\
        BlinkSpaceToEnclosedDIPs(bounds_in_widget);\
    float device_scale_factor =\
        widget_base_->GetScreenInfo().device_scale_factor;\
    float focused_bottom_px = bounds_in_dips.bottom() * device_scale_factor;\
    float viewport_height_px = ViewRect().height() * device_scale_factor;\
    float effective_ime_height =\
        std::max(0.f, ime_height - bottom_chrome_height);\
    float required_lift_px =\
        std::max(\
            0.f,\
            focused_bottom_px - (viewport_height_px - effective_ime_height));\
    lift_height = std::min(required_lift_px, effective_ime_height);\
  }\
  GetPage()->GetVisualViewport().SyncImeViewportLift(lift_height);\
}\
// Alice patch end 0064
;}' "$path6"

# VisualViewport 内部只更新独立视觉 transform，不修改滚动 offset。
sed -i '/^#include <memory>$/a\
// Alice patch start 0064\
#include <algorithm>\
#include <cmath>\
// Alice patch end 0064' "$path12"

sed -i '/^  void Move(const ScrollOffset&);$/a\
  // Alice patch start 0064\
  void SyncImeViewportLift(float lift_height);\
  // Alice patch end 0064' "$path11"

sed -i '/^  float Scale() const { return scale_; }$/a\
  // Alice patch start 0064\
  float ImeViewportLift() const { return ime_viewport_lift_height_; }\
  // Alice patch end 0064' "$path11"

sed -i '/^\/\/     +- overscroll_elasticity_transform_node_$/c\
// Alice patch start 0064\
//     +- ime_viewport_transform_node_\
//        +- overscroll_elasticity_transform_node_\
// Alice patch end 0064' "$path11"

sed -i '/^\/\/        +- page_scale_node__$/c\
// Alice patch start 0064\
//           +- page_scale_node__\
// Alice patch end 0064' "$path11"

sed -i '/^\/\/           +- scroll_translation_node_ (scroll: scroll_node_)$/c\
// Alice patch start 0064\
//              +- scroll_translation_node_ (scroll: scroll_node_)\
// Alice patch end 0064' "$path11"

sed -i '/^  if (overscroll_type_ == OverscrollType::kTransform) {$/i\
  // Alice patch start 0064\
  {\
    TransformPaintPropertyNode::State state;\
    if (ime_viewport_lift_height_ != 0.f) {\
      state.transform_and_origin.matrix =\
          gfx::Transform::MakeTranslation(0, -ime_viewport_lift_height_);\
    }\
    state.in_subtree_of_page_scale = false;\
    state.direct_compositing_reasons = {CompositingReason::kViewport};\
    if (!ime_viewport_transform_node_) {\
      ime_viewport_transform_node_ = TransformPaintPropertyNode::Create(\
          *transform_parent, std::move(state));\
      change = PaintPropertyChangeType::kNodeAddedOrRemoved;\
    } else {\
      auto effective_change_type =\
          ime_viewport_transform_node_->Update(*transform_parent,\
                                               std::move(state));\
      if (effective_change_type ==\
          PaintPropertyChangeType::kChangedOnlySimpleValues) {\
        if (auto* paint_artifact_compositor = GetPaintArtifactCompositor()) {\
          bool updated =\
              paint_artifact_compositor->DirectlyUpdateImeViewportTransform(\
                  *ime_viewport_transform_node_);\
          if (updated) {\
            effective_change_type =\
                PaintPropertyChangeType::kChangedOnlyCompositedValues;\
            ime_viewport_transform_node_->CompositorSimpleValuesUpdated();\
          }\
        }\
      }\
      change = std::max(change, effective_change_type);\
    }\
    transform_parent = ime_viewport_transform_node_.Get();\
  }\
  // Alice patch end 0064
' "$path12"

sed -i '/^  ScrollOffset offset_;$/a\
  // Alice patch start 0064\
  float ime_viewport_lift_height_ = 0.f;\
  // Alice patch end 0064' "$path11"

sed -i '/^  Member<TransformPaintPropertyNode> device_emulation_transform_node_;$/a\
  // Alice patch start 0064\
  Member<TransformPaintPropertyNode> ime_viewport_transform_node_;\
  // Alice patch end 0064' "$path11"

sed -i '/^  visitor->Trace(device_emulation_transform_node_);$/a\
  // Alice patch start 0064\
  visitor->Trace(ime_viewport_transform_node_);\
  // Alice patch end 0064' "$path12"

sed -i '/^  device_emulation_transform_node_ = nullptr;$/a\
  // Alice patch start 0064\
  ime_viewport_transform_node_ = nullptr;\
  // Alice patch end 0064' "$path12"

sed -i '/^  point_in_root_frame += GetScrollOffset();$/a\
  // Alice patch start 0064\
  point_in_root_frame.Offset(0, ImeViewportLift());\
  // Alice patch end 0064' "$path12"

sed -i '/^  rect_in_root_frame.Offset(GetScrollOffset());$/a\
  // Alice patch start 0064\
  rect_in_root_frame.Offset(0, ImeViewportLift());\
  // Alice patch end 0064' "$path12"

sed -i '/^  rect_in_viewport.Offset(-GetScrollOffset());$/a\
  // Alice patch start 0064\
  rect_in_viewport.Offset(0, -ImeViewportLift());\
  // Alice patch end 0064' "$path12"

sed -i '/^  point_in_viewport -= GetScrollOffset();$/a\
  // Alice patch start 0064\
  point_in_viewport.Offset(0, -ImeViewportLift());\
  // Alice patch end 0064' "$path12"

sed -i '/^void VisualViewport::Move(const ScrollOffset& delta) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void VisualViewport::SyncImeViewportLift(float lift_height) {\
  float target_lift = std::max(0.f, lift_height);\
  if (std::abs(target_lift - ime_viewport_lift_height_) < 0.01f)\
    return;\
  ime_viewport_lift_height_ = target_lift;\
\
  bool updated_directly = false;\
  if (ime_viewport_transform_node_) {\
    auto* parent = ime_viewport_transform_node_->UnaliasedParent();\
    if (parent) {\
      TransformPaintPropertyNode::State state;\
      if (ime_viewport_lift_height_ != 0.f) {\
        state.transform_and_origin.matrix = gfx::Transform::MakeTranslation(\
            0, -ime_viewport_lift_height_);\
      }\
      state.in_subtree_of_page_scale = false;\
      state.direct_compositing_reasons = {CompositingReason::kViewport};\
      auto change =\
          ime_viewport_transform_node_->Update(*parent, std::move(state));\
      if (change == PaintPropertyChangeType::kChangedOnlySimpleValues) {\
        if (auto* paint_artifact_compositor = GetPaintArtifactCompositor()) {\
          updated_directly =\
              paint_artifact_compositor->DirectlyUpdateImeViewportTransform(\
                  *ime_viewport_transform_node_);\
          if (updated_directly) {\
            ime_viewport_transform_node_->CompositorSimpleValuesUpdated();\
          }\
        }\
      }\
    }\
  }\
\
  needs_paint_property_update_ |= !updated_directly;\
  if (!updated_directly) {\
    LocalMainFrame().View()->SetVisualViewportOrOverlayNeedsRepaint();\
    ScheduleAnimation();\
  }\
}\
// Alice patch end 0064
;}' "$path12"

sed -i '/^  gfx::Vector2dF overscroll_offset;$/a\
  // Alice patch start 0064\
  gfx::Vector2dF ime_viewport_offset;\
  // Alice patch end 0064' "$path13"

sed -i '/^      visual_viewport = gfx::ToFlooredPoint($/,/^          root_view->GetPage()->GetVisualViewport().VisibleRect().origin());$/c\
      // Alice patch start 0064\
      VisualViewport\& root_visual_viewport =\
          root_view->GetPage()->GetVisualViewport();\
      visual_viewport =\
          gfx::ToFlooredPoint(root_visual_viewport.VisibleRect().origin());\
      // Alice patch end 0064' "$path13"

sed -i '/^      overscroll_offset =$/a\
      // Alice patch start 0064\
      ime_viewport_offset =\
          gfx::Vector2dF(0, root_visual_viewport.ImeViewportLift());\
      // Alice patch end 0064' "$path13"

sed -i '/^  return visual_viewport.OffsetFromOrigin() + overscroll_offset;$/c\
  // Alice patch start 0064\
  return visual_viewport.OffsetFromOrigin() + overscroll_offset +\
         ime_viewport_offset;\
  // Alice patch end 0064' "$path13"

sed -i '/^  bool DirectlyUpdateTransform(const TransformPaintPropertyNode&);$/a\
  // Alice patch start 0064\
  bool DirectlyUpdateImeViewportTransform(const TransformPaintPropertyNode\&);\
  // Alice patch end 0064' "$path14"

sed -i '/^  static bool DirectlyUpdateTransform(cc::LayerTreeHost&,$/,/^                                      const TransformPaintPropertyNode&);$/ { /^                                      const TransformPaintPropertyNode&);$/a\
  // Alice patch start 0064\
  static bool DirectlyUpdateImeViewportTransform(\
      cc::LayerTreeHost\&,\
      const TransformPaintPropertyNode\&);\
  // Alice patch end 0064
; }' "$path16"

sed -i '/^bool PaintArtifactCompositor::DirectlyUpdatePageScaleTransform($/i\
// Alice patch start 0064\
bool PaintArtifactCompositor::DirectlyUpdateImeViewportTransform(\
    const TransformPaintPropertyNode\& transform) {\
  DCHECK(transform.HasDirectCompositingReasons());\
  if (CanDirectlyUpdateProperties()) {\
    return PropertyTreeManager::DirectlyUpdateImeViewportTransform(\
        *root_layer_->layer_tree_host(), transform);\
  }\
  return false;\
}\
// Alice patch end 0064
' "$path15"

sed -i '/^bool PropertyTreeManager::DirectlyUpdatePageScaleTransform($/i\
// Alice patch start 0064\
bool PropertyTreeManager::DirectlyUpdateImeViewportTransform(\
    cc::LayerTreeHost\& host,\
    const TransformPaintPropertyNode\& transform) {\
  DCHECK(!transform.ScrollNode());\
\
  auto* property_trees = host.property_trees();\
  int cc_transform_id = transform.CcNodeId(property_trees->sequence_number());\
  if (cc_transform_id == cc::kInvalidPropertyNodeId) {\
    return false;\
  }\
\
  auto\& cc_transform =\
      property_trees->transform_tree_mutable().MutableNode(cc_transform_id);\
  UpdateCcTransformLocalMatrix(cc_transform, transform);\
  cc_transform.is_currently_animating = false;\
  cc_transform.SetTransformChanged(cc::DamageReason::kUntracked);\
  property_trees->transform_tree_mutable().set_needs_update(true);\
  host.SetNeedsCommit(/*urgent=*/true);\
  return true;\
}\
// Alice patch end 0064
' "$path17"

