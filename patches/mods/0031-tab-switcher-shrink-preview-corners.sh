#!/bin/bash
# 进入标签管理页（Hub）时，缩放动画的预览图圆角是扁的（上游 bug）
#
# 预览图（ShrinkExpandImageView）是用 setScaleX/setScaleY 非等比缩放做动画的，
# 圆角被一起拉伸，看起来变成椭圆。这里让 RoundedCornerImageView 支持 x/y 各自
# 的圆角半径，并在圆角动画里按当前缩放反向补偿，保证视觉上是正圆。

set -e

# 目标文件路径
path1="components/browser_ui/widget/android/java/src/org/chromium/components/browser_ui/widget/RoundedCornerImageView.java"
path2="chrome/browser/hub/android/java/src/org/chromium/chrome/browser/hub/RoundedCornerAnimatorUtil.java"

# 检测是否已应用
if grep -q 'Alice patch start 0031' "$path1"; then
    exit 100
fi

# 1) RoundedCornerImageView：新增按 x/y 分别设置圆角的入口
sed -i '/^    private void refreshState() {$/i\
\
    // Alice patch start 0031\
    /**\
     * Sets the rounded corner radii with independent x/y values for each corner.\
     *\
     * <p>The order is: top start, top end, bottom start, bottom end.\
     */\
    public void setRoundedCornerRadii(\
            float topStartX,\
            float topStartY,\
            float topEndX,\
            float topEndY,\
            float bottomStartX,\
            float bottomStartY,\
            float bottomEndX,\
            float bottomEndY) {\
        float[] radii;\
        if (ViewCompat.getLayoutDirection(this) == ViewCompat.LAYOUT_DIRECTION_LTR) {\
            radii =\
                    new float[] {\
                        topStartX,\
                        topStartY,\
                        topEndX,\
                        topEndY,\
                        bottomEndX,\
                        bottomEndY,\
                        bottomStartX,\
                        bottomStartY\
                    };\
        } else {\
            radii =\
                    new float[] {\
                        topEndX,\
                        topEndY,\
                        topStartX,\
                        topStartY,\
                        bottomStartX,\
                        bottomStartY,\
                        bottomEndX,\
                        bottomEndY\
                    };\
        }\
\
        mRoundedRectangle = new RoundRectShape(radii, null, null);\
    }\
    // Alice patch end 0031' "$path1"

# 2) RoundedCornerAnimatorUtil：圆角按当前 scaleX/scaleY 反向补偿，避免被拉成椭圆
sed -i '/^                    imageView\.setRoundedCorners($/,/^                            currentCorners\[3\]);$/c\
                    // Alice patch start 0031\
                    // 预览图是非等比缩放的，圆角会被拉成椭圆。这里只按 scaleX/scaleY 的比例修形状\
                    // （保持横向半径不变，纵向半径乘 sx/sy），不要改大小：\
                    // ShrinkExpandAnimationData 已经按 1/scale 预缩放过半径了。\
                    float aliceScaleX = Math.max(0.001f, Math.abs(imageView.getScaleX()));\
                    float aliceScaleY = Math.max(0.001f, Math.abs(imageView.getScaleY()));\
                    float aliceRadiusRatio = aliceScaleX / aliceScaleY;\
                    imageView.setRoundedCornerRadii(\
                            currentCorners[0],\
                            currentCorners[0] * aliceRadiusRatio,\
                            currentCorners[1],\
                            currentCorners[1] * aliceRadiusRatio,\
                            currentCorners[2],\
                            currentCorners[2] * aliceRadiusRatio,\
                            currentCorners[3],\
                            currentCorners[3] * aliceRadiusRatio);\
                    // Alice patch end 0031' "$path2"
