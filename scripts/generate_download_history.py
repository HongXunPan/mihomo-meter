#!/usr/bin/env python3
"""维护应用下载量历史，并生成适合 README 的明暗主题 SVG。"""

from __future__ import annotations

import argparse
import json
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

from download_history_svg import DownloadChartError, render_download_chart


SCHEMA_VERSION = 1
REPOSITORY = "HongXunPan/mihomo-meter"
METRIC = "application-downloads"
ASSET_SCOPE = ("macos-dmg", "windows-setup", "windows-portable")


class DownloadHistoryError(ValueError):
    """表示下载量历史或输入数据不符合约定。"""


def empty_history() -> dict[str, Any]:
    """创建不包含采样点的新口径历史。"""

    return {
        "schemaVersion": SCHEMA_VERSION,
        "repository": REPOSITORY,
        "metric": METRIC,
        "assetScope": list(ASSET_SCOPE),
        "points": [],
    }


def parse_iso_date(value: object, context: str) -> date:
    """读取严格的 YYYY-MM-DD 日期。"""

    if not isinstance(value, str):
        raise DownloadHistoryError(f"{context}必须是 YYYY-MM-DD 字符串。")
    try:
        parsed = date.fromisoformat(value)
    except ValueError as error:
        raise DownloadHistoryError(f"{context}必须是有效的 YYYY-MM-DD 日期。") from error
    if parsed.isoformat() != value:
        raise DownloadHistoryError(f"{context}必须使用 YYYY-MM-DD 格式。")
    return parsed


def validate_history(history: object) -> dict[str, Any]:
    """校验历史文件结构、统计口径和采样点顺序。"""

    if not isinstance(history, dict):
        raise DownloadHistoryError("下载量历史必须是 JSON 对象。")

    expected_keys = {
        "schemaVersion",
        "repository",
        "metric",
        "assetScope",
        "points",
    }
    if set(history) != expected_keys:
        raise DownloadHistoryError("下载量历史字段不符合 schema v1。")
    if history["schemaVersion"] != SCHEMA_VERSION:
        raise DownloadHistoryError("下载量历史 schemaVersion 必须为 1。")
    if history["repository"] != REPOSITORY:
        raise DownloadHistoryError("下载量历史仓库标识不正确。")
    if history["metric"] != METRIC:
        raise DownloadHistoryError("下载量历史统计指标不正确。")
    if history["assetScope"] != list(ASSET_SCOPE):
        raise DownloadHistoryError("下载量历史资产范围不正确。")

    points = history["points"]
    if not isinstance(points, list):
        raise DownloadHistoryError("下载量历史 points 必须是数组。")

    previous_date: date | None = None
    for index, point in enumerate(points):
        if not isinstance(point, dict) or set(point) != {"date", "count"}:
            raise DownloadHistoryError(f"第 {index + 1} 个采样点字段不正确。")
        point_date = parse_iso_date(point["date"], f"第 {index + 1} 个采样点日期")
        count = point["count"]
        if isinstance(count, bool) or not isinstance(count, int) or count < 0:
            raise DownloadHistoryError(f"第 {index + 1} 个采样点下载量必须是非负整数。")
        if previous_date is not None and point_date <= previous_date:
            raise DownloadHistoryError("下载量历史日期必须严格递增且不得重复。")
        previous_date = point_date

    return history


def load_history(path: Path) -> dict[str, Any]:
    """读取已有历史；文件尚不存在时从新口径空历史开始。"""

    if not path.is_file():
        return empty_history()
    try:
        history = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DownloadHistoryError(f"无法读取下载量历史：{path}") from error
    return validate_history(history)


def read_badge_count(path: Path) -> int:
    """从 Shields Endpoint JSON 读取当前全平台下载量。"""

    try:
        badge = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DownloadHistoryError(f"无法读取下载量徽章数据：{path}") from error
    if not isinstance(badge, dict) or badge.get("schemaVersion") != 1:
        raise DownloadHistoryError("下载量徽章必须是 schema v1 JSON 对象。")
    message = badge.get("message")
    if not isinstance(message, str) or not message.isdigit():
        raise DownloadHistoryError("下载量徽章 message 必须是非负整数字符串。")
    return int(message)


def record_sample(history: dict[str, Any], sample_date: date, count: int) -> dict[str, Any]:
    """追加当天采样；同一天重复执行时覆盖为最新值。"""

    validate_history(history)
    if count < 0:
        raise DownloadHistoryError("当前下载量不能为负数。")

    points = [dict(point) for point in history["points"]]
    sample_date_text = sample_date.isoformat()
    if points:
        latest_date = parse_iso_date(points[-1]["date"], "最后采样日期")
        if sample_date < latest_date:
            raise DownloadHistoryError("新采样日期不能早于已有历史。")
        if sample_date == latest_date:
            points[-1] = {"date": sample_date_text, "count": count}
        else:
            points.append({"date": sample_date_text, "count": count})
    else:
        points.append({"date": sample_date_text, "count": count})

    updated = dict(history)
    updated["points"] = points
    return validate_history(updated)


def render_svg(history: dict[str, Any], theme: str) -> str:
    """校验历史后交给独立 SVG 渲染模块。"""

    validate_history(history)
    try:
        return render_download_chart(history["points"], theme)
    except DownloadChartError as error:
        raise DownloadHistoryError(str(error)) from error


def write_text_atomically(path: Path, content: str) -> None:
    """在目标目录内原子替换生成文件。"""

    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = path.with_name(f".{path.name}.tmp")
    try:
        temporary_path.write_text(content, encoding="utf-8")
        temporary_path.replace(path)
    finally:
        temporary_path.unlink(missing_ok=True)


def parse_arguments(arguments: list[str] | None = None) -> argparse.Namespace:
    """解析命令行参数。"""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--badge", type=Path, required=True, help="当前下载量徽章 JSON")
    parser.add_argument("--history", type=Path, required=True, help="已有历史 JSON；可不存在")
    parser.add_argument("--date", help="采样日期，默认使用当前 UTC 日期")
    parser.add_argument("--history-output", type=Path, required=True, help="历史 JSON 输出")
    parser.add_argument("--light-svg-output", type=Path, required=True, help="浅色 SVG 输出")
    parser.add_argument("--dark-svg-output", type=Path, required=True, help="深色 SVG 输出")
    return parser.parse_args(arguments)


def main(arguments: list[str] | None = None) -> int:
    """执行采样、历史更新和双主题 SVG 生成。"""

    options = parse_arguments(arguments)
    try:
        sample_date = (
            parse_iso_date(options.date, "采样日期")
            if options.date is not None
            else datetime.now(timezone.utc).date()
        )
        count = read_badge_count(options.badge)
        history = record_sample(load_history(options.history), sample_date, count)
        history_json = json.dumps(history, ensure_ascii=False, indent=2) + "\n"
        write_text_atomically(options.history_output, history_json)
        write_text_atomically(options.light_svg_output, render_svg(history, "light"))
        write_text_atomically(options.dark_svg_output, render_svg(history, "dark"))
    except DownloadHistoryError as error:
        raise SystemExit(f"生成下载走势失败：{error}") from error
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
