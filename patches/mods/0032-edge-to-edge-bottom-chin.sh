#!/bin/bash
# 底部 edge-to-edge chin：启用 3 键导航、从 Blink 视口排除 chin，并保留 Hub 底部高度。

set -e

path1="chrome/browser/ui/android/edge_to_edge/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeUtils.java"
path2="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerImpl.java"
path3="chrome/browser/ui/android/edge_to_edge/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeControllerCreator.java"
path4="chrome/browser/browser_controls/android/java/src/org/chromium/chrome/browser/browser_controls/BottomControlsStacker.java"
path5="chrome/browser/ui/android/edge_to_edge/internal/java/src/org/chromium/chrome/browser/ui/edge_to_edge/EdgeToEdgeBottomChinMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0032' "$path1"; then
    exit 100
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/../../alice-patch-transaction.sh"

# 3 键导航也启用底部 edge-to-edge。
sed -i 's|^        return !DeviceInfo\.isAutomotive() \&\& !hasTappableNavigationBar(activity\.getWindow());$|        // Alice patch start 0032\n        return !DeviceInfo.isAutomotive();\n        // Alice patch end 0032|' "$path1"

# 底部 chin 支持检查改为按设备配置判断。
sed -i '/^    static boolean isBottomChinSupportedByConfiguration(/,/^    }$/c\
    static boolean isBottomChinSupportedByConfiguration(\
            Activity activity, InsetObserver insetObserver) {\
        // Alice patch start 0032\
        return EdgeToEdgeUtils.isEdgeToEdgeBottomChinSupportedByDevice(activity);\
        // Alice patch end 0032\
    }' "$path2"

# 移除仅允许手势导航的提前退出逻辑。
sed -i '/^        \/\/ Exit early if there is a tappable navbar (3-button) as bottom edge to edge should not$/,/^        }$/c\
        // Alice patch start 0032\
        // 3-button navigation is handled by the patched configuration check.\
        // Alice patch end 0032' "$path2"

# 是否为底部绘制统一使用新的 edge-to-edge 判断。
sed -i '/^        boolean shouldDrawToBottomEdge =$/,/^                        pageOptedIntoBottomEdgeToEdge, currentLayoutType, mSystemInsets.bottom);$/c\
        // Alice patch start 0032\
        boolean shouldDrawToBottomEdge =\
                !mActivity.isInMultiWindowMode()\
                        \&\& EdgeToEdgeUtils.shouldDrawToBottomEdge(\
                                pageOptedIntoBottomEdgeToEdge,\
                                currentLayoutType,\
                                mSystemInsets.bottom);\
        // Alice patch end 0032' "$path2"

# 移除只接受手势导航 insets 的配置保护。
sed -i '/^                && EdgeToEdgeUtils\.doAllInsetsIndicateGestureNavigation(insets)$/c\
// Alice patch start 0032\
// Removed the gesture-only configuration guard.\
// Alice patch end 0032' "$path3"

# bottom controls 高度不计入 chin，避免 Blink 视口重复避让。
sed -i '/^        mBrowserControlsSizer\.setBottomControlsHeight(mTotalHeight, mTotalMinHeight);$/c\
        // Alice patch start 0032\
        int aliceChinHeight = 0;\
        BottomControlsLayer aliceChin = mLayers.get(LayerType.BOTTOM_CHIN);\
        if (aliceChin != null && mLayerVisibilities.get(LayerType.BOTTOM_CHIN)) {\
            aliceChinHeight = aliceChin.getHeight();\
        }\
        mBrowserControlsSizer.setBottomControlsHeight(\
                Math.max(0, mTotalHeight - aliceChinHeight), mTotalMinHeight);\
        // Alice patch end 0032' "$path4"

# 首次布局没有 controls offset 时按 resting offset 主动重排一次。
sed -i '/^        if (mBrowserControlsSizer\.offsetOverridden()) {$/,/^        }$/c\
        // Alice patch start 0032\
        if (mBrowserControlsSizer.offsetOverridden()) {\
            repositionLayers(\
                    mBrowserControlsSizer.getBottomControlOffset(),\
                    mBrowserControlsSizer.getBottomControlsMinHeightOffset(),\
                    animate,\
                    isVisibilityForced());\
        } else {\
            repositionLayers(\
                    /* bottomOffset= */ 0,\
                    /* bottomControlsMinHeightOffset= */ 0,\
                    /* animated= */ false,\
                    isVisibilityForced());\
        }\
        // Alice patch end 0032' "$path4"

# 非 edge-to-edge 状态下 chin 不占高度。
sed -i 's|^        int newHeight = mEdgeToEdgeBottomInsetPx;$|        // Alice patch start 0032\n        int newHeight = mIsDrawingToEdge ? mEdgeToEdgeBottomInsetPx : 0;\n        // Alice patch end 0032|' "$path5"

# Hub 布局也保留底部 chin 高度，避免进入和退出动画高度变化。
sed -i 's|^\( *\)layoutType == LayoutType.BROWSING$|\1layoutType == LayoutType.BROWSING\n\1// Alice patch start 0032\n\1        \|\| layoutType == LayoutType.HUB\n\1// Alice patch end 0032|' "$path1"
