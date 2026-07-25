#!/usr/bin/env bash

set -euo pipefail

readonly bundle_identifier="com.HongXunPan.MihomoMeter"
readonly default_signing_identity="Mihomo Meter By HongXunPan"

usage() {
  cat <<'EOF'
用法：
  scripts/build-release-dmg.sh \
    --version X.Y.Z \
    --build-number 正整数 \
    [--architecture arm64|x86_64|universal] \
    [--signing-identity "Mihomo Meter By HongXunPan"] \
    [--output-dir 输出目录]

说明：
  按指定架构构建 Release 应用，默认构建 universal。
  使用固定自签名证书签名，并生成对应 DMG 与 SHA256SUMS。
  证书必须已经导入当前用户钥匙串、包含私钥，并被当前用户信任用于代码签名。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "未找到必需命令：$1"
  fi
}

verify_app() {
  local target_app_path="$1"
  local expected_version="$2"
  local expected_build_number="$3"
  local expected_certificate_sha1="$4"
  local expected_architecture="$5"
  local entitlements_output
  local requirement_output
  local actual_version
  local actual_build_number
  local executable_path
  local executable_architectures

  codesign --verify --deep --strict --verbose=2 "${target_app_path}"

  requirement_output="$(codesign -d -r- "${target_app_path}" 2>&1)"
  if ! grep -Fiq "identifier \"${bundle_identifier}\"" <<<"${requirement_output}" ||
    ! grep -Fiq \
      "certificate root = H\"${expected_certificate_sha1}\"" \
      <<<"${requirement_output}"; then
    echo "实际代码指定要求：${requirement_output}" >&2
    fail "Release 应用的代码指定要求与固定 Bundle ID 或签名证书不匹配。"
  fi

  entitlements_output="$(codesign -d --entitlements - "${target_app_path}" 2>&1)"
  if ! grep -Fq "com.apple.security.app-sandbox" <<<"${entitlements_output}" ||
    ! grep -Fq "com.apple.security.network.client" <<<"${entitlements_output}"; then
    fail "Release 应用缺少沙盒或网络客户端权限。"
  fi

  if grep -Fq "keychain-access-groups" <<<"${entitlements_output}"; then
    fail "Release 应用不应声明需要 provisioning profile 的 Keychain 访问组。"
  fi

  "${project_root}/scripts/verify-sparkle-release.sh" \
    --app "${target_app_path}" \
    --bundle-identifier "${bundle_identifier}"

  actual_version="$(
    /usr/libexec/PlistBuddy \
      -c 'Print :CFBundleShortVersionString' \
      "${target_app_path}/Contents/Info.plist"
  )"
  actual_build_number="$(
    /usr/libexec/PlistBuddy \
      -c 'Print :CFBundleVersion' \
      "${target_app_path}/Contents/Info.plist"
  )"
  if [[ "${actual_version}" != "${expected_version}" ]]; then
    fail "Release 应用版本不匹配：预期 ${expected_version}，实际 ${actual_version}。"
  fi
  if [[ "${actual_build_number}" != "${expected_build_number}" ]]; then
    fail "Release 应用构建号不匹配：预期 ${expected_build_number}，实际 ${actual_build_number}。"
  fi

  executable_path="${target_app_path}/Contents/MacOS/MihomoMeter"
  executable_architectures="$(lipo -archs "${executable_path}")"
  case "${expected_architecture}" in
    arm64|x86_64)
      if [[ "${executable_architectures}" != "${expected_architecture}" ]]; then
        fail \
          "Release 应用架构不匹配：预期 ${expected_architecture}，实际为：${executable_architectures}"
      fi
      ;;
    universal)
      if [[ " ${executable_architectures} " != *" arm64 "* ]] ||
        [[ " ${executable_architectures} " != *" x86_64 "* ]]; then
        fail "Universal Release 应用必须同时包含 arm64 与 x86_64，实际为：${executable_architectures}"
      fi
      ;;
    *)
      fail "内部错误：不支持校验架构 ${expected_architecture}"
      ;;
  esac
}

version=""
build_number=""
architecture="universal"
signing_identity="${default_signing_identity}"
output_directory=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fail "--version 缺少参数。"
      version="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || fail "--build-number 缺少参数。"
      build_number="$2"
      shift 2
      ;;
    --architecture)
      [[ $# -ge 2 ]] || fail "--architecture 缺少参数。"
      architecture="$2"
      shift 2
      ;;
    --signing-identity)
      [[ $# -ge 2 ]] || fail "--signing-identity 缺少参数。"
      signing_identity="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || fail "--output-dir 缺少参数。"
      output_directory="$2"
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

if [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  fail "版本号必须使用无前导零的 X.Y.Z 格式。"
fi
if [[ ! "${build_number}" =~ ^[1-9][0-9]*$ ]]; then
  fail "构建号必须是正整数。"
fi
case "${architecture}" in
  arm64)
    build_architectures="arm64"
    ;;
  x86_64)
    build_architectures="x86_64"
    ;;
  universal)
    build_architectures="arm64 x86_64"
    ;;
  *)
    fail "架构必须是 arm64、x86_64 或 universal。"
    ;;
