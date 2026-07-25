#!/usr/bin/env bash

set -euo pipefail

readonly smoke_attempts=30
readonly smoke_interval_seconds="0.1"

usage() {
  cat <<'EOF'
用法：
  scripts/smoke-test-release-launch.sh \
    --app /路径/MihomoMeter.app

说明：
  在不启动生产服务的测试模式下直接运行已签名应用。
  应用必须持续存活三秒，以发现 dyld、签名与框架加载阶段的启动崩溃。
  若当前宿主架构不在应用可执行文件中，则明确跳过该单架构产物。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

app_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      [[ $# -ge 2 ]] || fail "--app 缺少参数。"
      app_path="$2"
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

[[ -d "${app_path}" ]] || fail "找不到待启动应用：${app_path}"

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
executable_path="${app_path}/Contents/MacOS/MihomoMeter"
[[ -x "${executable_path}" ]] || fail "找不到可执行文件：${executable_path}"

host_architecture="$(uname -m)"
executable_architectures="$(lipo -archs "${executable_path}")"
if [[ " ${executable_architectures} " != *" ${host_architecture} "* ]]; then
  echo \
    "跳过启动冒烟：宿主架构 ${host_architecture} 不在应用架构 ${executable_architectures} 中。"
  exit 0
fi

mkdir -p "${project_root}/.build"
launch_log_path="$(mktemp "${project_root}/.build/release-launch-smoke.XXXXXX.log")"
app_pid=""

cleanup() {
  if [[ -n "${app_pid}" ]] && kill -0 "${app_pid}" >/dev/null 2>&1; then
    kill -TERM "${app_pid}" >/dev/null 2>&1 || true
    wait "${app_pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${launch_log_path}"
}
trap cleanup EXIT

MIHOMO_METER_TEST_MODE=1 "${executable_path}" \
  >"${launch_log_path}" 2>&1 &
app_pid=$!

for ((attempt = 1; attempt <= smoke_attempts; attempt++)); do
  if ! kill -0 "${app_pid}" >/dev/null 2>&1; then
    if wait "${app_pid}"; then
      exit_code=0
    else
      exit_code=$?
    fi
    app_pid=""
    if [[ -s "${launch_log_path}" ]]; then
      cat "${launch_log_path}" >&2
    fi
    fail "Release 应用启动后提前退出，退出码：${exit_code}。"
  fi
  sleep "${smoke_interval_seconds}"
done

kill -TERM "${app_pid}" >/dev/null 2>&1 || true
wait "${app_pid}" >/dev/null 2>&1 || true
app_pid=""

echo "Release 应用真实启动冒烟通过：${app_path}"
