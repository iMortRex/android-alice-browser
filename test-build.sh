cd ~/android-alice-browser/chromium/src

# 应用patch
echo "=== 应用 patch ==="
if [ -d "$SCRIPT_DIR/patches" ]; then
    for p in "$SCRIPT_DIR"/patches/*.patch; do
        [ -f "$p" ] || continue
        echo "Applying $p"
        git apply --whitespace=nowarn "$p"
    done
fi

# 应用mod
echo "=== 应用 mod ==="
if [ -d "$SCRIPT_DIR/patches/mods" ]; then
    for m in "$SCRIPT_DIR"/patches/mods/*.sh; do
        [ -f "$m" ] || continue
        echo "Applying mod: $(basename "$m")"
        bash "$m" || exit 1
    done
fi

# 增量编译
autoninja -C out/Default chrome_public_apk