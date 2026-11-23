#!/bin/bash
# 扩展按钮：加载 popup 页面并在应用内预览页 BottomSheet 中打开。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"
path2="chrome/browser/ui/android/extensions/extension_action_popup_contents.cc"
path3="chrome/browser/ui/android/extensions/java/src/org/chromium/chrome/browser/ui/extensions/ExtensionActionPopupContents.java"
path4="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/BUILD.gn"
path6="chrome/browser/ui/android/toolbar/DEPS"

# 检测是否已应用
if grep -q 'Alice patch start 0028' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 原生 popup 加载完成时，把最终 URL 一起回传给 Java。
sed -i '/^  Java_ExtensionActionPopupContents_onLoaded(AttachCurrentThread(),$/,/^                                             java_object_);$/c\
// Alice patch start 0028\
  Java_ExtensionActionPopupContents_onLoaded(\
      AttachCurrentThread(), java_object_,\
      host_->host_contents()->GetLastCommittedURL().spec());\
// Alice patch end 0028' "$path2"

# Java popup 内容接收 URL 参数。
sed -i '\|^    private void onLoaded() {$|c\
// Alice patch start 0028\
    private void onLoaded(@JniType("std::string") String url) {\
// Alice patch end 0028' "$path3"

# 将 URL 从 popup 内容层传给注册的 delegate。
sed -i '\|^            mDelegate\.onLoaded();$|c\
// Alice patch start 0028\
            mDelegate.onLoaded(url);\
// Alice patch end 0028' "$path3"

# 更新 delegate 接口，要求 onLoaded 接收 URL。
sed -i '\|^        void onLoaded();$|c\
// Alice patch start 0028\
        void onLoaded(String url);\
// Alice patch end 0028' "$path3"

# 为异步销毁 popup 内容补充 ThreadUtils import。
sed -i '\|^import org\.chromium\.base\.lifetime\.Destroyable;$|i\
// Alice patch start 0028\
import org.chromium.base.ThreadUtils;\
// Alice patch end 0028' "$path4"

# 保存预览模式使用的 popup URL 回调。
sed -i '\|^    /\*\*$|i\
// Alice patch start 0028\
    /** Alice: if not null, the loaded popup page URL is handed over to this callback. */\
    private final @Nullable Callback<String> mOnPreviewUrl;\
\
// Alice patch end 0028' "$path4"

# 为 popup 构造器增加预览回调参数。
sed -i '\|^            boolean inspectWithDevTools) {$|c\
// Alice patch start 0028\
            boolean inspectWithDevTools,\
            @Nullable Callback<String> onPreviewUrl) {\
// Alice patch end 0028' "$path4"

# 初始化预览回调字段。
sed -i '\|^        mContents = contents;$|a\
// Alice patch start 0028\
        mOnPreviewUrl = onPreviewUrl;\
// Alice patch end 0028' "$path4"

# 无预览页时，提供回退到锚点 popup 的显示方法。
sed -i '\|^    /\*\* Adds a listener that will be notified when the popup window is dismissed\. \*/$|i\
// Alice patch start 0028\
    /** Alice: shows the popup anchored to the action button (fallback path). */\
    public void showOnAnchor() {\
        mPopupWindow.show();\
        mContentView.requestFocus();\
    }\
\
// Alice patch end 0028' "$path4"

# 预览模式下跳过普通锚点 popup 的窗口尺寸调整。
sed -i '\|^            if (Build\.VERSION\.SDK_INT >= 34) {$|i\
// Alice patch start 0028\
            if (mOnPreviewUrl != null) {\
                // Alice: in preview mode the popup is never shown as an anchored window, so\
                // the content view has no window LayoutParams and nothing needs resizing.\
                return;\
            }\
// Alice patch end 0028' "$path4"

# popup 加载完成后异步通知预览页，避免在 native 调用栈内销毁对象。
sed -i '\|^        public void onLoaded() {$|c\
// Alice patch start 0028\
        public void onLoaded(String url) {\
            final @Nullable Callback<String> onPreviewUrl = mOnPreviewUrl;\
            if (onPreviewUrl != null) {\
                // Alice: still inside the native call stack; Destroy() is delete this, so the\
                // popup contents have to be torn down asynchronously.\
                final String previewUrl = url;\
                ThreadUtils.postOnUiThread(() -> onPreviewUrl.onResult(previewUrl));\
                return;\
            }\
// Alice patch end 0028' "$path4"

# 为扩展动作列表补充 Callback import。
sed -i '\|^import org\.chromium\.base\.lifetime\.Destroyable;$|i\
// Alice patch start 0028\
import org.chromium.base.Callback;\
// Alice patch end 0028' "$path1"