esac
if [[ "${signing_identity}" != "${default_signing_identity}" ]]; then
  fail "正式包签名证书必须固定为：${default_signing_identity}"
fi

for required_command in codesign hdiutil lipo security shasum xcodebuild; do
  require_command "${required_command}"
done

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
mkdir -p "${project_root}/.build"

if [[ -z "${output_directory}" ]]; then
  output_directory="${project_root}/.build/release"
elif [[ "${output_directory}" != /* ]]; then
  output_directory="${project_root}/${output_directory}"
fi
mkdir -p "${output_directory}"
output_directory="$(cd "${output_directory}" && pwd)"

signing_identities="$(security find-identity -v -p codesigning 2>&1)"
signing_certificate_sha1="$(
  awk -v name="${signing_identity}" \
    'index($0, "\"" name "\"") > 0 { print $2; exit }' \
    <<<"${signing_identities}"
)"
if [[ ! "${signing_certificate_sha1}" =~ ^[A-Fa-f0-9]{40}$ ]]; then
  fail "未找到名称完全匹配且含私钥的有效代码签名证书：${signing_identity}"
fi

work_directory="$(mktemp -d "${project_root}/.build/release-work.XXXXXX")"
derived_data_path="${work_directory}/DerivedData"
staging_directory="${work_directory}/dmg-root"
mount_point="${work_directory}/mounted-dmg"
app_path="${derived_data_path}/Build/Products/Release/MihomoMeter.app"
dmg_path="${output_directory}/Mihomo-Meter-${version}-macos-${architecture}.dmg"
checksum_path="${output_directory}/SHA256SUMS"
dmg_is_mounted=0

cleanup() {
  if [[ ${dmg_is_mounted} -eq 1 ]]; then
    hdiutil detach "${mount_point}" -force >/dev/null 2>&1 || true
  fi
  rm -rf "${work_directory}"
}
trap cleanup EXIT

cd "${project_root}"

xcodebuild \
  -quiet \
  -project MihomoMeter.xcodeproj \
  -scheme MihomoMeter \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${derived_data_path}" \
  ARCHS="${build_architectures}" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="${version}" \
  CURRENT_PROJECT_VERSION="${build_number}" \
  build

designated_requirement="$(
  printf 'designated => identifier "%s" and anchor = H"%s"' \
    "${bundle_identifier}" \
    "${signing_certificate_sha1}"
)"

"${project_root}/scripts/sign-sparkle-framework.sh" \
  --app "${app_path}" \
  --identity "${signing_certificate_sha1}"

codesign \
  --force \
  --sign "${signing_certificate_sha1}" \
  --identifier "${bundle_identifier}" \
  --requirements "=${designated_requirement}" \
  --entitlements "${project_root}/MihomoMeterSelfSignedRelease.entitlements" \
  --options runtime \
  --timestamp=none \
  "${app_path}"

verify_app \
  "${app_path}" \
  "${version}" \
  "${build_number}" \
  "${signing_certificate_sha1}" \
  "${architecture}"

mkdir -p "${staging_directory}"
ditto "${app_path}" "${staging_directory}/MihomoMeter.app"
ln -s /Applications "${staging_directory}/Applications"

rm -f "${dmg_path}" "${checksum_path}"
hdiutil create \
  -volname "Mihomo Meter ${version}" \
  -srcfolder "${staging_directory}" \
  -ov \
  -format UDZO \
  "${dmg_path}"

codesign \
  --force \
  --sign "${signing_certificate_sha1}" \
  --timestamp=none \
  "${dmg_path}"
codesign --verify --verbose=2 "${dmg_path}"

mkdir -p "${mount_point}"
hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "${mount_point}" \
  "${dmg_path}" >/dev/null
dmg_is_mounted=1

if [[ ! -d "${mount_point}/MihomoMeter.app" ]] ||
  [[ "$(readlink "${mount_point}/Applications")" != "/Applications" ]]; then
  fail "DMG 内容校验失败。"
fi
verify_app \
  "${mount_point}/MihomoMeter.app" \
  "${version}" \
  "${build_number}" \
  "${signing_certificate_sha1}" \
  "${architecture}"
"${project_root}/scripts/smoke-test-release-launch.sh" \
  --app "${mount_point}/MihomoMeter.app"

hdiutil detach "${mount_point}" >/dev/null
dmg_is_mounted=0

(
  cd "${output_directory}"
  shasum -a 256 "$(basename "${dmg_path}")" >"$(basename "${checksum_path}")"
)

echo
echo "Release DMG 构建完成：${dmg_path}"
echo "SHA-256 校验文件：${checksum_path}"
