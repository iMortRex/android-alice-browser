#!/bin/bash
# Hub 底栏移动后，将其固定在 HubContainerView 底部。

set -e

# 目标文件路径
path1="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
path2="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0027' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# --- HubContainerView.java ---
# 增加固定底部 View 所需的 import。
sed -i '/^import android\.widget\.FrameLayout;$/i\
// Alice patch start 0027\
import android.view.View;\
import android.view.ViewParent;\
// Alice patch end 0027' "$path1"
sed -i '/^import org\.chromium\.ui\.animation\.RunOnNextLayout;$/i\
// Alice patch start 0027\
import org.chromium.build.annotations.Nullable;\
// Alice patch end 0027' "$path1"

# 增加底部固定 View 字段。
sed -i '/^    \/\*\* Default {@link FrameLayout} constructor\. \*\/$/i\
    // Alice patch start 0027\
    private @Nullable View mPinnedBottomView;\
    // Alice patch end 0027\
    ' "$path1"

# 提供设置底部固定 View 的入口。
sed -i '/^    public HubContainerView(Context context) {$/,/^    }$/ s|^    }$|    }\n    // Alice patch start 0027\n\n    public void setPinnedBottomView(@Nullable View view) {\n        mPinnedBottomView = view;\n    }\n    // Alice patch end 0027|' "$path1"

# 每次布局后把目标 View 固定到父容器底部。
sed -i 's|^\( *\)runOnNextLayoutRunnables();$|        // Alice patch start 0027\n        runOnNextLayoutRunnables();\n        pinBottomView();\n    }\n\n    private void pinBottomView() {\n        View pinned = mPinnedBottomView;\n        if (pinned == null) return;\n        ViewParent parent = getParent();\n        if (!(parent instanceof View)) return;\n        View parentView = (View) parent;\n\n        int[] location = new int[2];\n        parentView.getLocationInWindow(location);\n        int parentBottom = location[1] + parentView.getHeight();\n\n        pinned.getLocationInWindow(location);\n        int pinnedBottom = location[1] + pinned.getHeight();\n\n        int delta = parentBottom - pinnedBottom;\n        if (delta != 0) {\n            pinned.setTranslationY(pinned.getTranslationY() + delta);\n        }\n        // Alice patch end 0027|' "$path1"

# --- HubCoordinator.java ---
# 将 Hub 工具栏注册为 HubContainerView 的底部固定 View。
sed -i '/^        hubToolbarView\.setXrSpaceModeObservableSupplier(xrSpaceModeObservableSupplier);$/i\
        // Alice patch start 0027\
        if (mContainerView instanceof HubContainerView) {\
            ((HubContainerView) mContainerView).setPinnedBottomView(hubToolbarView);\
        }\
        // Alice patch end 0027' "$path2"