# 补充预览页 BottomSheet 相关 import。
sed -i '\|^import org\.chromium\.chrome\.browser\.extensions\.ContextMenuSource;$|i\
// Alice patch start 0028\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinator;\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinatorSupplier;\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabObserver;\
// Alice patch end 0028' "$path1"

# 补充 GURL import。
sed -i '\|^import org\.chromium\.ui\.widget\.RectProvider;$|a\
// Alice patch start 0028\
import org.chromium.url.GURL;\
// Alice patch end 0028' "$path1"

# 增加“popup 在预览页中显示”的动作状态。
sed -i '\|^        /\*\* State when a context menu is active\. \*/$|i\
// Alice patch start 0028\
        /** State when the popup is displayed in the ephemeral tab (preview page) sheet. */\
        public static final class PreviewActive extends ActionState {\
            private final String mActionId;\
\
            public PreviewActive(String actionId) {\
                mActionId = actionId;\
            }\
\
            public String getActionId() {\
                return mActionId;\
            }\
        }\
\
// Alice patch end 0028' "$path1"

# 增加预览 URL 回调和预览页关闭观察器。
sed -i '\|^    @Nullable private final LifetimeAssert mLifetimeAssert = LifetimeAssert\.create(this);$|i\
// Alice patch start 0028\
    /** Alice: ExtensionActionPopup hands the loaded popup page URL over through this. */\
    private final Callback<String> mPreviewPopupUrlCallback = this::showPopupInPreviewSheet;\
\
    /** Alice: resets the action state when the user dismisses the preview sheet. */\
    private final EphemeralTabObserver mPreviewSheetObserver =\
            new EphemeralTabObserver() {\
                @Override\
                public void onWebContentsDestroyed() {\
                    if (mActionState instanceof ActionState.PreviewActive) {\
                        closePopup();\
                    }\
                }\
            };\
\
// Alice patch end 0028' "$path1"

# 已打开预览页时拒绝重复请求，并清理失效的预览状态。
sed -i '\|^            boolean inspectWithDevTools) {$|a\
        // Alice patch start 0028\
        if (mActionState instanceof ActionState.PreviewActive) {\
            // Alice: if the preview sheet is really still showing, drop this request\
            // (EphemeralTabCoordinator asserts !isOpened()). Otherwise the state is stale\
            // (the sheet was dismissed without notifying us) - reset it and carry on.\
            var previewSupplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
            EphemeralTabCoordinator previewCoordinator =\
                    previewSupplier != null ? previewSupplier.get() : null;\
            if (previewCoordinator != null && previewCoordinator.isOpened()) {\
                mHandler.post(popupContents::destroy);\
                return;\
            }\
            closePopup();\
        }\
        // Alice patch end 0028' "$path1"

# 创建 popup 前解析预览页协调器。
sed -i '\|^        ExtensionActionPopup popup =$|i\
// Alice patch start 0028\
        // Alice: prefer the ephemeral tab (preview page) sheet for extension popups.\
        var ephemeralTabSupplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
        EphemeralTabCoordinator ephemeralTabCoordinator =\
                (ephemeralTabSupplier != null\
                                && EphemeralTabCoordinator.isSupported()\
                                && ephemeralTabSupplier.get() != null)\
                        ? ephemeralTabSupplier.get()\
                        : null;\
\
// Alice patch end 0028' "$path1"

# 根据是否支持预览页，决定传入 URL 回调还是走普通 popup。
sed -i '\|^                        inspectWithDevTools);$|c\
// Alice patch start 0028\
                        inspectWithDevTools,\
                        (ephemeralTabCoordinator == null || inspectWithDevTools)\
                                ? null\
                                : mPreviewPopupUrlCallback);\
// Alice patch end 0028' "$path1"

# 将加载完成的扩展 popup URL 显示到预览页 BottomSheet。
sed -i '\|^    private void closePopup() {$|i\
// Alice patch start 0028\
    /** Alice: shows the loaded extension popup page in the ephemeral tab bottom sheet. */\
    private void showPopupInPreviewSheet(String url) {\
        if (!(mActionState instanceof ActionState.PopupActive activeState)) {\
            return;\
        }\
        String actionId = activeState.getActionId();\
        ExtensionActionPopup popup = activeState.getPopup();\
\
        var supplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
        EphemeralTabCoordinator coordinator =\
                (supplier != null && EphemeralTabCoordinator.isSupported())\
                        ? supplier.get()\
                        : null;\
        if (coordinator == null) {\
            popup.showOnAnchor();\
            return;\
        }\
