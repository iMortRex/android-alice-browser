#!/bin/bash
# 标签页分组按钮/工具栏移到底部

set -e

# 目标文件路径
path1="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
path2="chrome/browser/hub/internal/android/res/layout/hub_layout.xml"
path3="chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"
path4="chrome/browser/hub/internal/android/res/values/dimens.xml"
path5="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"
path6="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"
path7="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubToolbarView.java"
path8="chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"

# 检测是否已应用
if grep -q 'Alice patch start' "$path1" "$path2" "$path3" "$path4" "$path5" "$path6" "$path7" "$path8"; then
    exit 100
fi\

# ---- hub_layout.xml ----
sed -i '\|^      android:layout_marginTop="@dimen/toolbar_height_no_shadow">$|c\
<!-- Alice patch start -->\
      android:layout_marginBottom="@dimen/toolbar_height_no_shadow">\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_layout.xml"

sed -i '\|^    <include layout="@layout/hub_toolbar_layout" />$|i\
<!-- Alice patch start -->\
    <FrameLayout\
        android:layout_width="match_parent"\
        android:layout_height="wrap_content"\
        android:layout_gravity="bottom">\
      <include layout="@layout/hub_toolbar_layout" />\
    </FrameLayout>\
\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_layout.xml"

# ---- hub_toolbar_layout.xml ----

sed -i '\|^          app:tint="@color/default_icon_color_tint_list"/>$|a\
<!-- Alice patch start -->\
      </LinearLayout>\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"

sed -i '\|^        <Button$|i\
<!-- Alice patch start -->\
      <FrameLayout\
          android:layout_width="wrap_content"\
          android:layout_height="match_parent"\
          android:layout_gravity="center">\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"

sed -i '\#^          android:layout_gravity="start|center_vertical"$#c\
<!-- Alice patch start -->\
          android:layout_gravity="center"\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"

sed -i '\|^          style="?attr/newTabButtonStyle"/>$|,\|^      </LinearLayout>$| s|^      </LinearLayout>$|      </FrameLayout>|' "chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"
sed -i '\#^        android:layout_gravity="center_horizontal|bottom"$#c\
<!-- Alice patch start -->\
        android:layout_gravity="start|center_vertical"\
        android:layout_marginStart="16dp"\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"

sed -i '\|^        android:layout_gravity="end" >$|i\
<!-- Alice patch start -->\
        android:layout_marginEnd="16dp"\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/layout/hub_toolbar_layout.xml"

# ---- dimens.xml ----

sed -i '/^    <dimen name="hub_search_box_height">40dp<\/dimen>$/,/^    <dimen name="hub_search_box_vertical_margin">8dp<\/dimen>$/c\
<!-- Alice patch start -->\
    <dimen name="hub_search_box_height">0dp</dimen>\
    <dimen name="hub_search_box_vertical_margin">0dp</dimen>\
<!-- Alice patch end -->' "chrome/browser/hub/internal/android/res/values/dimens.xml"

# ---- HubManagerImpl.java ----

sed -i '\|^import android\.widget\.FrameLayout\.LayoutParams;$|i\
// Alice patch start\
import android.view.ViewGroup;\
import android.view.ViewParent;\
// Alice patch end' "chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"

sed -i '\|^        params\.topMargin = mStatusIndicatorHeight + (isVerticalTabsOn ? 0 : mAppHeaderHeight);$|c\
// Alice patch start\
        int searchBoxGap =\
                mHubContainerView\
                        .getResources()\
                        .getDimensionPixelSize(R.dimen.hub_search_box_gap);\
        params.topMargin = mStatusIndicatorHeight - searchBoxGap;\
// Alice patch end' "chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"

sed -i '\|^        mHubContainerView\.setPadding(0, isVerticalTabsOn ? mAppHeaderHeight : 0, 0, 0);$|c\
// Alice patch start\
        mHubContainerView.setPadding(0, 0, 0, 0);\
\
        ViewParent parent = mHubContainerView.getParent();\
        if (parent instanceof ViewGroup) {\
            ((ViewGroup) parent).setClipChildren(false);\
            ((ViewGroup) parent).setClipToPadding(false);\
        }\
// Alice patch end' "chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubManagerImpl.java"

# ---- ShrinkExpandAnimator.java ----

sed -i '\|^                        - Math\.round(mInitialRect\.top + (1\.0 - scaleY) \* initialRectHeight / 2\.0));$|a\
// Alice patch start\
        final float translationY =\
        (float) rect.top\
                - Math.round(mInitialRect.top + (1.0 - scaleY) * initialRectHeight / 2.0);\
        final int searchBoxGap =\
                Math.round(56 * mView.getResources().getDisplayMetrics().density);\
        mView.setTranslationY(translationY + searchBoxGap);\
// Alice patch end' "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/ShrinkExpandAnimator.java"

# ---- HubToolbarView.java ----

sed -i '\|^                params\.gravity = Gravity\.CENTER;$|c\
// Alice patch start\
                params.gravity = Gravity.CENTER_VERTICAL | Gravity.START;\
// Alice patch end' "chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubToolbarView.java"

# ---- HubContainerView.java ----

sed -i '\|^import android\.widget\.FrameLayout;$|i\
// Alice patch start\
import android.view.View;\
import android.view.ViewParent;\
// Alice patch end' "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"

sed -i '\|^import org\.chromium\.ui\.animation\.RunOnNextLayout;$|i\
// Alice patch start\
import org.chromium.build.annotations.Nullable;\
// Alice patch end' "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"

sed -i '\|^    /\*\* Default {@link FrameLayout} constructor\. \*/$|i\
// Alice patch start\
    private @Nullable View mPinnedBottomView;\
\
// Alice patch end' "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"

sed -i '/^    public HubContainerView(Context context) {$/,/^    }$/ s|^    }$|    }\n\n    public void setPinnedBottomView(@Nullable View view) {\n        mPinnedBottomView = view;\n    }|' "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
sed -i '\|^        runOnNextLayoutRunnables();$|a\
// Alice patch start\
        pinBottomView();\
    }\
\
    private void pinBottomView() {\
        View pinned = mPinnedBottomView;\
        if (pinned == null) return;\
        ViewParent parent = getParent();\
        if (!(parent instanceof View)) return;\
        View parentView = (View) parent;\
\
        int[] location = new int[2];\
        parentView.getLocationInWindow(location);\
        int parentBottom = location[1] + parentView.getHeight();\
\
        pinned.getLocationInWindow(location);\
        int pinnedBottom = location[1] + pinned.getHeight();\
\
        int delta = parentBottom - pinnedBottom;\
        if (delta != 0) {\
            pinned.setTranslationY(pinned.getTranslationY() + delta);\
        }\
// Alice patch end' "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"
# 该文件末尾没有换行符，保持一致
printf '%s' "$(cat "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java")" > "chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/HubContainerView.java"

# ---- HubCoordinator.java ----

sed -i '\|^        hubToolbarView\.setXrSpaceModeObservableSupplier(xrSpaceModeObservableSupplier);$|i\
// Alice patch start\
        if (mContainerView instanceof HubContainerView) {\
            ((HubContainerView) mContainerView).setPinnedBottomView(hubToolbarView);\
        }\
// Alice patch end' "chrome/browser/hub/internal/android/java/src/org/chromium/chrome/browser/hub/HubCoordinator.java"

