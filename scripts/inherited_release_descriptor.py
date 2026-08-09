#!/usr/bin/env python3
"""从既有稳定 Release 元数据补建并校验未构建平台描述。"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

from release_platform_descriptors import (
    DescriptorError,
    PLATFORM_ASSETS,
    PLATFORM_DESCRIPTOR_FILES,
    descriptor_from_hashes,
    load_descriptor,
    require_version,
    write_descriptor,
)


CHECKSUM_LINE_PATTERN = re.compile(r"^([0-9a-f]{64})  (?:\./)?([^/\\]+)$")


def load_release_checksums(path: Path) -> dict[str, str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exception:
        raise DescriptorError(f"无法读取既有 Release 校验文件：{path}") from exception
    if not lines:
        raise DescriptorError("既有 Release 校验文件不得为空。")

    checksums: dict[str, str] = {}
    for line in lines:
        match = CHECKSUM_LINE_PATTERN.fullmatch(line)
        if match is None:
            raise DescriptorError("既有 Release 校验文件包含非法条目。")
        file_name = match.group(2)
        if file_name in checksums:
            raise DescriptorError("既有 Release 校验文件包含重复资产。")
        checksums[file_name] = match.group(1)
    return checksums


def load_release_asset_names(path: Path) -> set[str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exception:
        raise DescriptorError(f"无法读取既有 Release 资产清单：{path}") from exception
    if not lines:
        raise DescriptorError("既有 Release 资产清单不得为空。")
    if any(
        not name or name in {".", ".."} or "/" in name or "\\" in name
        for name in lines
    ):
        raise DescriptorError("既有 Release 资产清单包含非法文件名。")
    if len(lines) != len(set(lines)):
        raise DescriptorError("既有 Release 资产清单包含重复文件名。")
    return set(lines)


def generate_inherited_descriptor(
    platform: str,
    version: str,
    checksums_path: Path,
    asset_list_path: Path,
) -> dict[str, Any]:
    require_version(version)
    if platform not in PLATFORM_ASSETS:
        raise DescriptorError(f"不支持的平台：{platform}")

    checksums = load_release_checksums(checksums_path)
    release_asset_names = load_release_asset_names(asset_list_path)
    expected_names = {spec.file_name(version) for spec in PLATFORM_ASSETS[platform]}
    if not expected_names.issubset(release_asset_names):
        raise DescriptorError("既有 Release 缺少待继承平台资产。")
    if not expected_names.issubset(checksums):
        raise DescriptorError("既有 Release 校验文件缺少待继承平台资产。")
    return descriptor_from_hashes(
        platform,
        version,
        {name: checksums[name] for name in expected_names},
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate = subparsers.add_parser("generate", help="从既有 Release 元数据补建描述")
    generate.add_argument("--platform", choices=tuple(PLATFORM_ASSETS), required=True)
    generate.add_argument("--version", required=True)
    generate.add_argument("--checksums", type=Path, required=True)
    generate.add_argument("--asset-list", type=Path, required=True)
    generate.add_argument("--output", type=Path, required=True)

    validate = subparsers.add_parser("validate", help="校验既有单平台描述")
    validate.add_argument("--platform", choices=tuple(PLATFORM_ASSETS), required=True)
    validate.add_argument("--descriptor", type=Path, required=True)
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
            descriptor = generate_inherited_descriptor(
                arguments.platform,
                arguments.version,
                arguments.checksums,
                arguments.asset_list,
            )
            write_descriptor(arguments.output, descriptor)
        else:
            load_descriptor(arguments.descriptor, arguments.platform)
    except DescriptorError as exception:
        print(f"错误：{exception}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
