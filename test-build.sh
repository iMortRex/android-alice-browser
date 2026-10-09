cd ~/android-alice-browser/chromium/src

# 手动改你要测的文件
source "android-alice-browser/patches/mods/0004-default-setting-value.sh" || exit 1

# 增量编译
autoninja -C out/Default chrome_public_apk