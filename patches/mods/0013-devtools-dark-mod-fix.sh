#!/bin/bash
# DevTools 默认关闭"与 Chrome 配色方案匹配"，使其跟随浏览器深浅色

# 目标文件路径
path1="chrome/browser/devtools/devtools_ui_bindings.cc"

# 检测是否已应用
if grep -q 'Alice patch start 0013' "$path1"; then
    exit 100
fi

#    关掉 DevTools 的"与 Chrome 配色方案匹配"（chrome-theme-colors）默认值：
#    它默认 true，第一次打开时会按 Chrome 配色把界面画成浅色；这里只在用户没有设置值时改成 false。
#    注意 DevTools 的设置值是 JSON 文本（Setting.set 用 JSON.stringify、get 用 JSON.parse），
#    布尔就是 "false"。
sed -i '/^  base::Value settings = base::Value(settings_.Get());$/a\
  // Alice patch start 0013\
#if BUILDFLAG(IS_ANDROID)\
  // Alice: devtools dark -- 默认关掉"与 Chrome 配色方案匹配"（不改用户已设置的值）。\
  if (base::DictValue* alice_theme_dict = settings.GetIfDict()) {\
    if (!alice_theme_dict->FindString("chrome-theme-colors")) {\
      alice_theme_dict->Set("chrome-theme-colors", "false");\
    }\
    if (!alice_theme_dict->FindString("__bundled__chrome-theme-colors")) {\
      alice_theme_dict->Set("__bundled__chrome-theme-colors", "false");\
    }\
  }\
#endif  // BUILDFLAG(IS_ANDROID)\
  // Alice patch end 0013' "$path1"
