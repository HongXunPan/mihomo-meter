#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  scripts/build_shared_core_macos.sh [--architectures "arm64 x86_64"]

说明：
  默认构建当前宿主架构的 Release 静态库。
  universal 应用构建前必须同时传入 arm64 与 x86_64。
EOF
}

architectures="$(uname -m)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --architectures)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "--architectures 缺少架构列表。" >&2
        exit 2
      fi
      architectures="$2"
      shift 2
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
done

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
# shellcheck source=scripts/shared_core_macos_toolchain.sh
source "${script_directory}/shared_core_macos_toolchain.sh"

resolve_shared_core_macos_toolchain
export CARGO_TARGET_DIR="${project_root}/.build/shared-core"
manifest_path="${project_root}/SharedCore/Cargo.toml"

read -r -a architecture_list <<<"${architectures}"
if [[ ${#architecture_list[@]} -eq 0 ]]; then
  echo "macOS 共享核心架构列表不得为空。" >&2
  exit 2
fi

for architecture in "${architecture_list[@]}"; do
  rust_target="$(shared_core_macos_target_for_architecture "${architecture}")"
  require_shared_core_macos_target "${rust_target}"

  rustup run "${shared_core_rust_toolchain}" cargo build \
    --manifest-path "${manifest_path}" \
    --locked \
    --release \
    --target "${rust_target}"

  library_path="${CARGO_TARGET_DIR}/${rust_target}/release/libmihomo_meter_shared_core.a"
  if [[ ! -f "${library_path}" ]]; then
    echo "macOS 共享核心静态库不存在：${library_path}" >&2
    exit 1
  fi
  echo "macOS 共享核心构建通过：${library_path}"
done
