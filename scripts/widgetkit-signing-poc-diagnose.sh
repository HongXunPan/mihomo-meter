#!/usr/bin/env bash
set -euo pipefail

app_path="/Applications/WidgetSigningPoC.app"
widget_path="${app_path}/Contents/PlugIns/WidgetSigningPoCWidget.appex"
app_identifier="com.HongXunPan.MihomoMeter.WidgetSigningPoC"
widget_identifier="${app_identifier}.Widget"
group_identifier="group.com.HongXunPan.MihomoMeter.WidgetSigningPoC"
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

has_group_entitlement() {
  local entitlements
  entitlements="$(codesign -d --entitlements - "$1" 2>&1)"
  grep -Fq "${group_identifier}" <<<"${entitlements}"
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

group_state="不一致或无法读取"
if has_group_entitlement "${app_path}" && has_group_entitlement "${widget_path}"; then
  group_state="双方均声明目标 App Group"
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

app_group_rejections=0
widget_group_rejections=0
app_tcc_grants=0
widget_tcc_denials=0
log_state="可读取"
predicate='(process == "containermanagerd" OR process == "sandboxd") AND '
predicate+='(eventMessage CONTAINS[c] "WidgetSigningPoC" OR '
predicate+='eventMessage CONTAINS[c] "group.com.HongXunPan.MihomoMeter")'
if system_logs="$(/usr/bin/log show --last "${minutes}m" --style compact --info --predicate "${predicate}" 2>/dev/null)"; then
  while IFS= read -r line; do
    if [[ "${line}" == *"[${app_identifier}] requesting [${group_identifier}]: REJECTED"* ]] &&
      [[ "${line}" == *"signature does not allow it to access a TCC-protected group container"* ]]; then
      ((app_group_rejections += 1))
    fi
    if [[ "${line}" == *"[${widget_identifier}] requesting [${group_identifier}]: REJECTED"* ]] &&
      [[ "${line}" == *"signature does not allow it to access a TCC-protected group container"* ]]; then
      ((widget_group_rejections += 1))
    fi
    if [[ "${line}" == *"kTCCServiceSystemPolicyAppData granted by TCC for WidgetSigningPoC" ]]; then
      ((app_tcc_grants += 1))
    fi
    if [[ "${line}" == *"kTCCServiceSystemPolicyAppData denied by TCC for WidgetSigningPoCWidget" ]]; then
      ((widget_tcc_denials += 1))
    fi
  done <<<"${system_logs}"
else
  log_state="系统日志不可读取"
fi

echo "WidgetKit 自签名 PoC 诊断（近 ${minutes} 分钟）"
echo "系统版本：$(sw_vers -productVersion)"
app_version="$(bundle_version "${app_path}" || true)"
widget_version="$(bundle_version "${widget_path}" || true)"
echo "已安装版本：主应用 ${app_version:-未知}，Widget ${widget_version:-未知}"
echo "签名校验：通过"
echo "叶证书：${certificate_state}"
echo "Team ID：${team_state}"
echo "App Group 权限声明：${group_state}"
echo "系统注册：${registration_state}"
echo "系统日志：${log_state}"
echo "群组容器签名拒绝次数：主应用 ${app_group_rejections}，Widget ${widget_group_rejections}"
echo "App Data 授权记录次数：主应用获准 ${app_tcc_grants}，Widget 被拒 ${widget_tcc_denials}"

if [[ "${certificate_state}" == 一致* && "${team_state}" == "主应用与 Widget 均未设置" ]] &&
  [[ "${group_state}" == "双方均声明目标 App Group" ]] &&
  [[ "${registration_state}" == "与当前安装包一致" ]] &&
  (( app_group_rejections > 0 && widget_group_rejections > 0 && widget_tcc_denials > 0 )); then
  echo "结论：本时间窗内观察到固定自签 PoC 的 App Group 运行时授权被拒；请与 Widget 的 257 截图对照。"
else
  echo "结论：证据尚不完整，不能据此判定共享容器授权成功或失败。"
fi
