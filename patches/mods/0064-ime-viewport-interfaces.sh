#!/bin/bash
# IME visual viewport 接口层：焦点滚动拦截和 CC/Blink 输入接口声明。

set -e

path1="cc/trees/proxy.h"
path2="cc/trees/layer_tree_host.h"
path3="cc/trees/layer_tree_host.cc"
path4="cc/trees/proxy_main.h"
path5="cc/trees/proxy_main.cc"
path6="cc/trees/proxy_impl.h"
path7="cc/trees/proxy_impl.cc"
path8="cc/trees/single_thread_proxy.h"
path9="content/public/android/java/src/org/chromium/content/browser/webcontents/WebContentsImpl.java"
path10="cc/trees/single_thread_proxy.cc"
path11="cc/test/fake_proxy.h"
path12="third_party/blink/public/mojom/input/input_handler.mojom"
path13="third_party/blink/renderer/platform/widget/input/frame_widget_input_handler_impl.h"
path14="third_party/blink/renderer/platform/widget/input/frame_widget_input_handler_impl.cc"
path15="third_party/blink/renderer/core/frame/web_frame_widget_impl.h"
path16="third_party/blink/renderer/core/frame/web_frame_widget_impl.cc"

# 检测是否已应用
if grep -q 'Alice patch start 0064' "$path1"; then
    exit 100
fi

# 拦截原有焦点滚动。实际 IME 跟随由 compositor visual viewport pan 完成。
# 补充 Activity import。
sed -i '/^import android\.content\.Context;$/i\
// Alice patch start 0064\
import android.app.Activity;\
// Alice patch end 0064' "$path9"

# 补充 WindowManager import。
sed -i '/^import android\.view\.ViewStructure;$/a\
// Alice patch start 0064\
import android.view.WindowManager;\
// Alice patch end 0064' "$path9"

# 在 ADJUST_NOTHING 模式下拦截原生焦点滚动。
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
' "$path9"

# 23) 将 IME 逐帧位移投递到 compositor 线程，只 pan visual viewport。
#     不进入 Blink scroll/layout，也不平移 Android ContentView。
# 为 Proxy 接口补充几何类型 include。
sed -i '/^#include "services\/metrics\/public\/cpp\/ukm_source_id.h"$/a\
// Alice patch start 0064\
#include "ui/gfx/geometry/vector2d_f.h"\
// Alice patch end 0064' "$path1"
# 在 Proxy 接口声明 IME viewport 位移方法。
sed -i '/^  virtual void SetNeedsRedraw(const gfx::Rect& damage_rect) = 0;$/a\
  // Alice patch start 0064\
  virtual void SetImeViewportTranslation(float translation_y) = 0;\
  // Alice patch end 0064' "$path1"

# 为 LayerTreeHost 补充几何类型 include。
sed -i '/^#include "ui\/gfx\/geometry\/rect.h"$/a\
// Alice patch start 0064\
#include "ui/gfx/geometry/vector2d_f.h"\
// Alice patch end 0064' "$path2"
# 在 LayerTreeHost 声明 IME viewport 位移方法。
sed -i '/^  bool HasPendingPageScaleAnimation() const;$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslation(float translation_y);\
  // Alice patch end 0064' "$path2"

# 实现 LayerTreeHost 到 Proxy 的 IME 位移转发。
sed -i '/^bool LayerTreeHost::HasPendingPageScaleAnimation() const {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void LayerTreeHost::SetImeViewportTranslation(float translation_y) {\
  DCHECK(IsMainThread());\
  proxy()->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0064
;}' "$path3"

# 在 ProxyMain 头文件声明 IME 位移 override。
sed -i '/^  void SetNeedsRedraw(const gfx::Rect& damage_rect) override;$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslation(float translation_y) override;\
  // Alice patch end 0064' "$path4"

# 实现 ProxyMain 向 impl 线程投递 IME 位移。
sed -i '/^void ProxyMain::SetNeedsRedraw(const gfx::Rect& damage_rect) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void ProxyMain::SetImeViewportTranslation(float translation_y) {\
  DCHECK(IsMainThread());\
  ImplThreadTaskRunner()->PostTask(\
      FROM_HERE,\
      base::BindOnce(\&ProxyImpl::SetImeViewportTranslationOnImpl,\
                     base::Unretained(proxy_impl_.get()), translation_y));\
}\
// Alice patch end 0064
;}' "$path5"

# 为 ProxyImpl 补充几何类型 include。
sed -i '/^#include "cc\/trees\/layer_tree_host_impl_delegate.h"$/a\
// Alice patch start 0064\
#include "ui/gfx/geometry/vector2d_f.h"\
// Alice patch end 0064' "$path6"
# 在 ProxyImpl 头文件声明 impl 线程 IME 位移方法。
sed -i '/^  void SetNeedsRedrawOnImpl(const gfx::Rect& damage_rect);$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslationOnImpl(float translation_y);\
  // Alice patch end 0064' "$path6"

