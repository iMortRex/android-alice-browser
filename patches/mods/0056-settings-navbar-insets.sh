#!/bin/bash
# 设置页导航栏避让：系统导航栏透明，设置内容延伸到导航栏下并保留底部 inset。

set -e

path1="chrome/android/java/src/org/chromium/chrome/browser/settings/SettingsActivity.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/settings/MainSettings.java"

# 检测是否已应用
if grep -q 'Alice patch start 0056' "$path1"; then
    exit 100
fi

# 设置 Activity 的系统导航栏透明。
sed -i '/^        setContentView(R.layout.settings_activity);$/a\
        // Alice patch start 0056\
        getWindow().setNavigationBarColor(Color.TRANSPARENT);\
        getWindow().setNavigationBarDividerColor(Color.TRANSPARENT);\
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {\
            getWindow().setNavigationBarContrastEnforced(false);\
        }\
        var aliceEdgeToEdgeManager = getEdgeToEdgeManager();\
        if (aliceEdgeToEdgeManager != null) {\
            aliceEdgeToEdgeManager\
                    .getEdgeToEdgeSystemBarColorHelper()\
                    .setNavigationBarColor(Color.TRANSPARENT);\
            aliceEdgeToEdgeManager\
                    .getEdgeToEdgeSystemBarColorHelper()\
                    .setNavigationBarDividerColor(Color.TRANSPARENT);\
        }\
        // Alice patch end 0056' "$path1"

# 设置内容延伸到导航栏下面。
sed -i '/^        setContentView(R.layout.settings_activity);$/a\
        // Alice patch start 0056\
        View aliceEdgeContent = getContentView();\
        aliceEdgeContent.getViewTreeObserver().addOnPreDrawListener(\
                new android.view.ViewTreeObserver.OnPreDrawListener() {\
                    @Override\
                    public boolean onPreDraw() {\
                        if (aliceEdgeContent.getPaddingBottom() == 0) return true;\
                        aliceEdgeContent.setPadding(\
                                aliceEdgeContent.getPaddingLeft(),\
                                aliceEdgeContent.getPaddingTop(),\
                                aliceEdgeContent.getPaddingRight(),\
                                0);\
                        return false;\
                    }\
                });\
        // Alice patch end 0056\
' "$path1"

# 设置列表关闭裁剪，为底部导航栏 inset 留出绘制空间。
sed -i '/^import androidx\.lifecycle\.Lifecycle;$/a\
// Alice patch start 0056\
import androidx.core.view.WindowInsetsCompat;\
// Alice patch end 0056
' "$path2"
# 修改对应源码以完成本补丁功能。
sed -i '/^        super.onViewCreated(view, savedInstanceState);$/a\
        // Alice patch start 0056\
        getListView().setClipToPadding(false);\
        getListView().addOnLayoutChangeListener(\
                (v, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {\
                    android.view.WindowInsets aliceWindowInsets = v.getRootWindowInsets();\
                    int bottomInset = 0;\
                    if (aliceWindowInsets != null) {\
                        WindowInsetsCompat insets =\
                                WindowInsetsCompat.toWindowInsetsCompat(aliceWindowInsets, v);\
                        bottomInset =\
                                insets.getInsets(WindowInsetsCompat.Type.navigationBars())\
                                        .bottom;\
                    }\
                    if (v.getPaddingBottom() != bottomInset) {\
                        v.setPadding(\
                                v.getPaddingLeft(),\
                                v.getPaddingTop(),\
                                v.getPaddingRight(),\
                                bottomInset);\
                    }\
                });\
        // Alice patch end 0056\
' "$path2"
