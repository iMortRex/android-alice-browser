#!/bin/bash
# 通用 OKLab 颜色插值接口：供 0071、0074 及后续功能复用。

set -e

path1="ui/android/java/src/org/chromium/ui/util/ColorUtils.java"

# 检测是否已应用
if grep -q 'Alice patch start 0075' "$path1"; then
    exit 100
fi

if grep -q 'blendColorsOklab' "$path1"; then
    echo "ColorUtils.blendColorsOklab already exists" >&2
    exit 101
fi

sed -i '$i\
    // Alice patch start 0075\
    /**\
     * Interpolates opaque colors in OKLab for a more even perceptual transition.\
     *\
     * <p>Translucent colors fall back to the existing premultiplied sRGB interpolation.\
     *\
     * @param from Color at fraction zero.\
     * @param to Color at fraction one.\
     * @param fraction Interpolation fraction from zero to one.\
     * @return Interpolated opaque sRGB color.\
     */\
    public static @ColorInt int blendColorsOklab(\
            @ColorInt int from, @ColorInt int to, @FloatRange(from = 0f, to = 1f) float fraction) {\
        if (fraction <= 0f) return from;\
        if (fraction >= 1f) return to;\
        if (Color.alpha(from) != 255 || Color.alpha(to) != 255) {\
            return blendColorsMultiply(from, to, fraction);\
        }\
\
        double fromR = aliceSrgbToLinear(Color.red(from));\
        double fromG = aliceSrgbToLinear(Color.green(from));\
        double fromB = aliceSrgbToLinear(Color.blue(from));\
        double fromL = Math.cbrt(\
                0.4122214708 * fromR + 0.5363325363 * fromG + 0.0514459929 * fromB);\
        double fromM = Math.cbrt(\
                0.2119034982 * fromR + 0.6806995451 * fromG + 0.1073969566 * fromB);\
        double fromS = Math.cbrt(\
                0.0883024619 * fromR + 0.2817188376 * fromG + 0.6299787005 * fromB);\
\
        double toR = aliceSrgbToLinear(Color.red(to));\
        double toG = aliceSrgbToLinear(Color.green(to));\
        double toB = aliceSrgbToLinear(Color.blue(to));\
        double toL = Math.cbrt(\
                0.4122214708 * toR + 0.5363325363 * toG + 0.0514459929 * toB);\
        double toM = Math.cbrt(\
                0.2119034982 * toR + 0.6806995451 * toG + 0.1073969566 * toB);\
        double toS = Math.cbrt(\
                0.0883024619 * toR + 0.2817188376 * toG + 0.6299787005 * toB);\
\
        double fromLabL = 0.2104542553 * fromL + 0.793617785 * fromM - 0.0040720468 * fromS;\
        double fromLabA = 1.9779984951 * fromL - 2.428592205 * fromM + 0.4505937099 * fromS;\
        double fromLabB = 0.0259040371 * fromL + 0.7827717662 * fromM - 0.808675766 * fromS;\
        double toLabL = 0.2104542553 * toL + 0.793617785 * toM - 0.0040720468 * toS;\
        double toLabA = 1.9779984951 * toL - 2.428592205 * toM + 0.4505937099 * toS;\
        double toLabB = 0.0259040371 * toL + 0.7827717662 * toM - 0.808675766 * toS;\
\
        double labL = fromLabL + (toLabL - fromLabL) * fraction;\
        double labA = fromLabA + (toLabA - fromLabA) * fraction;\
        double labB = fromLabB + (toLabB - fromLabB) * fraction;\
        double l = labL + 0.3963377774 * labA + 0.2158037573 * labB;\
        double m = labL - 0.1055613458 * labA - 0.0638541728 * labB;\
        double s = labL - 0.0894841775 * labA - 1.291485548 * labB;\
        l = l * l * l;\
        m = m * m * m;\
        s = s * s * s;\
\
        int red = aliceLinearToSrgb(\
                4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s);\
        int green = aliceLinearToSrgb(\
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s);\
        int blue = aliceLinearToSrgb(\
                -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s);\
        return Color.argb(255, red, green, blue);\
    }\
\
    private static double aliceSrgbToLinear(int channel) {\
        double value = channel / 255.0;\
        return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);\
    }\
\
    private static int aliceLinearToSrgb(double value) {\
        value = Math.max(0.0, Math.min(1.0, value));\
        double encoded = value <= 0.0031308\
                ? 12.92 * value\
                : 1.055 * Math.pow(value, 1.0 / 2.4) - 0.055;\
        return (int) Math.round(encoded * 255.0);\
    }\
    // Alice patch end 0075' "$path1"
