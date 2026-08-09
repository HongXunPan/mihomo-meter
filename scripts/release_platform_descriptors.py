#!/usr/bin/env python3
"""生成、校验并渲染 Mihomo Meter 平台发布描述。"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPOSITORY_URL = "https://github.com/HongXunPan/mihomo-meter"
VERSION_PATTERN = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


@dataclass(frozen=True)
class AssetSpec:
    kind: str
    architecture: str
    label: str
    file_name_template: str

    def file_name(self, version: str) -> str:
        return self.file_name_template.format(version=version)


PLATFORM_ASSETS = {
    "macos": (
        AssetSpec(
            "dmg",
            "arm64",
            "Apple Silicon Mac（M 系列芯片）",
            "Mihomo-Meter-{version}-macos-arm64.dmg",
        ),
        AssetSpec(
            "dmg",
            "x86_64",
            "Intel Mac",
            "Mihomo-Meter-{version}-macos-x86_64.dmg",
        ),
        AssetSpec(
            "dmg",
            "universal",
            "通用 Mac（不确定机型时选择）",
            "Mihomo-Meter-{version}-macos-universal.dmg",
        ),
    ),
    "windows": (
        AssetSpec(
            "installer",
            "x64",
            "Windows x64 安装版",
            "Mihomo-Meter-{version}-windows-x64-setup.exe",
        ),
        AssetSpec(
            "portable",
            "x64",
            "Windows x64 便携版",
            "Mihomo-Meter-{version}-windows-x64-portable.zip",
        ),
    ),
}

PLATFORM_DESCRIPTOR_FILES = {
    "macos": "macos-release.json",
    "windows": "windows-release.json",
}


class DescriptorError(ValueError):
    """表示平台发布描述不符合公开契约。"""


def require_version(value: str) -> str:
    if not VERSION_PATTERN.fullmatch(value):
        raise DescriptorError("版本号必须使用无前导零的 X.Y.Z 格式。")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def descriptor_from_hashes(
    platform: str,
    version: str,
    asset_hashes: dict[str, str],
) -> dict[str, Any]:
    require_version(version)
    if platform not in PLATFORM_ASSETS:
        raise DescriptorError(f"不支持的平台：{platform}")

    tag = f"v{version}"
    assets = []
    for spec in PLATFORM_ASSETS[platform]:
        file_name = spec.file_name(version)
        asset_hash = asset_hashes.get(file_name)
        if asset_hash is None:
            raise DescriptorError(f"缺少平台资产 SHA-256：{file_name}")
        assets.append(
            {
                "kind": spec.kind,
                "architecture": spec.architecture,
                "label": spec.label,
                "fileName": file_name,
                "downloadUrl": f"{REPOSITORY_URL}/releases/download/{tag}/{file_name}",
                "sha256": asset_hash,
            }
        )

    descriptor = {
        "schemaVersion": 1,
        "platform": platform,
        "version": version,
        "sourceTag": tag,
        "releasePageUrl": f"{REPOSITORY_URL}/releases/tag/{tag}",
        "assets": assets,
    }
    validate_descriptor(descriptor, platform)
    return descriptor


def generate_descriptor(platform: str, version: str, asset_directory: Path) -> dict[str, Any]:
    if platform not in PLATFORM_ASSETS:
        raise DescriptorError(f"不支持的平台：{platform}")
    asset_hashes = {}
    for spec in PLATFORM_ASSETS[platform]:
        file_name = spec.file_name(version)
        path = asset_directory / file_name
        if not path.is_file():
            raise DescriptorError(f"缺少平台资产：{path}")
        asset_hashes[file_name] = sha256(path)
    return descriptor_from_hashes(platform, version, asset_hashes)


def require_exact_keys(value: dict[str, Any], expected: set[str], context: str) -> None:
    if set(value) != expected:
        raise DescriptorError(f"{context} 字段必须严格等于：{', '.join(sorted(expected))}")


def validate_descriptor(descriptor: dict[str, Any], expected_platform: str) -> None:
    if expected_platform not in PLATFORM_ASSETS:
        raise DescriptorError(f"不支持的平台：{expected_platform}")
    require_exact_keys(
        descriptor,
        {"schemaVersion", "platform", "version", "sourceTag", "releasePageUrl", "assets"},
        "平台描述",
    )
    if descriptor["schemaVersion"] != 1:
        raise DescriptorError("平台描述 schemaVersion 必须为 1。")
    if descriptor["platform"] != expected_platform:
        raise DescriptorError(f"平台描述必须属于 {expected_platform}。")

    version = require_version(str(descriptor["version"]))
    tag = f"v{version}"
    if descriptor["sourceTag"] != tag:
        raise DescriptorError("平台描述来源 Tag 必须与实际版本一致。")
    if descriptor["releasePageUrl"] != f"{REPOSITORY_URL}/releases/tag/{tag}":
        raise DescriptorError("平台描述 Release 页面必须属于固定仓库和来源 Tag。")

    assets = descriptor["assets"]
    specs = PLATFORM_ASSETS[expected_platform]
    if not isinstance(assets, list) or len(assets) != len(specs):
        raise DescriptorError(f"{expected_platform} 平台资产数量不正确。")

    for asset, spec in zip(assets, specs):
        if not isinstance(asset, dict):
            raise DescriptorError("平台资产必须是对象。")
        require_exact_keys(
            asset,
            {"kind", "architecture", "label", "fileName", "downloadUrl", "sha256"},
            "平台资产",
        )
        file_name = spec.file_name(version)
        expected = {
            "kind": spec.kind,
            "architecture": spec.architecture,
            "label": spec.label,
            "fileName": file_name,
            "downloadUrl": f"{REPOSITORY_URL}/releases/download/{tag}/{file_name}",
        }
        for key, expected_value in expected.items():
            if asset[key] != expected_value:
                raise DescriptorError(f"平台资产 {key} 不符合固定契约。")
        if not isinstance(asset["sha256"], str) or not SHA256_PATTERN.fullmatch(
            asset["sha256"]
        ):
            raise DescriptorError("平台资产 SHA-256 必须是 64 位小写十六进制。")


def load_descriptor(path: Path, expected_platform: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exception:
        raise DescriptorError(f"无法读取平台描述：{path}") from exception
    if not isinstance(value, dict):
        raise DescriptorError("平台描述根节点必须是对象。")
    validate_descriptor(value, expected_platform)
    return value


def write_descriptor(path: Path, descriptor: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(descriptor, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def verify_descriptor_assets(descriptor: dict[str, Any], asset_directory: Path) -> None:
    validate_descriptor(descriptor, descriptor.get("platform", ""))
    for asset in descriptor["assets"]:
        path = asset_directory / asset["fileName"]
        if not path.is_file():
            raise DescriptorError(f"缺少描述中声明的资产：{path}")
        if sha256(path) != asset["sha256"]:
            raise DescriptorError(f"平台资产 SHA-256 与描述不一致：{path}")


def platform_heading(descriptor: dict[str, Any], release_version: str) -> str:
    platform_name = "macOS" if descriptor["platform"] == "macos" else "Windows"
    version = descriptor["version"]
    status = "本次构建" if version == release_version else f"沿用 {descriptor['sourceTag']}"
    return f"### {platform_name} {version}（{status}）"


def version_parts(value: str) -> tuple[int, int, int]:
    require_version(value)
    major, minor, patch = value.split(".")
    return int(major), int(minor), int(patch)


def validate_release_snapshot(
    release_version: str,
    macos: dict[str, Any],
    windows: dict[str, Any],
) -> None:
    release_parts = version_parts(release_version)
    platform_versions = (macos["version"], windows["version"])
    if any(version_parts(version) > release_parts for version in platform_versions):
        raise DescriptorError("发布快照版本不得低于任一平台实际版本。")
    if release_version not in platform_versions:
        raise DescriptorError("发布快照必须至少包含一个本次构建平台。")


def render_downloads(
    release_version: str,
    macos: dict[str, Any],
    windows: dict[str, Any],
) -> str:
    require_version(release_version)
    validate_descriptor(macos, "macos")
    validate_descriptor(windows, "windows")
    validate_release_snapshot(release_version, macos, windows)

    lines = [
        "## 直接下载",
        "",
        "请直接按设备和安装方式选择，不需要展开 Assets 或判断文件名中的架构缩写。",
        "",
    ]
    for descriptor in (macos, windows):
        lines.extend((platform_heading(descriptor, release_version), ""))
        for asset in descriptor["assets"]:
            lines.append(f"- [{asset['label']}]({asset['downloadUrl']})")
        lines.extend(("", f"来源：[查看 {descriptor['sourceTag']} 发布说明]({descriptor['releasePageUrl']})", ""))

    lines.extend(
        (
            "### 安装提醒",
            "",
            f"- [本次新构建资产 SHA-256 校验文件]({REPOSITORY_URL}/releases/download/v{release_version}/SHA256SUMS)",
            "- macOS 为自签名且未公证版本，首次打开请按公开安装说明处理 Gatekeeper 提示。",
            "- Windows 安装器未签名，可能显示“未知发布者”或 SmartScreen；请先核对仓库来源和 SHA-256。",
            "",
            "---",
            "",
        )
    )
    return "\n".join(lines)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate = subparsers.add_parser("generate", help="从当前平台资产生成描述")
    generate.add_argument("--platform", choices=tuple(PLATFORM_ASSETS), required=True)
    generate.add_argument("--version", required=True)
    generate.add_argument("--asset-dir", type=Path, required=True)
    generate.add_argument("--output", type=Path, required=True)

    validate = subparsers.add_parser("validate", help="校验两个平台描述")
    validate.add_argument("--release-version", required=True)
    validate.add_argument("--macos", type=Path, required=True)
    validate.add_argument("--windows", type=Path, required=True)

    verify = subparsers.add_parser("verify-assets", help="复核描述与本地平台资产")
    verify.add_argument("--platform", choices=tuple(PLATFORM_ASSETS), required=True)
    verify.add_argument("--descriptor", type=Path, required=True)
    verify.add_argument("--asset-dir", type=Path, required=True)

    render = subparsers.add_parser("render", help="生成 Release 顶部下载指引")
    render.add_argument("--release-version", required=True)
    render.add_argument("--macos", type=Path, required=True)
    render.add_argument("--windows", type=Path, required=True)
    render.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        if arguments.command == "generate":
            expected_name = PLATFORM_DESCRIPTOR_FILES[arguments.platform]
            if arguments.output.name != expected_name:
                raise DescriptorError(
                    f"{arguments.platform} 描述文件必须命名为 {expected_name}。"
                )
            descriptor = generate_descriptor(
                arguments.platform,
                arguments.version,
                arguments.asset_dir,
            )
            write_descriptor(arguments.output, descriptor)
        elif arguments.command == "validate":
            macos = load_descriptor(arguments.macos, "macos")
            windows = load_descriptor(arguments.windows, "windows")
            validate_release_snapshot(arguments.release_version, macos, windows)
        elif arguments.command == "verify-assets":
            descriptor = load_descriptor(arguments.descriptor, arguments.platform)
            verify_descriptor_assets(descriptor, arguments.asset_dir)
        else:
            macos = load_descriptor(arguments.macos, "macos")
            windows = load_descriptor(arguments.windows, "windows")
            content = render_downloads(arguments.release_version, macos, windows)
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(content, encoding="utf-8")
    except DescriptorError as exception:
        print(f"错误：{exception}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
