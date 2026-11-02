#!/bin/bash
# 修复 Activity 窗口焦点缓存失效后，Omnibox 建议监听器无法重新注册的问题。

set -e

# 目标文件路径
path1="chrome/browser/ui/android/omnibox/java/src/org/chromium/chrome/browser/omnibox/suggestions/AutocompleteMediator.java"

# 检测是否已应用
if grep -q 'Alice patch start 0044' "$path1"; then
    exit 100
fi

# 焦点缓存只作为最后一次回调结果，注册建议监听器前必须再核对实时窗口状态。
# 否则初始化期间 hasWindowFocus() 为 false 且顶层 Activity 回调被错过时，
# OnSuggestionsReceivedListener 会直到整个 Activity 进程结束都不再注册。
sed -i '/^    private void installAutocompleteObservers() {$/a\
        // Alice patch start 0044\
        if (!mActivityWindowFocused) {\
            Activity activity = mWindowAndroid.getActivity().get();\
            mActivityWindowFocused =\
                    mWindowAndroid.isTopResumedActivity()\
                            || (activity != null \&\& activity.hasWindowFocus());\
        }\
        // Alice patch end 0044' "$path1"

# 输入变化时幂等补注册。ObserverList 会忽略同一个监听器的重复注册，
# 因此即使顶层 Activity 回调丢失，也能在下一次输入时自行恢复。
sed -i '/^    public void onInputChanged() {$/a\
        // Alice patch start 0044\
        // Input updates are a reliable retry point when the top-resumed callback was missed.\
        // ObserverList ignores duplicate registrations.\
        installAutocompleteObservers();\
        // Alice patch end 0044' "$path1"
