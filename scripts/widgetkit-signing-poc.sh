#!/bin/bash
set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

[[ -n "${SIGNING_P12_BASE64:-}" ]] || fail "缺少固定自签名证书内容。"
[[ -n "${SIGNING_P12_PASSWORD:-}" ]] || fail "缺少固定自签名证书密码。"

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_directory}/.." && pwd)"
work_directory="${project_root}/.codex-tmp/widgetkit-ci-signing-${GITHUB_RUN_ID:-local}"
output_directory="${project_root}/dist"
derived_data_path="${work_directory}/DerivedData"
app_path="${derived_data_path}/Build/Products/Release/WidgetSigningPoC.app"
widget_path="${app_path}/Contents/PlugIns/WidgetSigningPoCWidget.appex"
keychain_path="${work_directory}/widgetkit-signing.keychain-db"
original_keychains_path="${work_directory}/original-keychains.txt"
certificate_path="${work_directory}/signing.p12"
certificate_pem_path="${work_directory}/signing.pem"
trust_helper_path="${work_directory}/add-certificate-trust"
staging_directory="${work_directory}/dmg-root"
mount_point="${work_directory}/mounted-dmg"
dmg_path="${output_directory}/widgetkit-signing-poc.dmg"
report_path="${output_directory}/widgetkit-signing-poc-verification.txt"
signing_identity="Mihomo Meter By HongXunPan"
app_identifier="com.HongXunPan.MihomoMeter.WidgetSigningPoC"
widget_identifier="${app_identifier}.Widget"
group_identifier="group.com.HongXunPan.MihomoMeter.WidgetSigningPoC"
mounted=0
keychain_created=0

cleanup() {
  local result=$?
  trap - EXIT
  if [[ ${mounted} -eq 1 ]]; then
    hdiutil detach "${mount_point}" -force >/dev/null 2>&1 || true
  fi
  if [[ -f "${original_keychains_path}" ]]; then
    local original_keychains=()
    while IFS= read -r keychain; do
      original_keychains+=("${keychain}")
    done <"${original_keychains_path}"
    security list-keychains -d user -s "${original_keychains[@]}" >/dev/null || true
  fi
  if [[ ${keychain_created} -eq 1 ]]; then
    security delete-keychain "${keychain_path}" >/dev/null || true
  fi
  rm -rf "${work_directory}"
  exit "${result}"
}
trap cleanup EXIT

mkdir -p "${work_directory}" "${output_directory}"

xcodebuild \
  -quiet \
  -project "${project_root}/PoC/WidgetSigning/WidgetSigningPoC.xcodeproj" \
  -scheme WidgetSigningPoC \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${derived_data_path}" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

[[ -d "${widget_path}" ]] || fail "构建产物未嵌入 Widget 扩展。"

security list-keychains -d user |
  sed -e 's/^[[:space:]]*"//' -e 's/"$//' >"${original_keychains_path}"
printf '%s' "${SIGNING_P12_BASE64}" | /usr/bin/base64 -D >"${certificate_path}"
keychain_password="$(openssl rand -hex 24)"
security create-keychain -p "${keychain_password}" "${keychain_path}"
keychain_created=1
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${keychain_password}" "${keychain_path}"

original_keychains=()
while IFS= read -r keychain; do
  original_keychains+=("${keychain}")
done <"${original_keychains_path}"
security list-keychains -d user -s "${keychain_path}" "${original_keychains[@]}"
security import "${certificate_path}" \
  -k "${keychain_path}" \
  -P "${SIGNING_P12_PASSWORD}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "${keychain_password}" \
  "${keychain_path}"

security find-certificate \
  -c "${signing_identity}" \
  -p \
  "${keychain_path}" >"${certificate_pem_path}"
xcrun swiftc \
  "${project_root}/scripts/add-release-certificate-trust.swift" \
  -framework Security \
  -o "${trust_helper_path}"
sudo -n "${trust_helper_path}" "${certificate_pem_path}"

signing_identities="$(security find-identity -v -p codesigning "${keychain_path}")"
signing_certificate_sha1="$(
  awk -v name="${signing_identity}" \
    'index($0, "\"" name "\"") > 0 { print $2; exit }' \
    <<<"${signing_identities}"
)"
[[ "${signing_certificate_sha1}" =~ ^[A-Fa-f0-9]{40}$ ]] ||
  fail "固定自签名证书未成为有效代码签名身份。"

codesign \
  --force \
  --sign "${signing_certificate_sha1}" \
  --identifier "${widget_identifier}" \
  --entitlements "${project_root}/PoC/WidgetSigning/Widget/Widget.entitlements" \
  --options runtime \
  --timestamp=none \
  "${widget_path}"
codesign \
  --force \
  --sign "${signing_certificate_sha1}" \
  --identifier "${app_identifier}" \
  --entitlements "${project_root}/PoC/WidgetSigning/App/App.entitlements" \
  --options runtime \
  --timestamp=none \
  "${app_path}"

codesign --verify --deep --strict --verbose=2 "${app_path}"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_path}/Contents/Info.plist")" == "${app_identifier}" ]] ||
  fail "主 App Bundle ID 不匹配。"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${widget_path}/Contents/Info.plist")" == "${widget_identifier}" ]] ||
  fail "Widget Bundle ID 不匹配。"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "${widget_path}/Contents/Info.plist")" == 'com.apple.widgetkit-extension' ]] ||
  fail "Widget 扩展点不匹配。"
for signed_bundle in "${app_path}" "${widget_path}"; do
  entitlements="$(codesign -d --entitlements - "${signed_bundle}" 2>&1)"
  grep -Fq "${group_identifier}" <<<"${entitlements}" ||
    fail "签名产物缺少预期 App Group：${signed_bundle}"
done

mkdir -p "${staging_directory}" "${mount_point}"
ditto "${app_path}" "${staging_directory}/WidgetSigningPoC.app"
ln -s /Applications "${staging_directory}/Applications"
hdiutil create \
  -ov \
  -volname 'WidgetKit 签名 PoC' \
  -srcfolder "${staging_directory}" \
  -format UDZO \
  "${dmg_path}"
codesign \
  --force \
  --sign "${signing_certificate_sha1}" \
  --timestamp=none \
  "${dmg_path}"
codesign --verify --verbose=2 "${dmg_path}"
hdiutil attach -readonly -nobrowse -mountpoint "${mount_point}" "${dmg_path}"
mounted=1
codesign --verify --deep --strict --verbose=2 "${mount_point}/WidgetSigningPoC.app"
[[ -d "${mount_point}/WidgetSigningPoC.app/Contents/PlugIns/WidgetSigningPoCWidget.appex" ]] ||
  fail "DMG 内缺少 Widget 扩展。"
hdiutil detach "${mount_point}"
mounted=0

cat >"${report_path}" <<EOF
测试范围：固定自签名证书的 WidgetKit 扩展静态打包与签名
主应用 Bundle ID：${app_identifier}
Widget Bundle ID：${widget_identifier}
共享组：${group_identifier}
签名证书：${signing_identity}
验证结果：主应用、嵌入扩展及 DMG 签名校验通过
未验证：共享容器运行时授权、小组件库可见性、用户安装交互
EOF
echo "签名 PoC 产物：${dmg_path}"
