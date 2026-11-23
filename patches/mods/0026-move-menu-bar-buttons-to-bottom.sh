#!/bin/bash
# 菜单栏的按钮移到底部：重排图标行、固定底部 footer，并保护扩展菜单入口。

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedAppMenuPropertiesDelegate.java"
path2="chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuHandlerImpl.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"
path4="chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenu.java"
path5="chrome/android/java/src/org/chromium/chrome/browser/customtabs/CustomTabAppMenuPropertiesDelegate.java"
path6="chrome/android/java/src/org/chromium/chrome/browser/customtabs/CustomTabActivity.java"

# 检测是否已应用
if grep -q 'Alice patch start 0026' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 重排图标行：去掉后退和页面信息，下载改为「下载内容」，新增「扩展」。
sed -i '/^            if (ChromeFeatureList\.sThreeDotMenuBackButton\.isEnabled()) {$/,/^            }$/d' "$path1"
sed -i '/^            iconModels\.add(buildDownloadActionModel(currentTab));$/d' "$path1"
sed -i '/^            if (!ChromeFeatureList\.sThreeDotMenuBackButton\.isEnabled()) {$/,/^$/d' "$path1"
sed -i '/^            iconModels\.add(buildBookmarkActionModel(currentTab));$/a\
            // Alice patch start 0026\
            // 下载此网页 → 下载内容\
            iconModels.add(\
                    AppMenuItemUtils.buildModelForIcon(\
                            mContext,\
                            R.id.downloads_menu_id,\
                            R.string.menu_downloads,\
                            R.string.menu_downloads,\
                            R.drawable.ic_file_download_white_24dp));\
            // 页面信息 → 扩展\
            iconModels.add(\
                    AppMenuItemUtils.buildModelForIcon(\
                            mContext,\
                            R.id.extensions_menu_menu_id,\
                            R.string.menu_extensions_menu,\
                            R.string.menu_extensions,\
                            R.drawable.ic_extension_24dp));\
            // Alice patch end 0026' "$path1"

# 自定义标签页沿用正常标签页的底部按钮组合。
sed -i '/^            if (ChromeFeatureList\.sThreeDotMenuBackButton\.isEnabled()) {$/,/^            iconModels\.add(buildReloadModel(currentTab));$/c\
            iconModels.add(buildForwardActionModel(currentTab));\
\
            if (bookmarkItemVisible) {\
                iconModels.add(buildBookmarkActionModel(currentTab));\
            }\
\
            // Alice patch start 0026\
            // 下载此网页 → 下载内容\
            if (downloadItemVisible) {\
                iconModels.add(\
                        AppMenuItemUtils.buildModelForIcon(\
                                mContext,\
                                R.id.downloads_menu_id,\
                                R.string.menu_downloads,\
                                R.string.menu_downloads,\
                                R.drawable.ic_file_download_white_24dp));\
            }\
            // 页面信息 → 扩展\
            iconModels.add(\
                    AppMenuItemUtils.buildModelForIcon(\
                            mContext,\
                            R.id.extensions_menu_menu_id,\
                            R.string.menu_extensions_menu,\
                            R.string.menu_extensions,\
                            R.drawable.ic_extension_24dp));\
            // Alice patch end 0026\
\
            iconModels.add(buildReloadModel(currentTab));' "$path5"

# 自定义标签页补齐底部按钮所需的下拉和扩展页依赖。
sed -i '/^import org\.chromium\.chrome\.browser\.document\.ChromeLauncherActivity;$/a\
// Alice patch start 0026\
import org.chromium.chrome.browser.download.DownloadOpenSource;\
import org.chromium.chrome.browser.download.DownloadUtils;\
// Alice patch end 0026' "$path6"

# 自定义标签页点击“下载内容”时打开下载管理器。
sed -i 's|^        } else if (id == R\.id\.open_in_browser_id) {$|        } else if (id == R.id.downloads_menu_id) {\
            // Alice patch start 0026\
            Tab tab = getCustomTabActivityTabProvider().getTab();\
            DownloadUtils.showDownloadManager(\
                    this,\
                    tab,\
                    tab == null ? null : tab.getProfile().getOtrProfileId(),\
                    DownloadOpenSource.MENU);\
            RecordUserAction.record("MobileMenuDownloadManager");\
            // Alice patch end 0026\
            return true;\
        } else if (id == R.id.open_in_browser_id) {|' "$path6"

# 自定义标签页点击“扩展”时复用 Web App Header 或工具栏的扩展菜单。
sed -i '/^        } else if (id == R\.id\.extensions_menu_menu_id) {$/,/^        } else if (id == R\.id\.extensions_webstore_menu_id) {$/c\
        } else if (id == R.id.extensions_menu_menu_id) {\
            // Alice patch start 0026\
            ExtensionsToolbarCoordinator coordinator = null;\
            var intentDataProvider = assertNonNull(getIntentDataProvider());\
            if (WebAppHeaderUtils.isWebAppHeaderEnabled(intentDataProvider)) {\
                coordinator =\
                        assumeNonNull(\
                                        getBaseCustomTabRootUiCoordinator()\
                                                .getWebAppHeaderLayoutCoordinator())\
                                .getExtensionsToolbarCoordinator();\
            }\
            if (coordinator == null && getToolbarManager() != null) {\
                coordinator = getToolbarManager().getExtensionsToolbarCoordinator();\
            }\
            if (coordinator != null) {\
                coordinator.showExtensionsMenu();\
                RecordUserAction.record("MobileMenuExtensionsMenu");\
                return true;\
            }\
            // Alice patch end 0026\
        } else if (id == R.id.extensions_webstore_menu_id) {' "$path6"

