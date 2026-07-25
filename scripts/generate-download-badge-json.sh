#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  scripts/generate-download-badge-json.sh \
    --repository OWNER/REPO \
    --output 输出文件

说明：
  汇总公开正式 Release 中三个 macOS DMG 资产的下载次数。
  草稿、预发布、未上传完成的资产、更新清单和校验文件不会计入。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

repository=""
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository)
      [[ $# -ge 2 ]] || fail "--repository 缺少参数。"
      repository="$2"
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
      echo "不支持的参数：$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "${repository}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  fail "仓库必须使用 OWNER/REPO 格式。"
fi
if [[ -z "${output_path}" ]]; then
  fail "必须指定 --output。"
fi
if ! command -v gh >/dev/null 2>&1; then
  fail "未找到必需命令：gh"
fi
if ! command -v awk >/dev/null 2>&1; then
  fail "未找到必需命令：awk"
fi

release_asset_filter='.[]
| select(.draft == false and .prerelease == false)
| .assets[]
| select(.state == "uploaded")
| select(
    .name
    | test(
        "^Mihomo-Meter-(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)-macos-(arm64|x86_64|universal)\\.dmg$"
      )
  )
| .download_count'

if ! download_counts="$(
  gh api \
    --paginate \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/${repository}/releases?per_page=100" \
    --jq "${release_asset_filter}"
)"; then
  fail "读取 GitHub Release 下载统计失败。"
fi

download_count="$(
  printf '%s\n' "${download_counts}" |
    awk '
      NF > 0 {
        if ($0 !~ /^[0-9]+$/) {
          print "GitHub API 返回了无效的下载次数：" $0 > "/dev/stderr"
          exit 1
        }
        total += $0
      }
      END {
        if (total == "") {
          total = 0
        }
        printf "%.0f\n", total
      }
    '
)"

if [[ "${output_path}" != /* ]]; then
  output_path="${PWD}/${output_path}"
fi
mkdir -p "$(dirname "${output_path}")"

temporary_output="${output_path}.tmp.$$"
cleanup() {
  rm -f "${temporary_output}"
}
trap cleanup EXIT

printf \
  '{"schemaVersion":1,"label":"DMG 下载量","message":"%s","color":"blue"}\n' \
  "${download_count}" >"${temporary_output}"
mv "${temporary_output}" "${output_path}"
