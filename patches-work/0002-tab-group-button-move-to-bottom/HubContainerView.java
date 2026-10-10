// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.hub;

import android.annotation.SuppressLint;
import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewParent;
import android.widget.FrameLayout;

import org.chromium.build.annotations.NullMarked;
import org.chromium.build.annotations.Nullable;
import org.chromium.ui.animation.RunOnNextLayout;
import org.chromium.ui.animation.RunOnNextLayoutDelegate;

/** Container view for the Hub. */
@NullMarked
public class HubContainerView extends FrameLayout implements RunOnNextLayout {
    private static final String TAG = "HubContainerView";
    private final RunOnNextLayoutDelegate mRunOnNextLayoutDelegate;

    private @Nullable View mPinnedBottomView;

    /** Default {@link FrameLayout} constructor. */
    public HubContainerView(Context context) {
        super(context);
        mRunOnNextLayoutDelegate = new RunOnNextLayoutDelegate(this);
    }

    public void setPinnedBottomView(@Nullable View view) {
        mPinnedBottomView = view;
    }

    @Override
    public void onLayout(boolean changed, int l, int t, int r, int b) {
        super.onLayout(changed, l, t, r, b);
        runOnNextLayoutRunnables();
        pinBottomView();
    }

    private void pinBottomView() {
        View pinned = mPinnedBottomView;
        if (pinned == null) return;
        ViewParent parent = getParent();
        if (!(parent instanceof View)) return;
        View parentView = (View) parent;

        int[] location = new int[2];
        parentView.getLocationInWindow(location);
        int parentBottom = location[1] + parentView.getHeight();

        pinned.getLocationInWindow(location);
        int pinnedBottom = location[1] + pinned.getHeight();

        int delta = parentBottom - pinnedBottom;
        if (delta != 0) {
            pinned.setTranslationY(pinned.getTranslationY() + delta);
        }
    }

    @Override
    public void runOnNextLayout(Runnable runnable) {
        mRunOnNextLayoutDelegate.runOnNextLayout(runnable);
    }

    @Override
    public void runOnNextLayoutRunnables() {
        mRunOnNextLayoutDelegate.runOnNextLayoutRunnables();
    }

    @Override
    @SuppressLint("ClickableViewAccessibility")
    public boolean onTouchEvent(MotionEvent motionEvent) {
        super.onTouchEvent(motionEvent);
        // Prevent touch events from "falling through" to views below. See b/337616153.
        return true;
    }
}