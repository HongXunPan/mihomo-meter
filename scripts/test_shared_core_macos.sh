#!/usr/bin/env bash

set -euo pipefail

expected_rust_version="1.97.1"
rust_toolchain=""

resolve_rust_toolchain() {
  local candidate
  local version

  for candidate in "${expected_rust_version}" stable; do
    version="$(rustup run "${candidate}" rustc --version 2>/dev/null || true)"
    if [[ "${version}" == "rustc ${expected_rust_version} "* ]]; then
      rust_toolchain="${candidate}"
      return
    fi
  done

  echo "未找到完整的 Rust ${expected_rust_version} 工具链。" >&2
  exit 1
}

if ! command -v rustup >/dev/null 2>&1; then
  echo "未找到 rustup，无法构建共享核心。" >&2
  exit 1
fi
if ! command -v xcrun >/dev/null 2>&1; then
  echo "未找到 xcrun，无法编译 Swift 探针。" >&2
  exit 1
fi

resolve_rust_toolchain
rust_compiler_path="$(rustup which rustc --toolchain "${rust_toolchain}")"
export PATH="$(dirname "${rust_compiler_path}"):${PATH}"

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
host_architecture="${MIHOMO_METER_SHARED_CORE_ARCH:-$(uname -m)}"
case "${host_architecture}" in
  arm64)
    rust_target="aarch64-apple-darwin"
    ;;
  x86_64)
    rust_target="x86_64-apple-darwin"
    ;;
  *)
    echo "不支持的 macOS 共享核心架构：${host_architecture}" >&2
    exit 1
    ;;
esac

if ! rustup target list --toolchain "${rust_toolchain}" --installed |
  grep -Fxq "${rust_target}"; then
  echo "Rust ${expected_rust_version} 未安装目标 ${rust_target}。" >&2
  exit 1
fi

export CARGO_TARGET_DIR="${project_root}/.build/shared-core"
manifest_path="${project_root}/SharedCore/Cargo.toml"
library_directory="${CARGO_TARGET_DIR}/${rust_target}/release"
library_path="${library_directory}/libmihomo_meter_shared_core.a"
probe_directory="${project_root}/.codex-tmp/shared-core-probe"
probe_path="${probe_directory}/mihomo-meter-shared-core-probe"
module_cache_path="${probe_directory}/module-cache"

cleanup() {
  rm -rf "${probe_directory}"
}
trap cleanup EXIT

rustup run "${rust_toolchain}" rustfmt --check \
  "${project_root}/SharedCore/src/lib.rs"
rustup run "${rust_toolchain}" cargo clippy \
  --manifest-path "${manifest_path}" \
  --locked \
  --target "${rust_target}" \
  -- \
  -D warnings
rustup run "${rust_toolchain}" cargo test \
  --manifest-path "${manifest_path}" \
  --locked \
  --target "${rust_target}"
rustup run "${rust_toolchain}" cargo build \
  --manifest-path "${manifest_path}" \
  --locked \
  --release \
  --target "${rust_target}"

if [[ ! -f "${library_path}" ]]; then
  echo "共享核心静态库不存在：${library_path}" >&2
  exit 1
fi

mkdir -p "${probe_directory}"
xcrun swiftc \
  -module-cache-path "${module_cache_path}" \
  -I "${project_root}/SharedCore/include" \
  -L "${library_directory}" \
  -lmihomo_meter_shared_core \
  "${project_root}/SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift" \
  "${project_root}/SharedCore/Adapters/Swift/Probe/main.swift" \
  -o "${probe_path}"

"${probe_path}"
