#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local target_file="$2"

  if ! grep -Fq -- "${expected}" "${target_file}"; then
    echo "未找到预期内容：${expected}" >&2
    cat "${target_file}" >&2
    exit 1
  fi
}

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generator_script="${script_directory}/generate-download-badge-json.sh"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/mihomo-meter-download-badge-test.XXXXXX")"

cleanup() {
  rm -rf "${test_directory}"
}
trap cleanup EXIT

fake_bin_directory="${test_directory}/bin"
mkdir -p "${fake_bin_directory}"

cat >"${fake_bin_directory}/gh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${FAKE_GH_ARGUMENTS_PATH:-}" ]]; then
  printf '%s\n' "$@" >"${FAKE_GH_ARGUMENTS_PATH}"
fi
if [[ "${FAKE_GH_EXIT_STATUS:-0}" -ne 0 ]]; then
  exit "${FAKE_GH_EXIT_STATUS}"
fi
printf '%s' "${FAKE_GH_OUTPUT:-}"
EOF
chmod +x "${fake_bin_directory}/gh"

arguments_path="${test_directory}/gh-arguments.txt"
badge_path="${test_directory}/download-count.json"

PATH="${fake_bin_directory}:${PATH}" \
  FAKE_GH_ARGUMENTS_PATH="${arguments_path}" \
  FAKE_GH_OUTPUT=$'2\n3\n5\n' \
  "${generator_script}" \
  --repository HongXunPan/mihomo-meter \
  --output "${badge_path}"

expected_badge='{"schemaVersion":1,"label":"DMG 下载量","message":"10","color":"blue"}'
actual_badge="$(cat "${badge_path}")"
if [[ "${actual_badge}" != "${expected_badge}" ]]; then
  echo "徽章 JSON 不符合预期。" >&2
  echo "预期：${expected_badge}" >&2
  echo "实际：${actual_badge}" >&2
  exit 1
fi

assert_contains "--paginate" "${arguments_path}"
assert_contains "repos/HongXunPan/mihomo-meter/releases?per_page=100" "${arguments_path}"
assert_contains "select(.draft == false and .prerelease == false)" "${arguments_path}"
assert_contains 'select(.state == "uploaded")' "${arguments_path}"
assert_contains "macos-(arm64|x86_64|universal)" "${arguments_path}"

PATH="${fake_bin_directory}:${PATH}" \
  FAKE_GH_OUTPUT="" \
  "${generator_script}" \
  --repository HongXunPan/mihomo-meter \
  --output "${badge_path}"

expected_empty_badge='{"schemaVersion":1,"label":"DMG 下载量","message":"0","color":"blue"}'
actual_empty_badge="$(cat "${badge_path}")"
if [[ "${actual_empty_badge}" != "${expected_empty_badge}" ]]; then
  fail "没有 Release 时应生成下载量为 0 的徽章。"
fi

if PATH="${fake_bin_directory}:${PATH}" \
  FAKE_GH_EXIT_STATUS=1 \
  "${generator_script}" \
  --repository HongXunPan/mihomo-meter \
  --output "${badge_path}" >/dev/null 2>&1; then
  fail "GitHub API 请求失败时脚本不应成功。"
fi

if PATH="${fake_bin_directory}:${PATH}" \
  "${generator_script}" \
  --repository invalid-repository \
  --output "${badge_path}" >/dev/null 2>&1; then
  fail "无效仓库格式不应被接受。"
fi

echo "下载量徽章脚本测试通过。"
