#!/bin/bash
# 禁用 mini origin bar；输入法显示或收起时始终保留完整工具栏

set -e

# 目标文件路径
path1="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/MiniOriginBarController.java"
path2="chrome/android/java/src/org/chromium/chrome/browser/toolbar/ToolbarManager.java"

# 检测是否已应用
if grep -q 'Alice patch start 0023' "$path1"; then
    exit 100
fi

# mini origin 状态机始终停留在 NOT_READY，表单聚焦和输入法事件都不会改变
# 地址栏尺寸、缩放、位置或工具栏可见性。
sed -i '/^    private @MiniOriginState int getNewMiniOriginState(@MiniOriginEvent int miniOriginEvent) {$/,/^    }$/c\
    private @MiniOriginState int getNewMiniOriginState(@MiniOriginEvent int miniOriginEvent) {\
        // Alice patch start 0023\
        return MiniOriginState.NOT_READY;\
        // Alice patch end 0023\
    }' "$path1"

# 状态转换本身也不再执行，避免任何旧状态进入 mini origin 动画。
sed -i '/^    private void transitionToNewState(@MiniOriginState int newMiniOriginState) {$/,/^    }$/c\
    private void transitionToNewState(@MiniOriginState int newMiniOriginState) {\
        // Alice patch start 0023\
        // Mini origin is disabled; the normal toolbar never transitions.\
        // Alice patch end 0023\
    }' "$path1"

# IME animation listener 仅在这里被允许启动。直接返回 false，
# 可阻止 controlContainerTranslationSupplier 被逐帧写入键盘位移。
sed -i '/^    private boolean waitingForImeAnimationToStart() {$/,/^    }$/c\
    private boolean waitingForImeAnimationToStart() {\
        // Alice patch start 0023\
        return false;\
        // Alice patch end 0023\
    }' "$path1"

# 不创建 MiniOriginBarController，避免注册 IME listener、layout listener
# 或写入 controlContainerTranslationSupplier。
sed -i '/^        mMiniOriginBarController =$/,/^                        this::isUrlBarFocused);$/c\
        // Alice patch start 0023\
        // Mini origin is disabled; keep the normal bottom toolbar controller-free.\
        mMiniOriginBarController = null;\
        // Alice patch end 0023' "$path2"
