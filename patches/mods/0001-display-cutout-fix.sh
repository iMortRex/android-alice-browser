#!/bin/bash
# Display Cutout 模式固定为 1

sed -i 's|if (attributes.layoutInDisplayCutoutMode == displayCutoutMode) return;|if (attributes.layoutInDisplayCutoutMode == 1) return;|' \
    components/browser_ui/display_cutout/android/java/src/org/chromium/components/browser_ui/display_cutout/DisplayCutoutController.java

sed -i 's|attributes.layoutInDisplayCutoutMode = displayCutoutMode;|attributes.layoutInDisplayCutoutMode = 1;|' \
    components/browser_ui/display_cutout/android/java/src/org/chromium/components/browser_ui/display_cutout/DisplayCutoutController.java