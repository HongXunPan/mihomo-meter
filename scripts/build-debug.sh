#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  scripts/build-debug.sh
  scripts/build-debug.sh --run

说明：
  默认构建已签名的 Debug 应用。
  使用 --run 时，构建完成后启动应用。
EOF
}

run_after_build=0
case "${1:-}" in
  "")
    ;;
  --run)
    run_after_build=1
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "不支持的参数：$1" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ $# -gt 1 ]]; then
  echo "参数过多。" >&2
  usage >&2
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "未找到 xcodebuild，请先安装并选择可用的 Xcode。" >&2
  exit 1
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
local_signing_config_path="${project_root}/Config.local.xcconfig"

if [[ ! -f "${local_signing_config_path}" ]] ||
  ! grep -Eq '^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*[A-Za-z0-9]+' \
    "${local_signing_config_path}"; then
  cat >&2 <<'EOF'
未找到有效的本机签名配置。
请创建不会提交到 Git 的 Config.local.xcconfig，并填写：

DEVELOPMENT_TEAM = 你的 Apple Developer Team ID
EOF
  exit 1
fi

if ! signing_identities="$(security find-identity -v -p codesigning 2>&1)" ||
  ! grep -Eq '[1-9][0-9]* valid identities found' <<<"${signing_identities}"; then
  echo "未找到可用的代码签名身份，请先在 Xcode 中登录开发者账号并完成本机签名配置。" >&2
  exit 1
fi

derived_data_path="${MIHOMO_METER_DERIVED_DATA_PATH:-${project_root}/.build/LocalDerivedData}"
app_path="${derived_data_path}/Build/Products/Debug/MihomoMeter.app"

cd "${project_root}"

if ! xcodebuild \
  -project MihomoMeter.xcodeproj \
  -scheme MihomoMeter \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "${derived_data_path}" \
  build; then
  cat >&2 <<'EOF'

构建失败。若上方错误为 CodeSign/errSecInternalComponent：
1. 打开“钥匙串访问”，确认“登录”钥匙串已经解锁；
2. 确认 Apple Development 证书存在对应私钥；
3. 返回 Xcode 完成一次本机签名后再重试。

请勿把登录钥匙串密码写入脚本。
EOF
  exit 1
fi

echo
echo "构建完成：${app_path}"

if [[ ${run_after_build} -eq 0 ]]; then
  echo "运行命令：open \"${app_path}\""
  exit 0
fi

if pgrep -x MihomoMeter >/dev/null 2>&1; then
  echo "检测到 Mihomo Meter 正在运行，请先从状态栏退出后再使用 --run。" >&2
  exit 1
fi

open "${app_path}"
