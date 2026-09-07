#!/usr/bin/env python3
"""测试应用下载量历史维护与 SVG 生成。"""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import date
from pathlib import Path

from generate_download_history import (
    DownloadHistoryError,
    empty_history,
    main,
    record_sample,
    render_svg,
    validate_history,
)


ROOT = Path(__file__).resolve().parents[1]
TEMPORARY_ROOT = ROOT / ".codex-tmp"


class DownloadHistoryTests(unittest.TestCase):
    """覆盖历史口径、日期更新和图表输出。"""

    def test_records_first_sample_without_legacy_macos_history(self) -> None:
        history = record_sample(empty_history(), date(2026, 9, 7), 48)

        self.assertEqual(history["assetScope"], ["macos-dmg", "windows-setup", "windows-portable"])
        self.assertEqual(history["points"], [{"date": "2026-09-07", "count": 48}])

    def test_replaces_same_day_and_appends_later_day(self) -> None:
        history = record_sample(empty_history(), date(2026, 9, 7), 48)
        history = record_sample(history, date(2026, 9, 7), 51)
        history = record_sample(history, date(2026, 9, 8), 53)

        self.assertEqual(
            history["points"],
            [
                {"date": "2026-09-07", "count": 51},
                {"date": "2026-09-08", "count": 53},
            ],
        )

    def test_rejects_earlier_sample(self) -> None:
        history = record_sample(empty_history(), date(2026, 9, 8), 53)

        with self.assertRaisesRegex(DownloadHistoryError, "不能早于"):
            record_sample(history, date(2026, 9, 7), 48)

    def test_rejects_legacy_asset_scope(self) -> None:
        history = empty_history()
        history["assetScope"] = ["macos-dmg"]

        with self.assertRaisesRegex(DownloadHistoryError, "资产范围"):
            validate_history(history)

    def test_renders_accessible_light_and_dark_svg(self) -> None:
        history = record_sample(empty_history(), date(2026, 9, 7), 48)
        history = record_sample(history, date(2026, 9, 8), 53)

        light_svg = render_svg(history, "light")
        dark_svg = render_svg(history, "dark")

        self.assertIn("Mihomo Meter 累计应用下载量走势", light_svg)
        self.assertIn("最新累计下载量为 53", light_svg)
        self.assertIn("#ffffff", light_svg)
        self.assertIn("#0d1117", dark_svg)
        self.assertIn("2026-09-08", dark_svg)

    def test_cli_writes_new_history_and_both_themes(self) -> None:
        TEMPORARY_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix="download-history-test-",
            dir=TEMPORARY_ROOT,
        ) as temporary_directory:
            directory = Path(temporary_directory)
            badge_path = directory / "download-count.json"
            history_path = directory / "download-history.json"
            light_svg_path = directory / "download-history-light.svg"
            dark_svg_path = directory / "download-history-dark.svg"
            badge_path.write_text(
                '{"schemaVersion":1,"label":"应用下载量","message":"48","color":"blue"}\n',
                encoding="utf-8",
            )

            exit_code = main(
                [
                    "--badge",
                    str(badge_path),
                    "--history",
                    str(history_path),
                    "--date",
                    "2026-09-07",
                    "--history-output",
                    str(history_path),
                    "--light-svg-output",
                    str(light_svg_path),
                    "--dark-svg-output",
                    str(dark_svg_path),
                ]
            )

            self.assertEqual(exit_code, 0)
            history = json.loads(history_path.read_text(encoding="utf-8"))
            self.assertEqual(history["points"], [{"date": "2026-09-07", "count": 48}])
            self.assertTrue(light_svg_path.read_text(encoding="utf-8").startswith("<svg"))
            self.assertTrue(dark_svg_path.read_text(encoding="utf-8").startswith("<svg"))


if __name__ == "__main__":
    unittest.main()
