#!/bin/bash
# 标签页分组按钮/工具栏移到底部

set -e

# 目标文件路径
path1="chrome/browser/hub/internal/android/res/layout/hub_layout.xml"
path2="chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"
path3="chrome/browser/hub/internal/android/res/values/dimens.xml"
path4="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"
path5="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"
path6="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubToolbarView.java"
path7="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
path8="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0027' "$path1"; then
    exit 100
fi

# --- hub_layout.xml：工具条挪到底部 ---
# 1) 顶部留白改成底部留白（marker 放元素外的上下行）
sed -i '/^    <LinearLayout$/{N;/\n      android:id="@+id\/hub_pane_host_container"$/i\
<!-- Alice patch start 0027 -->
}' "$path1"
sed -i 's|^\( *\)android:layout_marginTop="@dimen/toolbar_height_no_shadow">$|\1android:layout_marginBottom="@dimen/toolbar_height_no_shadow">\n\1<!-- Alice patch end 0027 -->|' "$path1"
# 2) 底部再插一份工具栏（整元素，marker 在元素外）
sed -i '/^    <include layout="@layout\/hub_toolbar_layout" \/>$/i\
<!-- Alice patch start 0027 -->\
    <FrameLayout\
        android:layout_width="match_parent"\
        android:layout_height="wrap_content"\
        android:layout_gravity="bottom">\
      <include layout="@layout/hub_toolbar_layout" />\
    </FrameLayout>\
<!-- Alice patch end 0027 -->\
' "$path1"

# --- hub_toolbar_layout.xml：按钮重排（结构搬动，标签内不能放注释，故不加 marker）---
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

# --- dimens.xml：搜索框高度/间距改 0 ---
sed -i 's|^\( *\)<dimen name="hub_search_box_height">40dp</dimen>$|\1<!-- Alice patch start 0027 -->\n\1<dimen name="hub_search_box_height">0dp</dimen>\n\1<!-- Alice patch end 0027 -->|' "$path3"
sed -i 's|^\( *\)<dimen name="hub_search_box_vertical_margin">8dp</dimen>$|\1<!-- Alice patch start 0027 -->\n\1<dimen name="hub_search_box_vertical_margin">0dp</dimen>\n\1<!-- Alice patch end 0027 -->|' "$path3"

# --- HubManagerImpl.java ---
sed -i '/^import android\.view\.View;$/a\
// Alice patch start 0027\
import android.view.ViewGroup;\
import android.view.ViewParent;\
// Alice patch end 0027' "$path4"
sed -i 's|^\( *\)params\.topMargin = mStatusIndicatorHeight + (isVerticalTabsOn ? 0 : mAppHeaderHeight);$|\1// Alice patch start 0027\n\1int searchBoxGap =\n\1        mHubContainerView\n\1                .getResources()\n\1                .getDimensionPixelSize(R.dimen.hub_search_box_gap);\n\1params.topMargin = mStatusIndicatorHeight - searchBoxGap;\n\1// Alice patch end 0027|' "$path4"
sed -i 's|^\( *\)mHubContainerView\.setPadding(0, isVerticalTabsOn ? mAppHeaderHeight : 0, 0, 0);$|\1// Alice patch start 0027\n\1mHubContainerView.setPadding(0, 0, 0, 0);\n\n\1ViewParent parent = mHubContainerView.getParent();\n\1if (parent instanceof ViewGroup) {\n\1    ((ViewGroup) parent).setClipChildren(false);\n\1    ((ViewGroup) parent).setClipToPadding(false);\n\1}\n\1// Alice patch end 0027|' "$path4"

# --- ShrinkExpandAnimator.java ---
sed -i '/^                        - Math\.round(mInitialRect\.top + (1\.0 - scaleY) \* initialRectHeight \/ 2\.0));$/a\
        // Alice patch start 0027\
        final float translationY =\
        (float) rect.top\
                - Math.round(mInitialRect.top + (1.0 - scaleY) * initialRectHeight / 2.0);\
        final int searchBoxGap =\
                Math.round(56 * mView.getResources().getDisplayMetrics().density);\
        mView.setTranslationY(translationY + searchBoxGap);\
        // Alice patch end 0027' "$path5"

# --- HubToolbarView.java ---
sed -i 's@^\( *\)params\.gravity = Gravity\.CENTER;$@\1// Alice patch start 0027\n\1params.gravity = Gravity.CENTER_VERTICAL | Gravity.START;\n\1// Alice patch end 0027@' "$path6"

# --- HubContainerView.java ---
sed -i '/^import android\.widget\.FrameLayout;$/i\
// Alice patch start 0027\
import android.view.View;\
import android.view.ViewParent;\
// Alice patch end 0027' "$path7"
sed -i '/^import org\.chromium\.ui\.animation\.RunOnNextLayout;$/i\
// Alice patch start 0027\
import org.chromium.build.annotations.Nullable;\
// Alice patch end 0027' "$path7"
sed -i '/^    \/\*\* Default {@link FrameLayout} constructor\. \*\/$/i\
    // Alice patch start 0027\
    private @Nullable View mPinnedBottomView;\
    // Alice patch end 0027\
' "$path7"
sed -i '/^    public HubContainerView(Context context) {$/,/^    }$/ s|^    }$|    }\n    // Alice patch start 0027\n\n    public void setPinnedBottomView(@Nullable View view) {\n        mPinnedBottomView = view;\n    }\n    // Alice patch end 0027|' "$path7"
sed -i 's|^\( *\)runOnNextLayoutRunnables();$|        // Alice patch start 0027\n        runOnNextLayoutRunnables();\n        pinBottomView();\n    }\n\n    private void pinBottomView() {\n        View pinned = mPinnedBottomView;\n        if (pinned == null) return;\n        ViewParent parent = getParent();\n        if (!(parent instanceof View)) return;\n        View parentView = (View) parent;\n\n        int[] location = new int[2];\n        parentView.getLocationInWindow(location);\n        int parentBottom = location[1] + parentView.getHeight();\n\n        pinned.getLocationInWindow(location);\n        int pinnedBottom = location[1] + pinned.getHeight();\n\n        int delta = parentBottom - pinnedBottom;\n        if (delta != 0) {\n            pinned.setTranslationY(pinned.getTranslationY() + delta);\n        }\n        // Alice patch end 0027|' "$path7"
printf '%s' "$(cat "$path7")" > "$path7"

# --- HubCoordinator.java ---
sed -i '/^        hubToolbarView\.setXrSpaceModeObservableSupplier(xrSpaceModeObservableSupplier);$/i\
        // Alice patch start 0027\
        if (mContainerView instanceof HubContainerView) {\
            ((HubContainerView) mContainerView).setPinnedBottomView(hubToolbarView);\
        }\
        // Alice patch end 0027' "$path8"
