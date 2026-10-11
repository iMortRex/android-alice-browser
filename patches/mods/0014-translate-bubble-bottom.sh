#!/bin/bash
# 消息气泡（翻译 bubble）居下

# 检测是否已应用
if grep -q 'params.bottomMargin =' "chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"; then
    exit 100
fi

# 1) 去掉 23dp 的 message_bubble_inset 修正（Lg19;->a() 删 sub-int/2addr v1, p0）
sed -i -e '/^        final Resources res = mContainer.getResources();$/d' \
       -e 's|^        return contentOffset - res.getDimensionPixelOffset(R.dimen.message_bubble_inset);$|        return contentOffset;|' \
    "chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"

# 2) 气泡停在底部，底部留出工具栏高度（Lg19;->b() 的 bottomMargin = max(a(), 56dp)）
#    56dp = R.dimen.toolbar_height_no_shadow = @dimen/default_action_bar_height
sed -i 's|^        params.topMargin = getContainerTopOffset();$|        final Resources res = mContainer.getResources();\n        params.topMargin = getContainerTopOffset();\n        params.bottomMargin =\n                Math.max(\n                        getContainerTopOffset(),\n                        res.getDimensionPixelOffset(R.dimen.toolbar_height_no_shadow));|' \
    "chrome/android/java/src/org/chromium/chrome/browser/messages/MessageContainerCoordinator.java"

# 3) 布局里气泡的重力从顶部改成底部（MessageContainer;->setLayoutParams 强制 0x50 / Gravity.BOTTOM）
#    main.xml 父容器是 CoordinatorLayoutForPointer，另一个是 FrameLayout
sed -i 's#android:layout_gravity="start|top"#android:layout_gravity="start|bottom"#' \
    "chrome/android/java/res_app/layout/main.xml" \
    "chrome/android/java/res_app/layout/main_forked_with_secondary_ui_container.xml"
