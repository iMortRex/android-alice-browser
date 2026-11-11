#!/bin/bash
# Hub 底栏布局：把工具栏按钮移到底部，并处理移动后产生的搜索框留白偏移。

set -e

path1="chrome/browser/hub/internal/android/res/layout/hub_layout.xml"
path2="chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"
path3="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"
path4="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"
path5="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubToolbarView.java"

# 检测是否已应用
if grep -q 'Alice patch start 0051' "$path1"; then
    exit 100
fi

# 将 Hub 内容区的顶部工具栏留白改成底部工具栏留白。
sed -i '/^    <LinearLayout$/{N;/\n      android:id="@+id\/hub_pane_host_container"$/i\
<!-- Alice patch start 0051 -->
}' "$path1"
sed -i 's|^\( *\)android:layout_marginTop="@dimen/toolbar_height_no_shadow">$|\1android:layout_marginBottom="@dimen/toolbar_height_no_shadow">\n\1<!-- Alice patch end 0051 -->|' "$path1"

# 将顶部工具栏替换为底部唯一工具栏。
sed -i '/^    <include layout="@layout\/hub_toolbar_layout" \/>$/c\
<!-- Alice patch start 0051 -->\
    <FrameLayout\
        android:layout_width="match_parent"\
        android:layout_height="wrap_content"\
        android:layout_gravity="bottom">\
      <include layout="@layout/hub_toolbar_layout" />\
    </FrameLayout>\
<!-- Alice patch end 0051 -->' "$path1"

# 包裹新建标签按钮，重排底部工具栏按钮。
sed -i '\|^          app:tint="@color/default_icon_color_tint_list"/>$|a\
      </LinearLayout>' "$path2"
sed -i '\|^        <Button$|i\
      <FrameLayout\
          android:layout_width="wrap_content"\
          android:layout_height="match_parent"\
          android:layout_gravity="center">' "$path2"
sed -i '\#^          android:layout_gravity="start|center_vertical"$#c\
          android:layout_gravity="center"' "$path2"
sed -i '/^          style="?attr\/newTabButtonStyle"\/>$/,/^      <\/LinearLayout>$/ s|^      </LinearLayout>$|      </FrameLayout>|' "$path2"
sed -i '\#^        android:layout_gravity="center_horizontal|bottom"$#c\
        android:layout_gravity="start|center_vertical"\
        android:layout_marginStart="16dp"' "$path2"
sed -i '\|^        android:layout_gravity="end" >$|i\
        android:layout_marginEnd="16dp"' "$path2"

# Hub 容器增加布局所需 import。
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0051\
import android.view.ViewGroup;\
import android.view.ViewParent;\
// Alice patch end 0051' "$path3"

# 按横竖屏重新计算 Hub 容器顶部 margin。
sed -i 's|^\( *\)params\.topMargin = mStatusIndicatorHeight + (isVerticalTabsOn ? 0 : mAppHeaderHeight);$|\1// Alice patch start 0051\n\1int searchBoxGap =\n\1        mHubContainerView\n\1                .getResources()\n\1                .getDimensionPixelSize(R.dimen.hub_search_box_gap);\n\1boolean aliceLandscape;\n\1if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {\n\1    android.graphics.Rect bounds =\n\1            mActivity\n\1                    .getWindowManager()\n\1                    .getCurrentWindowMetrics()\n\1                    .getBounds();\n\1    aliceLandscape = bounds.width() > bounds.height();\n\1} else {\n\1    android.content.res.Configuration configuration =\n\1            mHubContainerView.getResources().getConfiguration();\n\1    aliceLandscape = configuration.screenWidthDp > configuration.screenHeightDp;\n\1}\n\1params.topMargin =\n\1        aliceLandscape ? mStatusIndicatorHeight : mStatusIndicatorHeight - searchBoxGap;\n\1// Alice patch end 0051|' "$path3"

# 清除 Hub 容器顶部 padding，并允许底部工具栏越界绘制。
sed -i 's|^\( *\)mHubContainerView\.setPadding(0, isVerticalTabsOn ? mAppHeaderHeight : 0, 0, 0);$|\1// Alice patch start 0051\n\1mHubContainerView.setPadding(0, 0, 0, 0);\n\n\1ViewParent parent = mHubContainerView.getParent();\n\1if (parent instanceof ViewGroup) {\n\1    ((ViewGroup) parent).setClipChildren(false);\n\1    ((ViewGroup) parent).setClipToPadding(false);\n\1}\n\1// Alice patch end 0051|' "$path3"

# 注册配置变化回调，旋转后重新计算 Hub 容器顶部 margin。
sed -i '/^    private int mAppHeaderHeight;$/a\
    // Alice patch start 0051\
    private final android.content.ComponentCallbacks mComponentCallbacks =\
            new android.content.ComponentCallbacks() {\
                @Override\
                public void onConfigurationChanged(\
                        android.content.res.Configuration newConfig) {\
                    mHubContainerView.post(\
                            HubManagerImpl.this::updateContainerLayoutParams);\
                }\
\
                @Override\
                public void onLowMemory() {}\
            };\
    // Alice patch end 0051' "$path3"

# 初始化时注册配置变化回调。
sed -i '/^        mDefaultPaneId = defaultPaneId;$/a\
        // Alice patch start 0051\
        mActivity.registerComponentCallbacks(mComponentCallbacks);\
        // Alice patch end 0051' "$path3"

# 销毁时注销配置变化回调。
sed -i '/^    public void destroy() {$/a\
        // Alice patch start 0051\
        mActivity.unregisterComponentCallbacks(mComponentCallbacks);\
        // Alice patch end 0051' "$path3"

# 底部工具栏移动后，收缩展开动画补上 56dp 搜索框留白。
sed -i '/^                        - Math\.round(mInitialRect\.top + (1\.0 - scaleY) \* initialRectHeight \/ 2\.0));$/a\
        // Alice patch start 0051\
        final float translationY =\
        (float) rect.top\
                - Math.round(mInitialRect.top + (1.0 - scaleY) * initialRectHeight / 2.0);\
        final int searchBoxGap =\
                Math.round(56 * mView.getResources().getDisplayMetrics().density);\
        final boolean aliceLandscape =\
                mView.getRootView().getWidth() > mView.getRootView().getHeight();\
        final int aliceSearchBoxGap =\
                mSearchBoxGapEnabled \&\& !aliceLandscape ? searchBoxGap : 0;\
        mView.setTranslationY(translationY + aliceSearchBoxGap);\
        // Alice patch end 0051' "$path4"

# 底栏按钮改为从左侧垂直居中排列。
sed -i 's@^\( *\)params\.gravity = Gravity\.CENTER;$@\1// Alice patch start 0051\n\1params.gravity = Gravity.CENTER_VERTICAL | Gravity.START;\n\1// Alice patch end 0051@' "$path5"
