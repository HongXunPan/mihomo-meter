#!/usr/bin/env bash
set -euo pipefail

app_path="/Applications/WidgetSigningPoC.app"
widget_path="${app_path}/Contents/PlugIns/WidgetSigningPoCWidget.appex"
app_identifier="com.HongXunPan.MihomoMeter.WidgetSigningPoC"
widget_identifier="${app_identifier}.Widget"
snapshot_relative_path="/Library/Application Support/com.HongXunPan.MihomoMeter.WidgetSigningPoC/"
snapshot_filename="widget-snapshot.txt"
app_file_entitlement="com.apple.security.temporary-exception.files.home-relative-path.read-write"
widget_file_entitlement="com.apple.security.temporary-exception.files.home-relative-path.read-only"
minutes="${1:-15}"

if [[ $# -gt 1 || ! "${minutes}" =~ ^([1-9]|[1-5][0-9]|60)$ ]]; then
  echo "用法：bash widgetkit-signing-poc-diagnose.sh [最近分钟数：1–60，默认 15]" >&2
  exit 2
fi

if [[ ! -d "${widget_path}" ]]; then
  echo "未找到已安装的 PoC 主应用及 Widget 扩展；请先从 DMG 安装到应用程序目录。" >&2
  exit 1
fi

if ! codesign --verify --deep --strict "${app_path}" >/dev/null 2>&1; then
  echo "已安装的 PoC 签名校验失败；不继续推断运行时授权。" >&2
  exit 1
fi

bundle_identifier() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null
}

bundle_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null
}

leaf_certificate_sha1() {
  local requirement
  requirement="$(codesign -dr - "$1" 2>&1)"
  sed -nE 's/.*certificate leaf = H"([[:xdigit:]]{40})".*/\1/p' <<<"${requirement}"
}

team_identifier() {
  local signing_details
  signing_details="$(codesign -dv --verbose=4 "$1" 2>&1)"
  sed -n 's/^TeamIdentifier=//p' <<<"${signing_details}"
}

has_file_entitlement() {
  local entitlements
  entitlements="$(codesign -d --entitlements - "$1" 2>&1)"
  grep -Fq "$2" <<<"${entitlements}" &&
    grep -Fq "${snapshot_relative_path}" <<<"${entitlements}" &&
    ! grep -Fq 'com.apple.security.application-groups' <<<"${entitlements}"
}

if [[ "$(bundle_identifier "${app_path}")" != "${app_identifier}" ]] ||
  [[ "$(bundle_identifier "${widget_path}")" != "${widget_identifier}" ]]; then
  echo "已安装包的 Bundle ID 与此 PoC 不一致；不继续推断运行时授权。" >&2
  exit 1
fi

app_leaf="$(leaf_certificate_sha1 "${app_path}")"
widget_leaf="$(leaf_certificate_sha1 "${widget_path}")"
app_team="$(team_identifier "${app_path}")"
widget_team="$(team_identifier "${widget_path}")"

certificate_state="无法确认"
if [[ "${app_leaf}" =~ ^[[:xdigit:]]{40}$ && "${app_leaf}" == "${widget_leaf}" ]]; then
  certificate_state="一致（叶证书 SHA-1 前 12 位：${app_leaf:0:12}）"
elif [[ -n "${app_leaf}" && -n "${widget_leaf}" ]]; then
  certificate_state="不一致"
fi

team_state="无法确认"
if [[ "${app_team}" == "not set" && "${widget_team}" == "not set" ]]; then
  team_state="主应用与 Widget 均未设置"
elif [[ -n "${app_team}" && -n "${widget_team}" ]]; then
  team_state="至少一方已设置或两者不同"
fi

file_permission_state="不一致或无法读取"
if has_file_entitlement "${app_path}" "${app_file_entitlement}" &&
  has_file_entitlement "${widget_path}" "${widget_file_entitlement}"; then
  file_permission_state="主应用读写、Widget 只读，均未声明 App Group"
fi

snapshot_directory="${HOME}${snapshot_relative_path}"
directory_state="不存在"
if [[ -d "${snapshot_directory}" ]]; then
  directory_state="存在"
fi

snapshot_state="不存在"
snapshot_mode="未读取"
snapshot_path="${snapshot_directory}${snapshot_filename}"
if [[ -f "${snapshot_path}" ]]; then
  snapshot_state="存在"
  snapshot_mode="$(stat -f '%Lp' "${snapshot_path}" 2>/dev/null || echo '无法读取')"
fi

registration_state="无法查询"
if registration="$(pluginkit -m -v -v -i "${widget_identifier}" 2>/dev/null)"; then
  registered_path="$(sed -n 's/^[[:space:]]*Path = //p' <<<"${registration}")"
  if [[ "${registered_path}" == "${widget_path}" ]]; then
    registration_state="与当前安装包一致"
  elif [[ -n "${registered_path}" ]]; then
    registration_state="存在其他注册路径"
  else
    registration_state="未观察到注册路径"
  fi
fi

app_file_denials=0
widget_file_denials=0
widget_tcc_denials=0
log_state="可读取"
predicate='(process == "sandboxd" OR process == "kernel" OR process == "tccd") AND '
predicate+='eventMessage CONTAINS[c] "WidgetSigningPoC"'
if system_logs="$(/usr/bin/log show --last "${minutes}m" --style compact --info --predicate "${predicate}" 2>/dev/null)"; then
  while IFS= read -r line; do
    if [[ "${line}" == *"deny("* && "${line}" == *"${app_identifier}"* ]] &&
      [[ "${line}" == *"${snapshot_filename}"* ]]; then
      ((app_file_denials += 1))
    fi
    if [[ "${line}" == *"deny("* && "${line}" == *"${widget_identifier}"* ]] &&
      [[ "${line}" == *"${snapshot_filename}"* ]]; then
      ((widget_file_denials += 1))
    fi
    if [[ "${line}" == *"kTCCServiceSystemPolicyAppData denied by TCC for WidgetSigningPoCWidget" ]]; then
      ((widget_tcc_denials += 1))
    fi
  done <<<"${system_logs}"
else
  log_state="系统日志不可读取"
fi

echo "WidgetKit 固定自签名专用目录 PoC 诊断（近 ${minutes} 分钟）"
echo "系统版本：$(sw_vers -productVersion)"
app_version="$(bundle_version "${app_path}" || true)"
widget_version="$(bundle_version "${widget_path}" || true)"
echo "已安装版本：主应用 ${app_version:-未知}，Widget ${widget_version:-未知}"
echo "签名校验：通过"
echo "叶证书：${certificate_state}"
echo "Team ID：${team_state}"
echo "文件权限声明：${file_permission_state}"
echo "用户目录中的专用文件夹：${directory_state}"
echo "快照文件：${snapshot_state}；权限模式：${snapshot_mode}"
echo "系统注册：${registration_state}"
echo "系统日志：${log_state}"
echo "专用文件沙盒拒绝记录：主应用 ${app_file_denials}，Widget ${widget_file_denials}"
echo "Widget App Data 拒绝记录：${widget_tcc_denials}"

if [[ "${certificate_state}" == 一致* && "${team_state}" == "主应用与 Widget 均未设置" ]] &&
  [[ "${file_permission_state}" == "主应用读写、Widget 只读，均未声明 App Group" ]] &&
  [[ "${registration_state}" == "与当前安装包一致" ]]; then
  echo "结论：静态身份与权限声明匹配；运行时是否可读仍以主应用和 Widget 界面结果为准。"
else
  echo "结论：静态证据尚不完整，不能据此判定专用文件授权成功或失败。"
fi
