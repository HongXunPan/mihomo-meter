#!/usr/bin/env bash

set -euo pipefail

if ! command -v xcrun >/dev/null 2>&1; then
  echo "未找到 xcrun，无法编译 Swift 探针。" >&2
  exit 1
fi

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
# shellcheck source=scripts/shared_core_macos_toolchain.sh
source "${script_directory}/shared_core_macos_toolchain.sh"

resolve_shared_core_macos_toolchain
host_architecture="${MIHOMO_METER_SHARED_CORE_ARCH:-$(uname -m)}"
rust_target="$(shared_core_macos_target_for_architecture "${host_architecture}")"
require_shared_core_macos_target "${rust_target}"

export CARGO_TARGET_DIR="${project_root}/.build/shared-core"
manifest_path="${project_root}/SharedCore/Cargo.toml"
fixture_path="${project_root}/SharedCore/TestVectors/traffic_scale.json"
library_directory="${CARGO_TARGET_DIR}/${rust_target}/release"
library_path="${library_directory}/libmihomo_meter_shared_core.a"
probe_directory="${project_root}/.codex-tmp/shared-core-probe"
probe_path="${probe_directory}/mihomo-meter-shared-core-probe"
module_cache_path="${probe_directory}/module-cache"

cleanup() {
  rm -rf "${probe_directory}"
}
trap cleanup EXIT

rustup run "${shared_core_rust_toolchain}" rustfmt --check \
  "${project_root}/SharedCore/src/lib.rs"
rustup run "${shared_core_rust_toolchain}" cargo clippy \
  --manifest-path "${manifest_path}" \
  --locked \
  --target "${rust_target}" \
  -- \
  -D warnings
rustup run "${shared_core_rust_toolchain}" cargo test \
  --manifest-path "${manifest_path}" \
  --locked \
  --target "${rust_target}"
rustup run "${shared_core_rust_toolchain}" cargo build \
  --manifest-path "${manifest_path}" \
  --locked \
  --release \
  --target "${rust_target}"

if [[ ! -f "${library_path}" ]]; then
  echo "共享核心静态库不存在：${library_path}" >&2
  exit 1
fi
if [[ ! -f "${fixture_path}" ]]; then
  echo "统一流量缩放向量不存在：${fixture_path}" >&2
  exit 1
fi

mkdir -p "${probe_directory}"
xcrun swiftc \
  -module-cache-path "${module_cache_path}" \
  -I "${project_root}/SharedCore/include" \
  -L "${library_directory}" \
  -lmihomo_meter_shared_core \
  "${project_root}/SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift" \
  "${project_root}/Sources/Domain/SharedCoreRuntimeStatus.swift" \
  "${project_root}/Sources/Application/SharedCoreRuntimeProbe.swift" \
  "${project_root}/Sources/Domain/TrafficRate.swift" \
  "${project_root}/Sources/Presentation/TrafficRateFormatter.swift" \
  "${project_root}/Sources/Presentation/TrafficStatisticsFormatter.swift" \
  "${project_root}/SharedCore/Adapters/Swift/Probe/main.swift" \
  -o "${probe_path}"

"${probe_path}" "${fixture_path}"
