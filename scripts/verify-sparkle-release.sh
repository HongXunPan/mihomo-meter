#!/usr/bin/env bash

set -euo pipefail

readonly expected_feed_url="https://github.com/HongXunPan/mihomo-meter/releases/latest/download/appcast.xml"
readonly expected_minimum_system_version="14.0"
readonly expected_public_key="xPuZ+Pa87B1FNsb40KCxhMYd1qJtvUkEWBqwfqrtoWU="

usage() {
  cat <<'EOF'
用法：
  scripts/verify-sparkle-release.sh \
    --app /路径/MihomoMeter.app \
    --bundle-identifier com.HongXunPan.MihomoMeter

说明：
  校验 Release 应用的最低系统版本，以及 Sparkle 框架、沙盒通信权限、更新源、公钥与交互策略。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

read_plist_value() {
  local key="$1"
  local plist_path="$2"
  local value

  if ! value="$(/usr/libexec/PlistBuddy -c "Print :${key}" "${plist_path}" 2>/dev/null)"; then
    fail "Release 应用缺少 Sparkle 配置：${key}"
  fi
  printf '%s\n' "${value}"
}

app_path=""
bundle_identifier=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || fail "--app 缺少参数。"
      app_path="$2"
      shift 2
      ;;
    --bundle-identifier)
      [[ $# -ge 2 ]] || fail "--bundle-identifier 缺少参数。"
      bundle_identifier="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "不支持的参数：$1"
      ;;
  esac
done

[[ -d "${app_path}" ]] || fail "找不到待校验应用：${app_path}"
[[ -n "${bundle_identifier}" ]] || fail "必须提供 --bundle-identifier。"

info_plist="${app_path}/Contents/Info.plist"
sparkle_framework="${app_path}/Contents/Frameworks/Sparkle.framework"
sparkle_version="${sparkle_framework}/Versions/Current"
installer_xpc="${sparkle_version}/XPCServices/Installer.xpc"
downloader_xpc="${sparkle_version}/XPCServices/Downloader.xpc"
autoupdate="${sparkle_version}/Autoupdate"
updater_app="${sparkle_version}/Updater.app"

[[ -f "${info_plist}" ]] || fail "Release 应用缺少 Info.plist。"
[[ -d "${sparkle_framework}" ]] || fail "Release 应用缺少 Sparkle.framework。"

entitlements_output="$(codesign -d --entitlements - "${app_path}" 2>&1)"
if ! grep -Fq \
  "com.apple.security.temporary-exception.mach-lookup.global-name" \
  <<<"${entitlements_output}" ||
  ! grep -Fq "${bundle_identifier}-spks" <<<"${entitlements_output}" ||
  ! grep -Fq "${bundle_identifier}-spki" <<<"${entitlements_output}"; then
  fail "Release 应用缺少 Sparkle Installer XPC 所需的沙盒通信权限。"
fi

if ! grep -Fq \
  "com.apple.security.cs.disable-library-validation" \
  <<<"${entitlements_output}"; then
  fail "固定自签名 Release 必须允许加载没有 Apple Team ID 的 Sparkle.framework。"
fi

[[ "$(read_plist_value SUEnableInstallerLauncherService "${info_plist}")" == "true" ]] ||
  fail "Release 应用没有启用 Sparkle Installer Launcher Service。"
[[ "$(read_plist_value SUEnableAutomaticChecks "${info_plist}")" == "true" ]] ||
  fail "Release 应用没有启用自动更新检查。"
[[ "$(read_plist_value SUAllowsAutomaticUpdates "${info_plist}")" == "false" ]] ||
  fail "Release 应用必须要求用户确认后才能安装更新。"
[[ "$(read_plist_value SUVerifyUpdateBeforeExtraction "${info_plist}")" == "true" ]] ||
  fail "Release 应用没有启用解压前更新验签。"
[[ "$(read_plist_value LSMinimumSystemVersion "${info_plist}")" == \
  "${expected_minimum_system_version}" ]] ||
  fail "Release 应用最低系统版本不是 macOS ${expected_minimum_system_version}。"
[[ "$(read_plist_value SUFeedURL "${info_plist}")" == "${expected_feed_url}" ]] ||
  fail "Release 应用的 Sparkle 更新源不匹配。"
[[ "$(read_plist_value SUPublicEDKey "${info_plist}")" == "${expected_public_key}" ]] ||
  fail "Release 应用的 Sparkle Ed25519 公钥不匹配。"

sparkle_components=(
  "${sparkle_framework}"
  "${installer_xpc}"
  "${autoupdate}"
  "${updater_app}"
)
if [[ -e "${downloader_xpc}" ]]; then
  sparkle_components+=("${downloader_xpc}")
fi

for component_path in "${sparkle_components[@]}"; do
  [[ -e "${component_path}" ]] || fail "缺少 Sparkle 签名组件：${component_path}"
  component_requirement="$(codesign -d -r- "${component_path}" 2>&1)"
  if grep -Fq "identifier \"${bundle_identifier}\"" <<<"${component_requirement}"; then
    fail "Sparkle 组件不得继承主应用的 Keychain 指定要求：${component_path}"
  fi
done