# 为 ProxyImpl 实现补充 viewport include。
sed -i '/^#include "cc\/input\/browser_controls_offset_tag_modifications.h"$/a\
// Alice patch start 0064\
#include "cc/layers/viewport.h"\
// Alice patch end 0064' "$path7"

# 实现 impl 线程到 LayerTreeHostImpl 的 IME 位移转发。
sed -i '/^void ProxyImpl::SetNeedsRedrawOnImpl(const gfx::Rect& damage_rect) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void ProxyImpl::SetImeViewportTranslationOnImpl(float translation_y) {\
  DCHECK(IsImplThread());\
  host_impl_->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0064
;}' "$path7"

# 在 SingleThreadProxy 头文件声明 IME 位移 override。
sed -i '/^  void SetNeedsRedraw(const gfx::Rect& damage_rect) override;$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslation(float translation_y) override;\
  // Alice patch end 0064' "$path8"

# 为 SingleThreadProxy 实现补充 viewport include。
sed -i '/^#include "cc\/input\/browser_controls_offset_tag_modifications.h"$/a\
// Alice patch start 0064\
#include "cc/layers/viewport.h"\
// Alice patch end 0064' "$path10"

# 实现单线程 Proxy 的 IME 位移转发。
sed -i '/^void SingleThreadProxy::SetNeedsRedraw(const gfx::Rect& damage_rect) {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void SingleThreadProxy::SetImeViewportTranslation(float translation_y) {\
  DCHECK(task_runner_provider_->IsMainThread());\
  if (!host_impl_)\
    return;\
  DebugScopedSetImplThread impl(task_runner_provider_);\
  host_impl_->SetImeViewportTranslation(translation_y);\
}\
// Alice patch end 0064
;}' "$path10"

# 为测试 FakeProxy 增加空实现。
sed -i '/^  void SetNeedsRedraw(const gfx::Rect& damage_rect) override {}$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslation(float translation_y) override {}\
  // Alice patch end 0064' "$path11"

# 在 FrameWidgetInputHandler mojom 中声明 IME 位移和焦点刷新方法。
sed -i '/^  ScrollFocusedEditableNodeIntoView();$/a\
\
  // Alice patch start 0064\
  // Sets a compositor-only IME viewport translation in physical pixels.\
  SetImeViewportTranslation(float translation_y);\
\
  // Reports the current focused editable bounds without scrolling it.\
  RefreshFocusedEditableNodeBounds();\
  // Alice patch end 0064' "$path12"

# 在 Blink 输入 handler 头文件声明 IME 位移 override。
sed -i '/^  void ScrollFocusedEditableNodeIntoView() override;$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslation(float translation_y) override;\
  void RefreshFocusedEditableNodeBounds() override;\
  // Alice patch end 0064' "$path13"

# 实现 Blink 输入 handler 的主线程投递和焦点刷新。
sed -i '/^void FrameWidgetInputHandlerImpl::ScrollFocusedEditableNodeIntoView() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void FrameWidgetInputHandlerImpl::SetImeViewportTranslation(\
    float translation_y) {\
  RunOnMainThread(base::BindOnce(\
      [](base::WeakPtr<mojom::blink::FrameWidgetInputHandler> handler,\
         float translation) {\
        if (handler)\
          handler->SetImeViewportTranslation(translation);\
      },\
      main_thread_frame_widget_input_handler_, translation_y));\
}\
\
void FrameWidgetInputHandlerImpl::RefreshFocusedEditableNodeBounds() {\
  RunOnMainThread(base::BindOnce(\
      [](base::WeakPtr<mojom::blink::FrameWidgetInputHandler> handler) {\
        if (handler)\
          handler->RefreshFocusedEditableNodeBounds();\
      },\
      main_thread_frame_widget_input_handler_));\
}\
// Alice patch end 0064
;}' "$path14"

# 在 WebFrameWidgetImpl 头文件声明 IME 位移 override。
sed -i '/^  void ScrollFocusedEditableNodeIntoView() override;$/a\
  // Alice patch start 0064\
  void SetImeViewportTranslation(float translation_y) override;\
  void RefreshFocusedEditableNodeBounds() override;\
  // Alice patch end 0064' "$path15"

# 将 IME 位移从 WebFrameWidgetImpl 转发到 LayerTreeHost，并刷新焦点 bounds。
sed -i '/^void WebFrameWidgetImpl::ScrollFocusedEditableNodeIntoView() {$/,/^}$/{/^}$/a\
\
// Alice patch start 0064\
void WebFrameWidgetImpl::SetImeViewportTranslation(float translation_y) {\
  if (!ForMainFrame())\
    return;\
  LayerTreeHost()->SetImeViewportTranslation(translation_y);\
}\
\
void WebFrameWidgetImpl::RefreshFocusedEditableNodeBounds() {\
  if (!ForMainFrame())\
    return;\
  if (Element* element = FocusedElement()) {\
    element->GetDocument().SendFocusNotification(\
        element, mojom::blink::FocusType::kNone);\
  }\
}\
// Alice patch end 0064
;}' "$path16"

