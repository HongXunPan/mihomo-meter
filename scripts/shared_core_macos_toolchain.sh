#!/usr/bin/env bash

readonly shared_core_expected_rust_version="1.97.1"
shared_core_rust_toolchain=""
shared_core_rust_bin_directory=""

resolve_shared_core_macos_toolchain() {
  local candidate
  local compiler_path
  local version

  if ! command -v rustup >/dev/null 2>&1; then
    echo "未找到 rustup，无法构建共享核心。" >&2
    return 1
  fi

  for candidate in "${shared_core_expected_rust_version}" stable; do
    version="$(rustup run "${candidate}" rustc --version 2>/dev/null || true)"
    if [[ "${version}" == "rustc ${shared_core_expected_rust_version} "* ]]; then
      shared_core_rust_toolchain="${candidate}"
      break
    fi
  done

  if [[ -z "${shared_core_rust_toolchain}" ]]; then
    echo "未找到完整的 Rust ${shared_core_expected_rust_version} 工具链。" >&2
    return 1
  fi

  compiler_path="$(
    rustup which rustc --toolchain "${shared_core_rust_toolchain}"
  )"
  if [[ ! -f "${compiler_path}" ]]; then
    echo "无法定位 Rust ${shared_core_expected_rust_version} 编译器。" >&2
    return 1
  fi

  shared_core_rust_bin_directory="$(dirname "${compiler_path}")"
  export PATH="${shared_core_rust_bin_directory}:${PATH}"
}

shared_core_macos_target_for_architecture() {
  case "$1" in
    arm64)
      echo "aarch64-apple-darwin"
      ;;
    x86_64)
      echo "x86_64-apple-darwin"
      ;;
    *)
      echo "不支持的 macOS 共享核心架构：$1" >&2
      return 1
      ;;
  esac
}

require_shared_core_macos_target() {
  local rust_target="$1"

  if ! rustup target list \
    --toolchain "${shared_core_rust_toolchain}" \
    --installed | grep -Fxq "${rust_target}"; then
    echo "Rust ${shared_core_expected_rust_version} 未安装目标 ${rust_target}。" >&2
    return 1
  fi
}
