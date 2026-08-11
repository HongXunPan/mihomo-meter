#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  scripts/build-debug.sh
  scripts/build-debug.sh --run

说明：
  默认构建已签名的 Debug 应用。
  使用 --run 时，构建完成后以前台进程启动应用；应用退出后命令返回。
  构建失败时会提取真实错误上下文，并保留完整日志用于反馈。
EOF
}

print_build_diagnostics() {
  local build_log_path="$1"
  local error_context

  error_context="$(
    grep \
      -n \
      -E \
      -B 2 \
      -A 4 \
      ':[0-9]+:[0-9]+: (fatal )?error:|(^|[[:space:]])(fatal )?error:|Could not resolve package dependencies:|Command .* failed with a nonzero exit code|compile command failed|fatal error encountered during compilation' \
      "${build_log_path}" || true
  )"

  echo >&2
  echo "========== 构建失败的真实错误上下文 ==========" >&2
  if [[ -n "${error_context}" ]]; then
    printf '%s\n' "${error_context}" | sed -n '1,200p' >&2
  else
    echo "未匹配到标准错误诊断，以下为构建日志最后 120 行：" >&2
    tail -n 120 "${build_log_path}" >&2
  fi
  echo "=====================================================" >&2
  echo "完整构建日志：${build_log_path}" >&2
}

verify_app_entitlements() {
  local target_app_path="$1"
  local entitlements_output

  if ! entitlements_output="$(
    codesign -d --entitlements - "${target_app_path}" 2>&1
  )"; then
    echo "无法读取构建产物的签名权限，请确认应用已完成有效签名。" >&2
    return 1
  fi

  if ! grep -Fq "com.apple.security.app-sandbox" <<<"${entitlements_output}" ||
    ! grep -Fq "com.apple.security.network.client" <<<"${entitlements_output}"; then
    cat >&2 <<'EOF'
构建产物缺少应用运行所需的沙盒或网络客户端权限。
请确认：
1. MihomoMeter Target 已启用 App Sandbox；
2. 已允许出站网络连接；
3. 当前签名身份可以签署此 Bundle ID。
EOF
    return 1
  fi

  if grep -Fq "keychain-access-groups" <<<"${entitlements_output}"; then
    echo "构建产物不应声明需要 provisioning profile 的 Keychain 访问组。" >&2
    return 1
  fi
}

verify_shared_core_static_link() {
  local target_app_path="$1"
  local executable_directory="${target_app_path}/Contents/MacOS"
  local binary_path
  local linkage_output
  local binary_paths=("${executable_directory}/MihomoMeter")

  if [[ -f "${executable_directory}/MihomoMeter.debug.dylib" ]]; then
    binary_paths+=("${executable_directory}/MihomoMeter.debug.dylib")
  fi

  for binary_path in "${binary_paths[@]}"; do
    if ! linkage_output="$(/usr/bin/otool -L "${binary_path}" 2>&1)"; then
      echo "无法读取 Debug 应用链接信息：${linkage_output}" >&2
      return 1
    fi
    if grep -Fq "libmihomo_meter_shared_core.dylib" <<<"${linkage_output}"; then
      echo "Debug 应用错误地动态依赖 Rust 共享核心：${binary_path}" >&2
      return 1
    fi
  done
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
app_executable_path="${app_path}/Contents/MacOS/MihomoMeter"
diagnostic_log_directory="${project_root}/.build/Diagnostics"
build_log_path="${diagnostic_log_directory}/build-debug-$(date '+%Y%m%d-%H%M%S').log"

cd "${project_root}"
mkdir -p "${diagnostic_log_directory}"
scripts/build_shared_core_macos.sh --architectures "$(uname -m)"

set +e
xcodebuild \
  -project MihomoMeter.xcodeproj \
  -scheme MihomoMeter \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "${derived_data_path}" \
  -allowProvisioningUpdates \
  build 2>&1 | tee "${build_log_path}"
pipeline_status=("${PIPESTATUS[@]}")
set -e

build_status="${pipeline_status[0]}"
tee_status="${pipeline_status[1]}"
if [[ "${tee_status}" -ne 0 ]]; then
  echo "无法写入完整构建日志：${build_log_path}" >&2
fi

if [[ "${build_status}" -ne 0 ]]; then
  if [[ -s "${build_log_path}" ]]; then
    print_build_diagnostics "${build_log_path}"
  fi

  if [[ -s "${build_log_path}" ]] &&
    grep -Eq 'CodeSign|errSecInternalComponent' "${build_log_path}"; then
    cat >&2 <<'EOF'

检测到代码签名错误，请检查：
1. 打开“钥匙串访问”，确认“登录”钥匙串已经解锁；
2. 确认 Apple Development 证书存在对应私钥；
3. 返回 Xcode 完成一次本机签名后再重试。

请勿把登录钥匙串密码写入脚本。
EOF
  fi
  exit "${build_status}"
fi

if [[ "${tee_status}" -ne 0 ]]; then
  exit "${tee_status}"
fi

rm -f "${build_log_path}"

if ! verify_app_entitlements "${app_path}"; then
  exit 1
fi
if ! verify_shared_core_static_link "${app_path}"; then
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

if [[ ! -x "${app_executable_path}" ]]; then
  echo "Debug 应用缺少可执行文件：${app_executable_path}" >&2
  exit 1
fi

echo "以前台进程启动 Mihomo Meter Debug；应用退出后命令才返回。"
echo "按 Ctrl-C 或关闭当前终端会终止本次 Debug 应用。"
exec "${app_executable_path}"