# 补齐底部 footer 所需的 Android 和 PropertyModel import。
sed -i '/^import android\.view\.View;$/i\
// Alice patch start 0026\
import android.view.LayoutInflater;\
// Alice patch end 0026' "$path2"
sed -i '/^import android\.widget\.ListView;$/i\
// Alice patch start 0026\
import android.widget.LinearLayout;\
// Alice patch end 0026' "$path2"
sed -i '/^import org\.chromium\.ui\.modelutil\.PropertyModel;$/a\
// Alice patch start 0026\
import org.chromium.ui.modelutil.PropertyModelChangeProcessor;\
// Alice patch end 0026' "$path2"

# 新增保存图标行 footer 模型的字段。
sed -i '/^    private final Context mContext;$/i\
    // Alice patch start 0026\
    private @Nullable PropertyModel mIconRowFooterModel;\
    // Alice patch end 0026' "$path2"

# 菜单模型构建完成后，把图标行模型从列表模型中摘出。
sed -i '/^        setupModelForHighlightAndClick(mModelList, mHighlightMenuId, this);$/a\
        // Alice patch start 0026\
        mIconRowFooterModel = extractIconRowModel();\
        // Alice patch end 0026' "$path2"

# 新增图标行提取和独立 footer View 构建方法。
sed -i '/^    \/\*\*$/{N;/A means of reporting an exception without crashing\./s|^|    // Alice patch start 0026\n    /** 把 BUTTON_ROW（图标行）从菜单模型里摘出来，留作底部固定 footer。 */\n    private @Nullable PropertyModel extractIconRowModel() {\n        if (mModelList == null) return null;\n        for (int i = 0; i < mModelList.size(); i++) {\n            ListItem item = mModelList.get(i);\n            if (item.type != AppMenuItemType.BUTTON_ROW) continue;\n            PropertyModel model = item.model;\n            mModelList.removeAt(i);\n            return model;\n        }\n        return null;\n    }\n\n    /** 用图标行模型生成一份独立视图（不随列表滚动，钉在菜单底部）。 */\n    private View buildIconRowFooterView(PropertyModel model) {\n        ViewGroup view =\n                (ViewGroup)\n                        LayoutInflater.from(mContext)\n                                .inflate(R.layout.icon_row_menu_item, /* root= */ null);\n        PropertyModelChangeProcessor.create(\n                model, view, AppMenuItemViewBinder::bindIconRowItem,\n                /* performInitialBind= */ true);\n        // 关键：root 传 null 时 inflate 不会带 LayoutParams，不设的话\n        // LinearLayout 默认 WRAP_CONTENT，而里面 5 个按钮是 weight=1 + width=0dp，\n        // 会导致整行宽度为 0（按钮全看不见）。\n        view.setLayoutParams(\n                new LinearLayout.LayoutParams(\n                        LinearLayout.LayoutParams.MATCH_PARENT,\n                        LinearLayout.LayoutParams.WRAP_CONTENT));\n        return view;\n    }\n    // Alice patch end 0026\n\n|}' "$path2"

# 显示菜单时用独立图标行 footer 替换默认 footer。
sed -i '/^        mAppMenu\.show($/i\
        // Alice patch start 0026\
        View footer = mDelegate.buildFooterView(this);\
        if (mIconRowFooterModel != null) {\
            footer = buildIconRowFooterView(mIconRowFooterModel);\
            mIconRowFooterModel = null;              // 每次显示重建\
        }\
        // Alice patch end 0026\
' "$path2"
sed -i 's|^                mDelegate\.buildFooterView(this),$|                // Alice patch start 0026\n                footer,\n                // Alice patch end 0026|' "$path2"
sed -i '/^        if (mModelList == null || mModelList\.isEmpty()) return false;$/,/^        return mModelList\.get(0)\.type != AppMenuItemType\.BUTTON_ROW;$/c\
        // Alice patch start 0026\
        return false;\
        // Alice patch end 0026' "$path2"

# 打开扩展菜单前检查 ToolbarManager 和 coordinator，避免空指针。
sed -i '/^            ExtensionsToolbarCoordinator coordinator =$/,/^            RecordUserAction\.record("MobileMenuExtensionsMenu");$/c\
            // Alice patch start 0026\
            ExtensionsToolbarCoordinator coordinator =\
                    getToolbarManager() == null\
                            ? null\
                            : getToolbarManager().getExtensionsToolbarCoordinator();\
            if (coordinator != null) {\
                coordinator.showExtensionsMenu();\
                RecordUserAction.record("MobileMenuExtensionsMenu");\
            }\
            // Alice patch end 0026' "$path3"

# footer 也参与菜单宽度测量，避免底部按钮行被裁切。
sed -i '/^        int minWidth = context\.getResources()\.getDimensionPixelSize(R\.dimen\.menu_width_min);$/i\
        // Alice patch start 0026\
        if (footer instanceof ViewGroup footerGroup) {\
            int footerWidth = footerGroup.getPaddingLeft() + footerGroup.getPaddingRight();\
            int footerWidthSpec =\
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED);\
            int footerHeightSpec = footerWidthSpec;\
            for (int i = 0; i < footerGroup.getChildCount(); i++) {\
                View footerChild = footerGroup.getChildAt(i);\
                if (footerChild.getVisibility() == View.GONE) continue;\
                footerChild.measure(footerWidthSpec, footerHeightSpec);\
                footerWidth += footerChild.getMeasuredWidth();\
            }\
            contentWidth = Math.max(contentWidth, footerWidth);\
        }\
        // Alice patch end 0026' "$path4"
