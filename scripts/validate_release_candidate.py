#!/usr/bin/env python3
"""校验待提升的 Mihomo Meter draft Release 资产与正文。"""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

from release_platform_descriptors import (
    DescriptorError,
    PLATFORM_ASSETS,
    load_descriptor,
    render_downloads,
    validate_release_snapshot,
    verify_descriptor_assets,
)


CHECKSUM_PATTERN = re.compile(r"^([0-9a-f]{64})  ([^/\\]+)$")
METADATA_FILES = {
    "SHA256SUMS",
    "appcast.xml",
    "macos-release.json",
    "windows-release.json",
}


def expected_binary_names(platform: str, version: str) -> set[str]:
    platforms = {
        "all": ("macos", "windows"),
        "macos": ("macos",),
        "windows": ("windows",),
    }
    if platform not in platforms:
        raise DescriptorError(f"不支持的候选平台：{platform}")
    return {
        spec.file_name(version)
        for current in platforms[platform]
        for spec in PLATFORM_ASSETS[current]
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_checksums(asset_directory: Path, expected_binaries: set[str]) -> None:
    checksum_path = asset_directory / "SHA256SUMS"
    try:
        lines = checksum_path.read_text(encoding="utf-8").splitlines()
    except OSError as exception:
        raise DescriptorError("无法读取候选 SHA256SUMS。") from exception

    checksums: dict[str, str] = {}
    for line in lines:
        match = CHECKSUM_PATTERN.fullmatch(line)
        if match is None or match.group(2) in checksums:
            raise DescriptorError("候选 SHA256SUMS 格式或条目重复。")
        checksums[match.group(2)] = match.group(1)
    if set(checksums) != expected_binaries:
        raise DescriptorError("候选 SHA256SUMS 与本次构建资产不一致。")

    for file_name, expected_hash in checksums.items():
        path = asset_directory / file_name
        if not path.is_file() or sha256(path) != expected_hash:
            raise DescriptorError(f"候选资产 SHA-256 不一致：{file_name}")


def validate_candidate(
    version: str,
    platform: str,
    asset_directory: Path,
    body_path: Path,
) -> None:
    expected_binaries = expected_binary_names(platform, version)
    actual_files = {path.name for path in asset_directory.iterdir() if path.is_file()}
    if actual_files != METADATA_FILES | expected_binaries:
        raise DescriptorError("候选 Release 资产列表与发布平台不一致。")

    macos = load_descriptor(asset_directory / "macos-release.json", "macos")
    windows = load_descriptor(asset_directory / "windows-release.json", "windows")
    validate_release_snapshot(version, macos, windows)
    if platform != "windows":
        verify_descriptor_assets(macos, asset_directory)
    if platform != "macos":
        verify_descriptor_assets(windows, asset_directory)
    validate_checksums(asset_directory, expected_binaries)

    expected_body_prefix = render_downloads(version, macos, windows)
    try:
        actual_body = body_path.read_text(encoding="utf-8")
    except OSError as exception:
        raise DescriptorError("无法读取候选 Release 正文。") from exception
    if not actual_body.startswith(expected_body_prefix):
        raise DescriptorError("候选 Release 顶部下载指引与平台描述不一致。")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--platform", choices=("all", "macos", "windows"), required=True)
    parser.add_argument("--asset-dir", type=Path, required=True)
    parser.add_argument("--body", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        validate_candidate(
            arguments.version,
            arguments.platform,
            arguments.asset_dir,
            arguments.body,
        )
    except (DescriptorError, OSError) as exception:
        print(f"错误：{exception}")
        return 1
    print("候选 Release 资产、描述、校验和与下载指引一致。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
