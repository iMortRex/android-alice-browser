#!/bin/bash
# Hub 预览动画：底栏工具栏已经显示在快照中，不再叠加纯色动画遮挡。

set -e

path1="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandHubLayoutAnimatorProvider.java"

# 检测是否已应用
if grep -q 'Alice patch start 0066' "$path1"; then
    exit 100
fi

# 底置工具栏快照已包含工具栏区域，动画高度不再额外叠加纯色底栏。
sed -i '/^        int aliceToolbarHeight = toolbarView == null ? 0 : toolbarView.getHeight();$/,/^                                : Math.max(0, bottomControlsHeight - bottomMargin);$/c\
        // Alice patch start 0066\
        boolean aliceUseBottomToolbarGeometry =\
                toolbarView != null \&\& !animationData.isTopToolbar();\
        int animatingHeight =\
                mAnimationType == HubLayoutAnimationType.EXPAND_NEW_TAB\
                                || animationData.isTopToolbar()\
                        ? 0\
                        : aliceUseBottomToolbarGeometry\
                                ? 0\
                                : Math.max(0, bottomControlsHeight - bottomMargin);\
        // Alice patch end 0066' "$path1"
