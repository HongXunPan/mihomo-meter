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

assert_not_contains() {
  local unexpected="$1"
  local target_file="$2"

  if grep -Fq -- "${unexpected}" "${target_file}"; then
    echo "发现不应出现的内容：${unexpected}" >&2
    cat "${target_file}" >&2
    exit 1
  fi
}

assert_occurrences() {
  local expected_count="$1"
  local expected="$2"
  local target_file="$3"
  local actual_count

  actual_count="$(grep -Fc -- "${expected}" "${target_file}" || true)"
  if [[ "${actual_count}" -ne "${expected_count}" ]]; then
    echo "内容出现次数不符合预期：${expected}" >&2
    echo "预期 ${expected_count} 次，实际 ${actual_count} 次。" >&2
    cat "${target_file}" >&2
    exit 1
  fi
}

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generator_script="${script_directory}/generate-release-notes.sh"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/mihomo-meter-release-notes-test.XXXXXX")"

cleanup() {
  rm -rf "${test_directory}"
}
trap cleanup EXIT

cd "${test_directory}"
git init --quiet
git config user.name "Mihomo Meter Tests"
git config user.email "tests@example.invalid"

commit_with_subject() {
  local subject="$1"

  printf '%s\n' "${subject}" >>history.txt
  git add -- history.txt
  git commit --quiet -m "${subject}"
}

commit_with_subject "chore: 初始化测试仓库"
git tag v0.1.0

commit_with_subject "feat: 增加状态栏展示"
first_feature_hash="$(git rev-parse --short HEAD)"
commit_with_subject "feat(ui): 增加状态栏展示"
second_feature_hash="$(git rev-parse --short HEAD)"
commit_with_subject "修复: 处理连接超时"
commit_with_subject "docs: 更新安装说明"
commit_with_subject "重构: 拆分监控职责"
commit_with_subject "调整其他交互"
commit_with_subject "fixup! feat: 不应展示的功能修正"
commit_with_subject "squash! docs: 不应展示的文档修正"

notes_path="${test_directory}/release-notes.md"
"${generator_script}" --version 0.2.0 --output "${notes_path}"

assert_contains "## 本次更新" "${notes_path}"
assert_contains "### 新增功能" "${notes_path}"
assert_contains "增加状态栏展示" "${notes_path}"
assert_occurrences 1 "增加状态栏展示" "${notes_path}"
assert_contains "\`${first_feature_hash}\`" "${notes_path}"
assert_contains "\`${second_feature_hash}\`" "${notes_path}"
assert_contains "### 问题修复与安全" "${notes_path}"
assert_contains "处理连接超时" "${notes_path}"
assert_contains "### 文档更新" "${notes_path}"
assert_contains "更新安装说明" "${notes_path}"
assert_contains "### 内部改进" "${notes_path}"
assert_contains "拆分监控职责" "${notes_path}"
assert_contains "### 其他变化" "${notes_path}"
assert_contains "调整其他交互" "${notes_path}"
assert_contains '`v0.1.0..v0.2.0`' "${notes_path}"
assert_not_contains "初始化测试仓库" "${notes_path}"
assert_not_contains "feat:" "${notes_path}"
assert_not_contains "不应展示的功能修正" "${notes_path}"
assert_not_contains "不应展示的文档修正" "${notes_path}"

git tag v0.2.0
if "${generator_script}" --version 0.3.0 --output "${notes_path}" >/dev/null 2>&1; then
  fail "没有新提交时不应生成发布说明。"
fi

commit_with_subject "fixup! feat: 标签后仅有的修正"
if "${generator_script}" --version 0.3.0 --output "${notes_path}" >/dev/null 2>&1; then
  fail "只有 fixup! / squash! 提交时不应生成发布说明。"
fi

echo "发布说明脚本测试通过。"
