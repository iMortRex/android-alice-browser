#!/bin/bash
# 在 UA Client Hints 的品牌列表中公开 "Alice Browser"。

set -e

# 目标文件路径
path1="components/embedder_support/user_agent_utils.cc"

# 检测是否已应用
if grep -q 'Alice patch start 0045' "$path1"; then
    exit 100
fi

# GetUserAgentBrandList 同时生成低熵 brands 与高熵 fullVersionList，
# 因此在这里追加品牌可以保证 navigator.userAgentData 的两份列表一致。
sed -i '/^  return GenerateBrandVersionList(major_version_number, brand, brand_version,$/,/^                                  additional_brand_version);$/c\
  blink::UserAgentBrandList brand_version_list =\
      GenerateBrandVersionList(major_version_number, brand, brand_version,\
                               output_version_type,\
                               additional_brand_version);\
  // Alice patch start 0045\
  // Keep Alice Browser in both Sec-CH-UA brands and fullVersionList.\
  bool alice_brand_present = false;\
  for (const auto& item : brand_version_list) {\
    if (item.brand == "Alice Browser") {\
      alice_brand_present = true;\
      break;\
    }\
  }\
  if (!alice_brand_present) {\
    brand_version_list.emplace_back("Alice Browser", brand_version);\
  }\
  // Alice patch end 0045\
  return brand_version_list;' "$path1"