\
        // Switch the state first so that popup.destroy() cannot re-enter closePopup().\
        mActionState = new ActionState.PreviewActive(actionId);\
        popup.destroy();\
        coordinator.addObserver(mPreviewSheetObserver);\
\
        Tab currentTab = mCurrentTabSupplier.get();\
        WebContents webContents = currentTab != null ? currentTab.getWebContents() : null;\
        ExtensionAction action = mExtensionsToolbarBridge.getAction(actionId, webContents);\
        String title = action != null ? action.getName() : "";\
\
        coordinator.requestOpenSheet(\
                new GURL(url),\
                /* fullPageUrl= */ null,\
                title,\
                mProfile,\
                /* canPromoteToNewTab= */ true,\
                /* shouldHaveContextMenu= */ true,\
                /* initiatorOrigin= */ null,\
                /* additionalNavigationParams= */ null,\
                /* requestDeniedCallback= */ this::closePopup);\
    }\
\
// Alice patch end 0028' "$path1"

# 关闭预览页时同步恢复扩展按钮状态。
sed -i '\|^        if (mActionState instanceof ActionState\.PopupPending pendingState) {$|i\
// Alice patch start 0028\
        if (mActionState instanceof ActionState.PreviewActive previewState) {\
            mActionState = new ActionState.Idle();\
            ListMenuButton previewButtonView =\
                    (ListMenuButton)\
                            mRecyclerViewDelegate.getButtonViewForId(\
                                    previewState.getActionId());\
            if (previewButtonView != null) {\
                previewButtonView.setIsPressed(false);\
            }\
            var previewSupplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
            EphemeralTabCoordinator previewCoordinator =\
                    previewSupplier != null ? previewSupplier.get() : null;\
            if (previewCoordinator != null) {\
                previewCoordinator.removeObserver(mPreviewSheetObserver);\
                if (previewCoordinator.isOpened()) {\
                    previewCoordinator.close();\
                }\
            }\
            undoPopout();\
            return;\
        }\
\
// Alice patch end 0028' "$path1"

# 点击其他扩展按钮前先关闭当前预览页。
sed -i '\|^    private void onPrimaryClick(String actionId) {$|a\
// Alice patch start 0028\
        if (mActionState instanceof ActionState.PreviewActive previewState) {\
            boolean closeOnly = previewState.getActionId().equals(actionId);\
            closePopup();\
            if (closeOnly) {\
                return;\
            }\
        }\
// Alice patch end 0028' "$path1"

# 扩展启用或禁用会重建动作列表，先关闭旧预览以撤销临时按钮状态。
sed -i '\|^    private class ToolbarObserver implements ExtensionsToolbarBridge.Observer {$|i\
// Alice patch start 0028\
    /** Alice: closes a preview before an action-list update can restore its temporary icon. */\
    private void closePreviewForActionListChange() {\
        if (mActionState instanceof ActionState.PreviewActive) {\
            closePopup();\
        }\
    }\
\
// Alice patch end 0028' "$path1"

# 动作列表更新前关闭预览页，避免旧临时图标残留。
sed -i '\|^    private class ToolbarObserver implements ExtensionsToolbarBridge.Observer {$|,/^    }$/ s|^            reconcileActionItems();$|            // Alice patch start 0028\
            closePreviewForActionListChange();\
            reconcileActionItems();\
            // Alice patch end 0028|' "$path1"

# 预览页仍打开时，扩展工具栏应报告 popup 为活跃状态。
sed -i '\|^            return mActionState instanceof ActionState\.PopupActive;$|i\
// Alice patch start 0028\
            if (mActionState instanceof ActionState.PreviewActive) {\
                // Alice: the sheet may already be gone; only report active while it is open.\
                var supplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
                EphemeralTabCoordinator coordinator = supplier != null ? supplier.get() : null;\
                return coordinator != null && coordinator.isOpened();\
            }\
// Alice patch end 0028' "$path1"

# 为扩展工具栏目标补上 ephemeral tab Java 依赖。
sed -i '0,\|^    "//chrome/browser/ui/android/extensions:java_resources",$| s||&\n    # Alice patch start 0028\n    "//chrome/browser/ui/android/ephemeraltab:java",\n    # Alice patch end 0028|' "$path5"

# 允许工具栏 DEPS 引用 ephemeral tab 目录。
sed -i '\|^  "+chrome/browser/ui/messages/android/java",$|i\
  # Alice patch start 0028\
  "+chrome/browser/ui/android/ephemeraltab",\
  # Alice patch end 0028' "$path6"
