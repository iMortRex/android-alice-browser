#!/bin/bash
# DevTools 面板挂在当前浏览器窗口

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/app/ChromeActivity.java"
path2="chrome/browser/devtools/android/java/src/org/chromium/chrome/browser/devtools/DevToolsWindowAndroid.java"
path3="chrome/browser/devtools/devtools_window.cc"
path4="chrome/browser/devtools/devtools_window.h"
path5="chrome/browser/devtools/android/devtools_window_android.cc"
path6="chrome/android/java/src/org/chromium/chrome/browser/contextmenu/ContextMenuHelper.java"
path7="chrome/browser/contextmenu/java/src/org/chromium/chrome/browser/contextmenu/ContextMenuNativeDelegateImpl.java"

# 检测是否已应用
if grep -q 'Alice patch start 0025' "$path1"; then
    exit 100
fi

# 1) ChromeActivity：三个入口打开 DevTools 前，把目标浏览器窗口告诉原生层
sed -i '/^            DevToolsWindowAndroid\.openDevTools(webContents);$/i\
            // Alice patch start 0025\
            ChromeAndroidTask aliceDevToolsTask = getChromeAndroidTaskSupplier().get();\
            if (aliceDevToolsTask != null) {\
                DevToolsWindowAndroid.setTargetBrowserWindow(\
                        aliceDevToolsTask.getOrCreateNativeBrowserWindowPtr(\
                                currentTab.getProfile()));\
            }\
            // Alice patch end 0025' "$path1"

sed -i '/^            DevToolsWindowAndroid\.openDevToolsConsole(webContents);$/i\
            // Alice patch start 0025\
            ChromeAndroidTask aliceDevToolsTask = getChromeAndroidTaskSupplier().get();\
            if (aliceDevToolsTask != null) {\
                DevToolsWindowAndroid.setTargetBrowserWindow(\
                        aliceDevToolsTask.getOrCreateNativeBrowserWindowPtr(\
                                currentTab.getProfile()));\
            }\
            // Alice patch end 0025' "$path1"

sed -i '/^            DevToolsWindowAndroid\.openDevToolsInspect(webContents);$/i\
            // Alice patch start 0025\
            ChromeAndroidTask aliceDevToolsTask = getChromeAndroidTaskSupplier().get();\
            if (aliceDevToolsTask != null) {\
                DevToolsWindowAndroid.setTargetBrowserWindow(\
                        aliceDevToolsTask.getOrCreateNativeBrowserWindowPtr(\
                                currentTab.getProfile()));\
            }\
            // Alice patch end 0025' "$path1"

# 2) DevToolsWindowAndroid：Java 入口
sed -i '/^    @NativeMethods$/i\
    // Alice patch start 0025\
    /** 指定前端要挂进的浏览器窗口（0 = 走原来的新窗口逻辑）。 */\
    public static void setTargetBrowserWindow(long nativeBrowserWindowPtr) {\
        DevToolsWindowAndroidJni.get().setTargetBrowserWindow(nativeBrowserWindowPtr);\
    }\
    // Alice patch end 0025\
' "$path2"

# 3) DevToolsWindowAndroid：JNI 声明
sed -i '/^        void attachToBrowser(WebContents webContents, long nativeBrowserWindowPtr);$/a\
\
        // Alice patch start 0025\
        void setTargetBrowserWindow(long browserWindowPtr);\
        // Alice patch end 0025' "$path2"

# 4) devtools_window.cc：全局目标窗口指针（0 = 原逻辑）
sed -i '/^    "devtools:\/\/devtools\/bundled\/inspector.html";$/a\
// Alice patch start 0025\
static int64_t g_android_target_browser_window_ptr = 0;\
// Alice patch end 0025' "$path3"

# 5) devtools_window.cc：Show() 里若已指定窗口，直接挂进去，不再新开 Activity
sed -i '/^  JNIEnv\* env = base::android::AttachCurrentThread();$/i\
  // Alice patch start 0025\
  if (g_android_target_browser_window_ptr != 0) {\
    AttachToBrowser(\
        reinterpret_cast<BrowserWindowInterface*>(g_android_target_browser_window_ptr));\
    g_android_target_browser_window_ptr = 0;\
    launched_activity_ = true;\
    OverrideAndSyncDevToolsRendererPrefs();\
    return;\
  }\
  // Alice patch end 0025' "$path3"

