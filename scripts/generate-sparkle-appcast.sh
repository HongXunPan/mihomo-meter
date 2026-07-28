#!/usr/bin/env bash

set -euo pipefail

readonly repository_url="https://github.com/HongXunPan/mihomo-meter"
readonly expected_minimum_system_version="14.0"

usage() {
  cat <<'EOF'
用法：
  scripts/generate-sparkle-appcast.sh \
    --version X.Y.Z \
    --dmg dist/Mihomo-Meter-X.Y.Z-macos-universal.dmg \
    --release-notes dist/RELEASE_NOTES.md \
    --private-key /路径/sparkle-ed25519-private-key \
    --generate-appcast /路径/generate_appcast \
    --output dist/appcast.xml

说明：
  使用 Sparkle 官方 generate_appcast 为 Universal DMG 生成 Ed25519 签名更新清单。
  私钥只用于当前进程签名，不会复制到输出目录。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

absolute_path() {
  if [[ "$1" == /* ]]; then
    printf '%s\n' "$1"
  else
    printf '%s\n' "${project_root}/$1"
  fi
}

version=""
dmg_path=""
release_notes_path=""
private_key_path=""
generate_appcast_path=""
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fail "--version 缺少参数。"
      version="$2"
      shift 2
      ;;
    --dmg)
      [[ $# -ge 2 ]] || fail "--dmg 缺少参数。"
      dmg_path="$2"
      shift 2
      ;;
    --release-notes)
      [[ $# -ge 2 ]] || fail "--release-notes 缺少参数。"
      release_notes_path="$2"
      shift 2
      ;;
    --private-key)
      [[ $# -ge 2 ]] || fail "--private-key 缺少参数。"
      private_key_path="$2"
      shift 2
      ;;
    --generate-appcast)
      [[ $# -ge 2 ]] || fail "--generate-appcast 缺少参数。"
      generate_appcast_path="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || fail "--output 缺少参数。"
      output_path="$2"
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

[[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
  fail "版本号必须使用无前导零的 X.Y.Z 格式。"
[[ -n "${dmg_path}" ]] || fail "必须提供 --dmg。"
[[ -n "${release_notes_path}" ]] || fail "必须提供 --release-notes。"
[[ -n "${private_key_path}" ]] || fail "必须提供 --private-key。"
[[ -n "${generate_appcast_path}" ]] || fail "必须提供 --generate-appcast。"
[[ -n "${output_path}" ]] || fail "必须提供 --output。"

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
dmg_path="$(absolute_path "${dmg_path}")"
release_notes_path="$(absolute_path "${release_notes_path}")"
private_key_path="$(absolute_path "${private_key_path}")"
generate_appcast_path="$(absolute_path "${generate_appcast_path}")"
output_path="$(absolute_path "${output_path}")"

[[ -f "${dmg_path}" ]] || fail "找不到 Universal DMG：${dmg_path}"
[[ -s "${release_notes_path}" ]] || fail "找不到有效发布说明：${release_notes_path}"
[[ -s "${private_key_path}" ]] || fail "找不到有效 Sparkle Ed25519 私钥文件。"
[[ -x "${generate_appcast_path}" ]] || fail "Sparkle generate_appcast 不存在或不可执行。"

archive_name="Mihomo-Meter-${version}-macos-universal.dmg"
[[ "$(basename "${dmg_path}")" == "${archive_name}" ]] ||
  fail "Sparkle 更新包必须使用预期的 Universal DMG 文件名：${archive_name}"

mkdir -p "${project_root}/.build" "$(dirname "${output_path}")"
work_directory="$(mktemp -d "${project_root}/.build/sparkle-appcast-work.XXXXXX")"
cleanup() {
  rm -rf "${work_directory}"
}
trap cleanup EXIT

cp "${dmg_path}" "${work_directory}/${archive_name}"
cp \
  "${release_notes_path}" \
  "${work_directory}/Mihomo-Meter-${version}-macos-universal.md"

generated_appcast_path="${work_directory}/appcast.xml"
"${generate_appcast_path}" \
  --ed-key-file "${private_key_path}" \
  --download-url-prefix "${repository_url}/releases/download/v${version}/" \
  --embed-release-notes \
  --maximum-deltas 0 \
  --link "${repository_url}/releases/tag/v${version}" \
  -o "${generated_appcast_path}" \
  "${work_directory}"

xmllint --noout "${generated_appcast_path}"
minimum_system_version="$(
  xmllint \
    --xpath \
    'string(/*[local-name()="rss"]/*[local-name()="channel"]/*[local-name()="item"][1]/*[local-name()="minimumSystemVersion"])' \
    "${generated_appcast_path}"
)"
if [[ "${minimum_system_version}" != "${expected_minimum_system_version}" &&
  "${minimum_system_version}" != "${expected_minimum_system_version}.0" ]]; then
  fail "生成的 appcast 最低系统版本不是 macOS ${expected_minimum_system_version}。"
fi
grep -Fq "sparkle:edSignature=" "${generated_appcast_path}" ||
  fail "生成的 appcast 缺少 Ed25519 更新签名。"
grep -Fq \
  "${repository_url}/releases/download/v${version}/${archive_name}" \
  "${generated_appcast_path}" ||
  fail "生成的 appcast 未指向当前版本 Universal DMG。"

install -m 0644 "${generated_appcast_path}" "${output_path}"
echo "Sparkle appcast 生成完成：${output_path}"
