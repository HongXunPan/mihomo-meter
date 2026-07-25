#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  scripts/generate-release-notes.sh \
    --version X.Y.Z \
    --output 输出文件

说明：
  读取上一个 vX.Y.Z 标签到当前提交之间的非合并提交。
  根据提交信息前缀生成面向用户的中文分类摘要。
  相同分类下标题完全一致的提交会合并，并过滤 fixup! / squash!。
EOF
}

fail() {
  echo "$1" >&2
  exit 1
}

version=""
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fail "--version 缺少参数。"
      version="$2"
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

if [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  fail "版本号必须使用无前导零的 X.Y.Z 格式。"
fi
if [[ -z "${output_path}" ]]; then
  fail "必须指定 --output。"
fi
if ! command -v git >/dev/null 2>&1; then
  fail "未找到必需命令：git"
fi
if ! command -v awk >/dev/null 2>&1; then
  fail "未找到必需命令：awk"
fi

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  fail "当前目录不属于 Git 仓库。"
fi
cd "${repository_root}"

if ! git rev-parse --verify --quiet HEAD >/dev/null; then
  fail "当前仓库没有可用于生成发布说明的提交。"
fi

previous_tag="$(
  git describe \
    --tags \
    --abbrev=0 \
    --match 'v[0-9]*' \
    HEAD 2>/dev/null || true
)"

if [[ -n "${previous_tag}" ]]; then
  commit_range="${previous_tag}..HEAD"
else
  commit_range="HEAD"
fi

commit_count="$(git rev-list --count --no-merges "${commit_range}")"
if [[ "${commit_count}" -eq 0 ]]; then
  if [[ -n "${previous_tag}" ]]; then
    fail "标签 ${previous_tag} 之后没有可发布的新提交。"
  fi
  fail "当前仓库没有可发布的新提交。"
fi

if [[ "${output_path}" != /* ]]; then
  output_path="${repository_root}/${output_path}"
fi
mkdir -p "$(dirname "${output_path}")"

temporary_output="${output_path}.tmp.$$"
cleanup() {
  rm -f "${temporary_output}"
}
trap cleanup EXIT

git log \
  --no-merges \
  --format='%h%x09%s' \
  "${commit_range}" |
  awk \
    -F '\t' \
    -v version="${version}" \
    -v previous_tag="${previous_tag}" \
    '
BEGIN {
  feature_pattern = "^(feat|功能)(\\([^)]*\\))?!?:[[:space:]]*"
  fix_pattern = "^(fix|修复|安全)(\\([^)]*\\))?!?:[[:space:]]*"
  docs_pattern = "^(docs|文档)(\\([^)]*\\))?!?:[[:space:]]*"
  internal_pattern = \
    "^(refactor|perf|test|build|ci|chore|重构|性能)(\\([^)]*\\))?!?:[[:space:]]*"
}

function append_item(category, item) {
  if (category == "features") {
    features = features item "\n"
    feature_count++
  } else if (category == "fixes") {
    fixes = fixes item "\n"
    fix_count++
  } else if (category == "docs") {
    docs = docs item "\n"
    doc_count++
  } else if (category == "internal") {
    internal = internal item "\n"
    internal_count++
  } else {
    other = other item "\n"
    other_count++
  }
}

function remember_item(category, title, hash, key, item) {
  key = category SUBSEP title
  item = item_index[key]

  if (item == 0) {
    item = ++item_count
    item_index[key] = item
    item_categories[item] = category
    item_titles[item] = title
    item_hashes[item] = "`" hash "`"
    return
  }

  item_hashes[item] = item_hashes[item] ", `" hash "`"
}

function emit_section(title, content, count) {
  if (count == 0) {
    return
  }
  print "### " title
  print ""
  printf "%s", content
  print ""
}

{
  hash = $1
  subject = $2
  for (field = 3; field <= NF; field++) {
    subject = subject FS $field
  }

  if (subject ~ /^(fixup|squash)![[:space:]]*/) {
    next
  }

  category = "other"
  title = subject

  if (subject ~ feature_pattern) {
    category = "features"
    sub(feature_pattern, "", title)
  } else if (subject ~ fix_pattern) {
    category = "fixes"
    sub(fix_pattern, "", title)
  } else if (subject ~ docs_pattern) {
    category = "docs"
    sub(docs_pattern, "", title)
  } else if (subject ~ internal_pattern) {
    category = "internal"
    sub(internal_pattern, "", title)
  }

  remember_item(category, title, hash)
}

END {
  if (item_count == 0) {
    print "提交记录只包含不应单独发布的 fixup! / squash! 提交。" > "/dev/stderr"
    exit 1
  }

  for (item = 1; item <= item_count; item++) {
    append_item(item_categories[item], "- " item_titles[item] " (" item_hashes[item] ")")
  }

  print "## 本次更新"
  print ""
  emit_section("新增功能", features, feature_count)
  emit_section("问题修复与安全", fixes, fix_count)
  emit_section("文档更新", docs, doc_count)
  emit_section("内部改进", internal, internal_count)
  emit_section("其他变化", other, other_count)
  print "---"
  print ""

  if (previous_tag != "") {
    print "以上内容根据 `" previous_tag "..v" version "` 之间的提交记录自动整理。"
  } else {
    print "以上内容根据项目首个提交到 `v" version "` 之间的提交记录自动整理。"
  }
}
' >"${temporary_output}"

mv "${temporary_output}" "${output_path}"
trap - EXIT

echo "中文发布摘要已生成：${output_path}"
