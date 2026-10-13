#!/bin/bash
# 扩展按钮：在应用内视图页打开 popup

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"
path2="chrome/browser/ui/android/extensions/extension_action_popup_contents.cc"
path3="chrome/browser/ui/android/extensions/java/src/org/chromium/chrome/browser/ui/extensions/ExtensionActionPopupContents.java"
path4="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"
path5="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/BUILD.gn"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1" "$path2" "$path3" "$path4" "$path5"; then
    exit 100
fi

# ---- extension_action_popup_contents.cc ----
sed -i '/^  Java_ExtensionActionPopupContents_onLoaded(AttachCurrentThread(),$/,/^                                             java_object_);$/c\
// Alice patch start\
  Java_ExtensionActionPopupContents_onLoaded(\
      AttachCurrentThread(), java_object_,\
      host_->host_contents()->GetLastCommittedURL().spec());\
// Alice patch end' "chrome/browser/ui/android/extensions/extension_action_popup_contents.cc"

# ---- ExtensionActionPopupContents.java ----

sed -i '\|^    private void onLoaded() {$|c\
// Alice patch start\
    private void onLoaded(@JniType("std::string") String url) {\
// Alice patch end' "chrome/browser/ui/android/extensions/java/src/org/chromium/chrome/browser/ui/extensions/ExtensionActionPopupContents.java"

sed -i '\|^            mDelegate\.onLoaded();$|c\
// Alice patch start\
            mDelegate.onLoaded(url);\
// Alice patch end' "chrome/browser/ui/android/extensions/java/src/org/chromium/chrome/browser/ui/extensions/ExtensionActionPopupContents.java"

sed -i '\|^        void onLoaded();$|c\
// Alice patch start\
        void onLoaded(String url);\
// Alice patch end' "chrome/browser/ui/android/extensions/java/src/org/chromium/chrome/browser/ui/extensions/ExtensionActionPopupContents.java"

# ---- ExtensionActionPopup.java ----

sed -i '\|^import org\.chromium\.base\.lifetime\.Destroyable;$|i\
// Alice patch start\
import org.chromium.base.ThreadUtils;\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

sed -i '\|^    /\*\*$|i\
// Alice patch start\
    /** Alice: if not null, the loaded popup page URL is handed over to this callback. */\
    private final @Nullable Callback<String> mOnPreviewUrl;\
\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

sed -i '\|^            boolean inspectWithDevTools) {$|c\
// Alice patch start\
            boolean inspectWithDevTools,\
            @Nullable Callback<String> onPreviewUrl) {\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

sed -i '\|^        mContents = contents;$|a\
// Alice patch start\
        mOnPreviewUrl = onPreviewUrl;\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

sed -i '\|^    /\*\* Adds a listener that will be notified when the popup window is dismissed\. \*/$|i\
// Alice patch start\
    /** Alice: shows the popup anchored to the action button (fallback path). */\
    public void showOnAnchor() {\
        mPopupWindow.show();\
        mContentView.requestFocus();\
    }\
\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

sed -i '\|^            if (Build\.VERSION\.SDK_INT >= 34) {$|i\
// Alice patch start\
            if (mOnPreviewUrl != null) {\
                // Alice: in preview mode the popup is never shown as an anchored window, so\
                // the content view has no window LayoutParams and nothing needs resizing.\
                return;\
            }\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

sed -i '\|^        public void onLoaded() {$|c\
// Alice patch start\
        public void onLoaded(String url) {\
            final @Nullable Callback<String> onPreviewUrl = mOnPreviewUrl;\
            if (onPreviewUrl != null) {\
                // Alice: still inside the native call stack; Destroy() is delete this, so the\
                // popup contents have to be torn down asynchronously.\
                final String previewUrl = url;\
                ThreadUtils.postOnUiThread(() -> onPreviewUrl.onResult(previewUrl));\
                return;\
            }\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionPopup.java"

# ---- ExtensionActionListMediator.java ----

sed -i '\|^import org\.chromium\.base\.lifetime\.Destroyable;$|i\
// Alice patch start\
import org.chromium.base.Callback;\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^import org\.chromium\.chrome\.browser\.extensions\.ContextMenuSource;$|i\
// Alice patch start\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinator;\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabCoordinatorSupplier;\
import org.chromium.chrome.browser.ephemeraltab.EphemeralTabObserver;\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^import org\.chromium\.ui\.widget\.RectProvider;$|a\
// Alice patch start\
import org.chromium.url.GURL;\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^        /\*\* State when a context menu is active\. \*/$|i\
// Alice patch start\
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
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^    @Nullable private final LifetimeAssert mLifetimeAssert = LifetimeAssert\.create(this);$|i\
// Alice patch start\
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
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^            boolean inspectWithDevTools) {$|a\
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
            mActionState = new ActionState.Idle();\
        }' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"
sed -i '\|^        ExtensionActionPopup popup =$|i\
// Alice patch start\
        // Alice: prefer the ephemeral tab (preview page) sheet for extension popups.\
        var ephemeralTabSupplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
        EphemeralTabCoordinator ephemeralTabCoordinator =\
                (ephemeralTabSupplier != null\
                                && EphemeralTabCoordinator.isSupported()\
                                && ephemeralTabSupplier.get() != null)\
                        ? ephemeralTabSupplier.get()\
                        : null;\
\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^                        inspectWithDevTools);$|c\
// Alice patch start\
                        inspectWithDevTools,\
                        (ephemeralTabCoordinator == null || inspectWithDevTools)\
                                ? null\
                                : mPreviewPopupUrlCallback);\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^    private void closePopup() {$|i\
// Alice patch start\
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
                /* requestDeniedCallback= */ () -> {});\
    }\
\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^        if (mActionState instanceof ActionState\.PopupPending pendingState) {$|i\
// Alice patch start\
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
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

sed -i '\|^            return mActionState instanceof ActionState\.PopupActive;$|i\
// Alice patch start\
            if (mActionState instanceof ActionState.PreviewActive) {\
                // Alice: the sheet may already be gone; only report active while it is open.\
                var supplier = EphemeralTabCoordinatorSupplier.from(mWindowAndroid);\
                EphemeralTabCoordinator coordinator = supplier != null ? supplier.get() : null;\
                return coordinator != null && coordinator.isOpened();\
            }\
// Alice patch end' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/ExtensionActionListMediator.java"

# ---- BUILD.gn ----

sed -i '0,\|^    "//chrome/browser/ui/android/extensions:java_resources",$| s||&\n    "//chrome/browser/ui/android/ephemeraltab:java",|' "chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/extensions/BUILD.gn"

# ---- DEPS ----
sed -i '\|^  "+chrome/browser/ui/messages/android/java",$|i\
  "+chrome/browser/ui/android/ephemeraltab",' "chrome/browser/ui/android/toolbar/DEPS"
