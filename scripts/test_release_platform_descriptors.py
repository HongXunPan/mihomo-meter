#!/usr/bin/env python3
"""测试平台发布描述的生成、继承校验与下载指引。"""

from __future__ import annotations

import copy
import shutil
import unittest
from pathlib import Path

from inherited_release_descriptor import generate_inherited_descriptor
from release_platform_descriptors import (
    DescriptorError,
    PLATFORM_ASSETS,
    generate_descriptor,
    render_downloads,
    sha256,
    validate_descriptor,
    validate_release_snapshot,
    verify_descriptor_assets,
    write_descriptor,
)
from validate_release_candidate import validate_candidate


ROOT = Path(__file__).resolve().parents[1]
TEST_ROOT = ROOT / ".codex-tmp" / "release-platform-descriptor-tests"


class ReleasePlatformDescriptorTests(unittest.TestCase):
    def setUp(self) -> None:
        shutil.rmtree(TEST_ROOT, ignore_errors=True)
        TEST_ROOT.mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(TEST_ROOT, ignore_errors=True)

    def create_assets(self, platform: str, version: str) -> Path:
        directory = TEST_ROOT / platform
        directory.mkdir()
        for index, spec in enumerate(PLATFORM_ASSETS[platform], start=1):
            (directory / spec.file_name(version)).write_bytes(
                f"{platform}-{version}-{index}".encode()
            )
        return directory

    def create_release_metadata(self, platform: str, version: str) -> tuple[Path, Path]:
        metadata = TEST_ROOT / f"{platform}-metadata"
        metadata.mkdir()
        checksum_lines = []
        asset_names = ["appcast.xml", "SHA256SUMS"]
        for index, spec in enumerate(PLATFORM_ASSETS[platform], start=1):
            file_name = spec.file_name(version)
            checksum_lines.append(f"{str(index) * 64}  ./{file_name}")
            asset_names.append(file_name)
        checksums = metadata / "SHA256SUMS"
        checksums.write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")
        asset_list = metadata / "assets.txt"
        asset_list.write_text("\n".join(asset_names) + "\n", encoding="utf-8")
        return checksums, asset_list

    def test_generates_strict_platform_descriptors(self) -> None:
        macos = generate_descriptor("macos", "1.2.3", self.create_assets("macos", "1.2.3"))
        windows = generate_descriptor(
            "windows",
            "1.2.4",
            self.create_assets("windows", "1.2.4"),
        )

        validate_descriptor(macos, "macos")
        validate_descriptor(windows, "windows")
        self.assertEqual("v1.2.3", macos["sourceTag"])
        self.assertEqual("Windows x64 安装版", windows["assets"][0]["label"])
        self.assertEqual(64, len(windows["assets"][0]["sha256"]))

    def test_render_shows_plain_language_links_and_inherited_version(self) -> None:
        macos = generate_descriptor("macos", "1.2.5", self.create_assets("macos", "1.2.5"))
        windows = generate_descriptor(
            "windows",
            "1.2.4",
            self.create_assets("windows", "1.2.4"),
        )

        content = render_downloads("1.2.5", macos, windows)

        self.assertIn("Apple Silicon Mac（M 系列芯片）", content)
        self.assertIn("Windows 1.2.4（沿用 v1.2.4）", content)
        self.assertIn("不需要展开 Assets", content)
        self.assertIn("本次新构建资产 SHA-256 校验文件", content)

    def test_rejects_cross_repository_and_tag_mismatch(self) -> None:
        descriptor = generate_descriptor(
            "windows",
            "1.2.4",
            self.create_assets("windows", "1.2.4"),
        )
        foreign = copy.deepcopy(descriptor)
        foreign["releasePageUrl"] = "https://example.com/releases/tag/v1.2.4"
        mismatched = copy.deepcopy(descriptor)
        mismatched["sourceTag"] = "v1.2.5"

        with self.assertRaises(DescriptorError):
            validate_descriptor(foreign, "windows")
        with self.assertRaises(DescriptorError):
            validate_descriptor(mismatched, "windows")

    def test_rejects_invalid_hash_and_extra_fields(self) -> None:
        descriptor = generate_descriptor(
            "windows",
            "1.2.4",
            self.create_assets("windows", "1.2.4"),
        )
        invalid_hash = copy.deepcopy(descriptor)
        invalid_hash["assets"][0]["sha256"] = "ABC"
        extra_field = copy.deepcopy(descriptor)
        extra_field["downloadToken"] = "forbidden"

        with self.assertRaises(DescriptorError):
            validate_descriptor(invalid_hash, "windows")
        with self.assertRaises(DescriptorError):
            validate_descriptor(extra_field, "windows")

    def test_release_snapshot_requiresCurrentPlatformAndMonotonicVersion(self) -> None:
        macos = generate_descriptor("macos", "1.2.3", self.create_assets("macos", "1.2.3"))
        windows = generate_descriptor(
            "windows",
            "1.2.4",
            self.create_assets("windows", "1.2.4"),
        )

        validate_release_snapshot("1.2.4", macos, windows)
        with self.assertRaises(DescriptorError):
            validate_release_snapshot("1.2.3", macos, windows)
        with self.assertRaises(DescriptorError):
            validate_release_snapshot("1.2.5", macos, windows)

    def test_verifiesLocalAssetsAgainstDescriptorHashes(self) -> None:
        directory = self.create_assets("windows", "1.2.4")
        descriptor = generate_descriptor("windows", "1.2.4", directory)

        verify_descriptor_assets(descriptor, directory)
        (directory / descriptor["assets"][0]["fileName"]).write_bytes(b"changed")
        with self.assertRaises(DescriptorError):
            verify_descriptor_assets(descriptor, directory)

    def test_generatesInheritedDescriptorFromLegacyReleaseMetadata(self) -> None:
        checksums, asset_list = self.create_release_metadata("macos", "0.5.1")

        descriptor = generate_inherited_descriptor(
            "macos",
            "0.5.1",
            checksums,
            asset_list,
        )

        self.assertEqual("v0.5.1", descriptor["sourceTag"])
        self.assertEqual("1" * 64, descriptor["assets"][0]["sha256"])
        self.assertIn("/releases/download/v0.5.1/", descriptor["assets"][0]["downloadUrl"])

    def test_rejectsIncompleteOrUnsafeLegacyReleaseMetadata(self) -> None:
        checksums, asset_list = self.create_release_metadata("macos", "0.5.1")
        valid_checksums = checksums.read_text(encoding="utf-8")
        valid_asset_list = asset_list.read_text(encoding="utf-8")
        asset_list.write_text("appcast.xml\nSHA256SUMS\n", encoding="utf-8")
        with self.assertRaises(DescriptorError):
            generate_inherited_descriptor("macos", "0.5.1", checksums, asset_list)

        asset_list.write_text(valid_asset_list, encoding="utf-8")
        checksums.write_text(
            f"{'a' * 64}  ../Mihomo-Meter-0.5.1-macos-arm64.dmg\n",
            encoding="utf-8",
        )
        with self.assertRaises(DescriptorError):
            generate_inherited_descriptor("macos", "0.5.1", checksums, asset_list)

        first_line = valid_checksums.splitlines()[0]
        checksums.write_text(f"{first_line}\n{first_line}\n", encoding="utf-8")
        with self.assertRaises(DescriptorError):
            generate_inherited_descriptor("macos", "0.5.1", checksums, asset_list)

    def test_validatesInheritedCandidateWithoutCopiedOldBinaries(self) -> None:
        candidate = TEST_ROOT / "candidate"
        candidate.mkdir()
        windows_assets = self.create_assets("windows", "1.2.4")
        for path in windows_assets.iterdir():
            shutil.copy2(path, candidate / path.name)
        checksums, asset_list = self.create_release_metadata("macos", "1.2.3")
        macos = generate_inherited_descriptor("macos", "1.2.3", checksums, asset_list)
        windows = generate_descriptor("windows", "1.2.4", windows_assets)
        write_descriptor(candidate / "macos-release.json", macos)
        write_descriptor(candidate / "windows-release.json", windows)
        (candidate / "appcast.xml").write_text("<rss />\n", encoding="utf-8")
        checksum_lines = [
            f"{sha256(candidate / asset['fileName'])}  {asset['fileName']}"
            for asset in windows["assets"]
        ]
        (candidate / "SHA256SUMS").write_text(
            "\n".join(checksum_lines) + "\n",
            encoding="utf-8",
        )
        body = TEST_ROOT / "body.md"
        body.write_text(
            render_downloads("1.2.4", macos, windows) + "发布说明\n",
            encoding="utf-8",
        )

        validate_candidate("1.2.4", "windows", candidate, body)
        body.write_text("错误下载指引\n", encoding="utf-8")
        with self.assertRaises(DescriptorError):
            validate_candidate("1.2.4", "windows", candidate, body)
        body.write_text(
            render_downloads("1.2.4", macos, windows) + "发布说明\n",
            encoding="utf-8",
        )
        (candidate / "copied-old.dmg").write_bytes(b"forbidden")
        with self.assertRaises(DescriptorError):
            validate_candidate("1.2.4", "windows", candidate, body)


if __name__ == "__main__":
    unittest.main()
