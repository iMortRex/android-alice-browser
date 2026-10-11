#!/bin/sh

# 用法: icon.sh <png>
#   用 res/ 里对应的 SVG 模板，按原图尺寸重画这张 PNG（分层约定）：
#     layered_app_icon_background* -> background.svg
#     layered_app_icon*            -> foreground.svg
#     app_icon*                    -> icon.svg

RES_DIR=$(dirname "$0")
w=$(identify -format %w "$1")

case $(basename "$1") in
  layered_app_icon_background*)
      tpl="$RES_DIR/background.svg"; k=1.0 ;;
  layered_app_icon*)
      tpl="$RES_DIR/foreground.svg"; k=0.66 ;;
  app_icon*)
      tpl="$RES_DIR/icon.svg"; k=1.147 ;;
  *)
      tpl="$RES_DIR/icon.svg"; k=1 ;;
esac

# s/scale(1)/scale($k)/ 只在模板里写了 scale(1) 时才生效；
# 现在这三个 SVG 里没有（等于空操作），留着是为了以后换 SVG 时能继续用。
sed -e "s/scale(1)/scale($k)/" "$tpl" | rsvg-convert -w "$w" -h "$w" -o "$1" -
echo "$1 (${w}px)"