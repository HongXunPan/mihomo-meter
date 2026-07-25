#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  scripts/sign-sparkle-framework.sh \
    --app /路径/MihomoMeter.app \
    --identity 证书SHA1

说明：
  按 Sparkle 官方要求由内到外签名嵌套组件。
  不使用 --deep 签名，也不会覆盖主应用的代码指定要求。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

require_path() {
  if [[ ! -e "$1" ]]; then
    fail "缺少 Sparkle 签名目标：$1"
  fi
}

sign_component() {
  local target_path="$1"

  codesign \
    --force \
    --sign "${signing_identity}" \
    --options runtime \
    --timestamp=none \
    "${target_path}"
}

app_path=""
signing_identity=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || fail "--app 缺少参数。"
      app_path="$2"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || fail "--identity 缺少参数。"
      signing_identity="$2"
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

[[ -n "${app_path}" ]] || fail "必须提供 --app。"
[[ -n "${signing_identity}" ]] || fail "必须提供 --identity。"
command -v codesign >/dev/null 2>&1 || fail "未找到必需命令：codesign"

sparkle_framework="${app_path}/Contents/Frameworks/Sparkle.framework"
sparkle_version="${sparkle_framework}/Versions/Current"
installer_xpc="${sparkle_version}/XPCServices/Installer.xpc"
downloader_xpc="${sparkle_version}/XPCServices/Downloader.xpc"
autoupdate="${sparkle_version}/Autoupdate"
updater_app="${sparkle_version}/Updater.app"

require_path "${sparkle_framework}"
require_path "${installer_xpc}"
require_path "${autoupdate}"
require_path "${updater_app}"

sign_component "${installer_xpc}"

if [[ -e "${downloader_xpc}" ]]; then
  codesign \
    --force \
    --sign "${signing_identity}" \
    --options runtime \
    --timestamp=none \
    --preserve-metadata=entitlements \
    "${downloader_xpc}"
fi

sign_component "${autoupdate}"
sign_component "${updater_app}"
sign_component "${sparkle_framework}"

codesign --verify --deep --strict --verbose=2 "${sparkle_framework}"
