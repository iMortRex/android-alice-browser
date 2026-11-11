#!/bin/bash
# 通用状态栏颜色过渡接口：Activity 级共享当前状态栏颜色与动画状态。

set -e

path1="$(mktemp)"
path2="chrome/android/java/src/org/chromium/chrome/browser/ui/system/StatusBarColorController.java"
nested="$(mktemp)"
trap 'rm -f "$path1" "$nested"' EXIT

if grep -q 'Alice patch start 0076' "$path2"; then
    exit 100
fi

cat > "$path1" <<'ALICE_EOF'
// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.ui.system;

import android.animation.ValueAnimator;
import android.app.Activity;
import android.graphics.Color;

import androidx.annotation.ColorInt;

import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.ui.interpolators.Interpolators;
import org.chromium.ui.util.ColorUtils;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;

/** Coordinates transient status bar colors for one Activity. */
// Alice patch start 0076
@NullMarked
public final class AliceStatusBarColorTransitionController {
    /** Receives every intermediate color. */
    public interface Observer {
        void onColorChanged(@ColorInt int color);
    }

    private static final Map<Activity, WeakReference<AliceStatusBarColorTransitionController>>
            sControllers = new WeakHashMap<>();

    private final List<Observer> mObservers = new ArrayList<>();
    private @Nullable ValueAnimator mAnimator;
    private @ColorInt int mCurrentColor = Color.TRANSPARENT;
    private @ColorInt int mTargetColor = Color.TRANSPARENT;
    private int mGeneration;
    private boolean mHasColor;
    private boolean mOverrideActive;
    private int mCurrentToken;
    private int mNextToken;

    private AliceStatusBarColorTransitionController() {}

    /** Returns the Activity-scoped controller. */
    public static AliceStatusBarColorTransitionController forActivity(Activity activity) {
        synchronized (sControllers) {
            WeakReference<AliceStatusBarColorTransitionController> reference =
                    sControllers.get(activity);
            AliceStatusBarColorTransitionController controller =
                    reference == null ? null : reference.get();
            if (controller == null) {
                controller = new AliceStatusBarColorTransitionController();
                sControllers.put(activity, new WeakReference<>(controller));
            }
            return controller;
        }
    }

    /** Releases the controller and all observers for the Activity. */
    public static void releaseForActivity(Activity activity) {
        synchronized (sControllers) {
            WeakReference<AliceStatusBarColorTransitionController> reference =
                    sControllers.remove(activity);
            AliceStatusBarColorTransitionController controller =
                    reference == null ? null : reference.get();
            if (controller != null) controller.destroy();
        }
    }

    public void addObserver(Observer observer) {
        if (mObservers.contains(observer)) return;
        mObservers.add(observer);
        if (mHasColor) observer.onColorChanged(mCurrentColor);
    }

    public void removeObserver(Observer observer) {
        mObservers.remove(observer);
    }

    /** Animates from the current color to {@code targetColor}. */
    public int animateTo(@ColorInt int targetColor, long durationMs) {
        return animateTo(null, targetColor, durationMs);
    }

    /**
     * Starts a new transition from an optional explicit start color.
     *
     * <p>When {@code startColor} is null, the current rendered color is used. A new call always
     * interrupts the previous transition.
     */
    public int animateTo(
            @Nullable Integer startColor, @ColorInt int targetColor, long durationMs) {
        int token = ++mNextToken;
        mCurrentToken = token;
        mOverrideActive = true;
        if (startColor != null) {
            cancelAnimator();
            mCurrentColor = startColor;
            mHasColor = true;
            notifyObservers();
        }

        if (!mHasColor) {
            mCurrentColor = targetColor;
            mTargetColor = targetColor;
            mHasColor = true;
        }

        if (durationMs <= 0 || mCurrentColor == targetColor) {
            cancelAnimator();
            mCurrentColor = targetColor;
            mTargetColor = targetColor;
            mHasColor = true;
            notifyObservers();
            return token;
        }

        cancelAnimator();
        int generation = ++mGeneration;
        int fromColor = mCurrentColor;
        mTargetColor = targetColor;
        ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);
        animator.setDuration(durationMs);
        animator.setInterpolator(Interpolators.EMPHASIZED);
        animator.addUpdateListener(
                animation -> {
                    if (generation != mGeneration) return;
                    mCurrentColor =
                            ColorUtils.blendColorsOklab(
                                    fromColor,
                                    targetColor,
                                    animation.getAnimatedFraction());
                    notifyObservers();
                });
        mAnimator = animator;
        animator.start();
        return token;
    }

    /** Releases the status bar override owned by {@code token}. */
    public void clearOverride(int token) {
        if (token != mCurrentToken) return;
        cancelAnimator();
        mOverrideActive = false;
        notifyObservers();
    }

    public @ColorInt int getCurrentColor() {
        return mCurrentColor;
    }

    public boolean hasColor() {
        return mHasColor;
    }

    public boolean isOverriding() {
        return mOverrideActive;
    }

    private void cancelAnimator() {
        mGeneration++;
        if (mAnimator != null) {
            mAnimator.cancel();
            mAnimator = null;
        }
    }

    private void notifyObservers() {
        for (Observer observer : mObservers) {
            observer.onColorChanged(mCurrentColor);
        }
    }

    private void destroy() {
        cancelAnimator();
        mObservers.clear();
        mHasColor = false;
        mOverrideActive = false;
        mCurrentToken = 0;
        mCurrentColor = Color.TRANSPARENT;
        mTargetColor = Color.TRANSPARENT;
    }
}
// Alice patch end 0076
ALICE_EOF

sed -i '/^import java.util.Map;$/i\
// Alice patch start 0076\
import java.lang.ref.WeakReference;\
import java.util.ArrayList;\
import java.util.List;\
// Alice patch end 0076' "$path2"

sed -n '/^\/\/ Alice patch start 0076$/,/^\/\/ Alice patch end 0076$/p' "$path1" \
    | sed 's/^public final class/    public static final class/' \
    | sed 's/^/    /' > "$nested"

sed -i '$d' "$path2"
cat "$nested" >> "$path2"
printf '}\n' >> "$path2"