# 6) devtools_window.cc：setter
sed -i '/^void DevToolsWindow::AttachToBrowser(BrowserWindowInterface\* browser) {$/i\
// Alice patch start 0025\
void DevToolsWindow::SetAndroidTargetBrowserWindow(int64_t ptr) {\
  g_android_target_browser_window_ptr = ptr;\
}\
// Alice patch end 0025\
\
' "$path3"

# 7) devtools_window.cc：插到当前活动标签页之后，而不是固定插到第 0 个
sed -i 's|^  tab_list->InsertWebContentsAt(0, std::move(owned_web_contents), false,$|  // Alice patch start 0025\n  const int insert_index =\n      std::min(tab_list->GetActiveIndex() + 1, tab_list->GetTabCount());\n  tab_list->InsertWebContentsAt(insert_index, std::move(owned_web_contents), false,|' "$path3"

sed -i '/^                                std::nullopt);$/a\
  // Alice patch end 0025' "$path3"

# 8) devtools_window.h：声明
sed -i '/^  static DevToolsWindow\* AsDevToolsWindow(BrowserWindowInterface\* browser);$/a\
  // Alice patch start 0025\
  static void SetAndroidTargetBrowserWindow(int64_t ptr);\
  // Alice patch end 0025' "$path4"

# 9) devtools_window_android.cc：JNI 实现
sed -i '/^DEFINE_JNI(DevToolsWindowAndroid)$/i\
// Alice patch start 0025\
static void JNI_DevToolsWindowAndroid_SetTargetBrowserWindow(\
    JNIEnv* env,\
    int64_t native_browser_window_ptr) {\
#if BUILDFLAG(ENABLE_DEVTOOLS_FRONTEND)\
  DevToolsWindow::SetAndroidTargetBrowserWindow(native_browser_window_ptr);\
#endif\
}\
// Alice patch end 0025\
' "$path5"

# 10) 长按页面菜单：创建 delegate 时解析当前窗口，选中“检查”时再设置目标，
#     避免未经“检查”操作就留下全局目标窗口。
sed -i '/^import org\.chromium\.chrome\.browser\.flags\.ChromeFeatureList;$/i\
// Alice patch start 0025\
import org.chromium.chrome.browser.devtools.DevToolsWindowAndroid;\
// Alice patch end 0025' "$path6"

sed -i '/^import org\.chromium\.chrome\.browser\.flags\.ChromeFeatureList;$/a\
// Alice patch start 0025\
import org.chromium.chrome.browser.profiles.Profile;\
import org.chromium.chrome.browser.ui.browser_window.ChromeAndroidTaskTrackerFactory;\
// Alice patch end 0025' "$path6"

sed -i '/^        mCurrentNativeDelegate =$/i\
        // Alice patch start 0025\
        Runnable aliceSetDevToolsTarget =\
                () -> {\
                    var aliceDevToolsTask =\
                            ChromeAndroidTaskTrackerFactory.getInstance()\
                                    .get(activity.getTaskId());\
                    @Nullable Profile aliceDevToolsProfile =\
                            Profile.fromWebContents(mWebContents);\
                    if (aliceDevToolsTask != null \&\& aliceDevToolsProfile != null) {\
                        DevToolsWindowAndroid.setTargetBrowserWindow(\
                                aliceDevToolsTask.getOrCreateNativeBrowserWindowPtr(\
                                        aliceDevToolsProfile));\
                    }\
                };\
        // Alice patch end 0025\
' "$path6"

sed -i 's|^                new ContextMenuNativeDelegateImpl(mWebContents, renderFrameHost, params);$|                new ContextMenuNativeDelegateImpl(\
                        mWebContents,\
                        renderFrameHost,\
                        params,\
                        aliceSetDevToolsTarget);|' "$path6"

sed -i '/^    private final RenderFrameHost mRenderFrameHost;$/a\
\
    // Alice patch start 0025\
    private final Runnable mDevToolsTargetSetter;\
    // Alice patch end 0025' "$path7"

sed -i 's|^            ContextMenuParams contextMenuParams) {$|            ContextMenuParams contextMenuParams,\
            // Alice patch start 0025\
            Runnable devToolsTargetSetter) {\
        // Alice patch end 0025|' "$path7"

sed -i '/^        mRenderFrameHost = renderFrameHost;$/a\
        // Alice patch start 0025\
        mDevToolsTargetSetter = devToolsTargetSetter;\
        // Alice patch end 0025' "$path7"

sed -i '/^        ContextMenuNativeDelegateImplJni\.get()\.inspectElement(mNativePtr, mRenderFrameHost, x, y);$/i\
        // Alice patch start 0025\
        mDevToolsTargetSetter.run();\
        // Alice patch end 0025' "$path7"
