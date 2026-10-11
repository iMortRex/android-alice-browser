#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM="$SCRIPT_DIR/chromium/src"
RES_DIR="$SCRIPT_DIR/res"

# 前景层渲染完后的整体缩放百分比（100 = 原样不缩）。
# 现在前景内容占画布约 81.5%，自适应图标官方安全区是 66.7%，所以：
#   82  -> 内容约 67%（正好落在安全区）
#   88  -> 约 72%
#   100 -> 81.5%（原样，个别启动器遮罩会裁到）
# 注意：这是"整层等比缩放 + 居中"，SVG 自己的留白比例保留（不做 trim）。
FG_SCALE=60

# 确保 depot_tools 在 PATH
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

cd "$CHROMIUM"

# 分层图标：background.svg -> 背景层，foreground.svg -> 前景层，icon.svg -> 方形图标（app_icon）。
# 一律按 SVG 原样渲染（不采样、不 tint、不改 alpha），只在渲染后按 FG_SCALE 等比缩前景。
cp "$RES_DIR/drawable/themed_app_icon.xml" chrome/android/java/res_alice_base/drawable/themed_app_icon.xml

for icon in $(find chrome/android/java/res_alice_base -type f -name '*.png'); do
    case $(basename "$icon") in
        layered_app_icon_background*) tpl="$RES_DIR/background.svg"; k=1.0 ;;
        layered_app_icon*)            tpl="$RES_DIR/foreground.svg"; k=0.66 ;;
        app_icon*)                    tpl="$RES_DIR/icon.svg";       k=1.147 ;;
        *)                            tpl="$RES_DIR/icon.svg";       k=1 ;;
    esac
    w=$(identify -format %w "$icon")
    sed -e "s/scale(1)/scale(${k})/" "$tpl" | rsvg-convert -w "$w" -h "$w" -o "$icon" -

    # 只缩前景层：整层等比缩放 + 居中（保留 SVG 自己的留白比例，不 trim）。
    # 注意背景层分支要放在前面，否则它也会被缩。
    case $(basename "$icon") in
        layered_app_icon_background*) ;;
        layered_app_icon*)
            if [ "$FG_SCALE" != "100" ]; then
                convert "$icon" -resize "${FG_SCALE}%" -background none -gravity center \
                        -extent "${w}x${w}" "$icon"
            fi ;;
    esac
    echo "$icon ($w px)"
done
