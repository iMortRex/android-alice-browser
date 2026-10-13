#!/bin/bash
# 菜单：图标行改语义 + 钉在菜单底部；扩展菜单空指针保护

set -e

# 目标文件路径
path1="chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedAppMenuPropertiesDelegate.java"
path2="chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenuHandlerImpl.java"
path3="chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java"
path4="chrome/browser/ui/android/appmenu/internal/java/src/org/chromium/chrome/browser/ui/appmenu/AppMenu.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1"; then
    exit 100
fi

# 1) 图标行：去掉后退/页面信息，下载改为「下载内容」、新增「扩展」
sed -i '/^            if (ChromeFeatureList\.sThreeDotMenuBackButton\.isEnabled()) {$/,/^            }$/d' "$path1"
sed -i '/^            iconModels\.add(buildDownloadActionModel(currentTab));$/d' "$path1"
sed -i '/^            if (!ChromeFeatureList\.sThreeDotMenuBackButton\.isEnabled()) {$/,/^$/d' "$path1"
sed -i '/^            iconModels\.add(buildBookmarkActionModel(currentTab));$/a\
            // Alice patch start\
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
            // Alice patch end' "$path1"

# 2) AppMenuHandlerImpl：import
sed -i '/^import android\.view\.ViewGroup;$/a\
import android.view.LayoutInflater;' "$path2"
sed -i '/^import android\.widget\.ListView;$/a\
import android.widget.LinearLayout;' "$path2"
sed -i '/^import org\.chromium\.ui\.modelutil\.PropertyModel;$/a\
import org.chromium.ui.modelutil.PropertyModelChangeProcessor;' "$path2"

# 3) AppMenuHandlerImpl：字段
sed -i '/^    private final Context mContext;$/i\
    private @Nullable PropertyModel mIconRowFooterModel;' "$path2"

# 4) AppMenuHandlerImpl：摘出图标行模型
sed -i '/^        setupModelForHighlightAndClick(mModelList, mHighlightMenuId, this);$/a\
        mIconRowFooterModel = extractIconRowModel();' "$path2"

# 5) AppMenuHandlerImpl：新增两个方法
sed -i '/^    \/\*\*$/{N;/A means of reporting an exception without crashing\./s|^|    // Alice patch start\n    /** 把 BUTTON_ROW（图标行）从菜单模型里摘出来，留作底部固定 footer。 */\n    private @Nullable PropertyModel extractIconRowModel() {\n        if (mModelList == null) return null;\n        for (int i = 0; i < mModelList.size(); i++) {\n            ListItem item = mModelList.get(i);\n            if (item.type != AppMenuItemType.BUTTON_ROW) continue;\n            PropertyModel model = item.model;\n            mModelList.removeAt(i);\n            return model;\n        }\n        return null;\n    }\n\n    /** 用图标行模型生成一份独立视图（不随列表滚动，钉在菜单底部）。 */\n    private View buildIconRowFooterView(PropertyModel model) {\n        ViewGroup view =\n                (ViewGroup)\n                        LayoutInflater.from(mContext)\n                                .inflate(R.layout.icon_row_menu_item, /* root= */ null);\n        PropertyModelChangeProcessor.create(\n                model, view, AppMenuItemViewBinder::bindIconRowItem,\n                /* performInitialBind= */ true);\n        // 关键：root 传 null 时 inflate 不会带 LayoutParams，不设的话\n        // LinearLayout 默认 WRAP_CONTENT，而里面 5 个按钮是 weight=1 + width=0dp，\n        // 会导致整行宽度为 0（按钮全看不见）。\n        view.setLayoutParams(\n                new LinearLayout.LayoutParams(\n                        LinearLayout.LayoutParams.MATCH_PARENT,\n                        LinearLayout.LayoutParams.WRAP_CONTENT));\n        return view;\n    }\n    // Alice patch end\n\n|}' "$path2"

# 6) AppMenuHandlerImpl：底部 footer
sed -i '/^        mAppMenu\.show($/i\
        // Alice patch start\
        View footer = mDelegate.buildFooterView(this);\
        if (mIconRowFooterModel != null) {\
            footer = buildIconRowFooterView(mIconRowFooterModel);\
            mIconRowFooterModel = null;              // 每次显示重建\
        }\
        // Alice patch end\
' "$path2"
sed -i 's|^                mDelegate\.buildFooterView(this),$|                footer,|' "$path2"
sed -i '/^        if (mModelList == null || mModelList\.isEmpty()) return false;$/,/^        return mModelList\.get(0)\.type != AppMenuItemType\.BUTTON_ROW;$/c\
        // Alice patch start\
        return false;\
        // Alice patch end' "$path2"

# 7) ChromeTabbedActivity：扩展菜单空指针保护
sed -i '/^            ExtensionsToolbarCoordinator coordinator =$/,/^            RecordUserAction\.record("MobileMenuExtensionsMenu");$/c\
            // Alice patch start\
            ExtensionsToolbarCoordinator coordinator =\
                    getToolbarManager() == null\
                            ? null\
                            : getToolbarManager().getExtensionsToolbarCoordinator();\
            if (coordinator != null) {\
                coordinator.showExtensionsMenu();\
                RecordUserAction.record("MobileMenuExtensionsMenu");\
            }\
            // Alice patch end' "$path3"

# 8) AppMenu：底部 footer 也参与宽度测量
sed -i '/^        int contentWidth = itemWidth + bgPadding\.left + bgPadding\.right;$/i\
        // Alice patch start\
        if (footer != null) {\
            footer.measure(\
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),\
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED));\
            itemWidth = Math.max(itemWidth, footer.getMeasuredWidth());\
        }\
        // Alice patch end' "$path4"
