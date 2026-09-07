"""把已校验的应用下载量历史渲染为静态 SVG。"""

from __future__ import annotations

import math
from datetime import date
from html import escape
from typing import Any


CHART_WIDTH = 960
CHART_HEIGHT = 400
PLOT_LEFT = 76.0
PLOT_TOP = 104.0
PLOT_WIDTH = 840.0
PLOT_HEIGHT = 222.0
PLOT_BOTTOM = PLOT_TOP + PLOT_HEIGHT


class DownloadChartError(ValueError):
    """表示 SVG 图表输入或主题不受支持。"""


def nice_axis_maximum(maximum: int) -> int:
    """为纵轴选择易读且略高于数据的上界。"""

    target = max(1, math.ceil(maximum * 1.15))
    magnitude = 10 ** math.floor(math.log10(target))
    normalized = target / magnitude
    for step in (1, 2, 5, 10):
        if normalized <= step:
            return step * magnitude
    return 10 * magnitude


def palette_for_theme(theme: str) -> dict[str, str]:
    """返回浅色或深色图表配色。"""

    if theme not in {"light", "dark"}:
        raise DownloadChartError(f"不支持的 SVG 主题：{theme}")
    return (
        {
            "background": "#ffffff",
            "border": "#d0d7de",
            "text": "#1f2328",
            "muted": "#656d76",
            "grid": "#d8dee4",
            "accent": "#0969da",
            "area": "#54aeff",
        }
        if theme == "light"
        else {
            "background": "#0d1117",
            "border": "#30363d",
            "text": "#f0f6fc",
            "muted": "#8b949e",
            "grid": "#30363d",
            "accent": "#58a6ff",
            "area": "#1f6feb",
        }
    )


def chart_x(point_date: date, first_ordinal: int, day_span: int) -> float:
    """把日期投影到横轴位置。"""

    if day_span == 0:
        return PLOT_LEFT + PLOT_WIDTH / 2
    return PLOT_LEFT + (
        (point_date.toordinal() - first_ordinal) / day_span
    ) * PLOT_WIDTH


def chart_coordinates(
    parsed_dates: list[date],
    counts: list[int],
    axis_maximum: int,
) -> tuple[list[tuple[float, float]], int, int]:
    """计算折线坐标以及日期跨度。"""

    first_ordinal = parsed_dates[0].toordinal()
    last_ordinal = parsed_dates[-1].toordinal()
    day_span = last_ordinal - first_ordinal
    coordinates = [
        (
            chart_x(point_date, first_ordinal, day_span),
            PLOT_BOTTOM - (count / axis_maximum) * PLOT_HEIGHT,
        )
        for point_date, count in zip(parsed_dates, counts)
    ]
    return coordinates, first_ordinal, day_span


def chart_paths(coordinates: list[tuple[float, float]]) -> tuple[str, str]:
    """生成折线及面积区域的 SVG 路径。"""

    line_path = " ".join(
        f"{'M' if index == 0 else 'L'} {x:.1f} {y:.1f}"
        for index, (x, y) in enumerate(coordinates)
    )
    area_path = ""
    if len(coordinates) > 1:
        area_path = (
            f"M {coordinates[0][0]:.1f} {PLOT_BOTTOM:.1f} "
            + " ".join(f"L {x:.1f} {y:.1f}" for x, y in coordinates)
            + f" L {coordinates[-1][0]:.1f} {PLOT_BOTTOM:.1f} Z"
        )
    return line_path, area_path


def render_grid(axis_maximum: int) -> str:
    """生成纵轴标签和水平网格。"""

    grid_lines = []
    for index in range(5):
        ratio = index / 4
        y = PLOT_BOTTOM - ratio * PLOT_HEIGHT
        value = round(axis_maximum * ratio)
        grid_lines.append(
            f'<line x1="{PLOT_LEFT:.1f}" y1="{y:.1f}" x2="{PLOT_LEFT + PLOT_WIDTH:.1f}" y2="{y:.1f}" class="grid" />'
        )
        grid_lines.append(
            f'<text x="{PLOT_LEFT - 12:.1f}" y="{y + 4:.1f}" text-anchor="end" class="axis">{value:,}</text>'
        )
    return "".join(grid_lines)


def render_date_labels(
    parsed_dates: list[date],
    first_ordinal: int,
    day_span: int,
) -> str:
    """生成起点、中点和终点日期标签。"""

    if day_span == 0:
        date_ticks = [parsed_dates[0]]
    else:
        middle = date.fromordinal(first_ordinal + day_span // 2)
        date_ticks = list(dict.fromkeys((parsed_dates[0], middle, parsed_dates[-1])))

    date_labels = []
    for tick_date in date_ticks:
        x = chart_x(tick_date, first_ordinal, day_span)
        date_labels.append(
            f'<text x="{x:.1f}" y="{PLOT_BOTTOM + 28:.1f}" text-anchor="middle" class="axis">{escape(tick_date.isoformat())}</text>'
        )
    return "".join(date_labels)


def render_download_chart(points: list[dict[str, Any]], theme: str) -> str:
    """把下载量采样点渲染为无需脚本和外部字体的 SVG。"""

    if not points:
        raise DownloadChartError("至少需要一个采样点才能生成走势图。")
    palette = palette_for_theme(theme)
    parsed_dates = [date.fromisoformat(point["date"]) for point in points]
    counts = [point["count"] for point in points]
    axis_maximum = nice_axis_maximum(max(counts))
    coordinates, first_ordinal, day_span = chart_coordinates(
        parsed_dates,
        counts,
        axis_maximum,
    )
    line_path, area_path = chart_paths(coordinates)
    area_element = (
        f'<path d="{area_path}" fill="url(#area-gradient)" />' if area_path else ""
    )
    endpoint_x, endpoint_y = coordinates[-1]
    latest_count = counts[-1]
    latest_date = parsed_dates[-1].isoformat()

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CHART_WIDTH} {CHART_HEIGHT}" role="img" aria-labelledby="chart-title chart-description">
  <title id="chart-title">Mihomo Meter 累计应用下载量走势</title>
  <desc id="chart-description">统计正式发布中的 macOS DMG、Windows 安装版和便携版，最新累计下载量为 {latest_count}。</desc>
  <defs>
    <linearGradient id="area-gradient" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0%" stop-color="{palette['area']}" stop-opacity="0.34" />
      <stop offset="100%" stop-color="{palette['area']}" stop-opacity="0.03" />
    </linearGradient>
  </defs>
  <style>
    text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .axis {{ fill: {palette['muted']}; font-size: 12px; }}
    .grid {{ stroke: {palette['grid']}; stroke-width: 1; stroke-dasharray: 4 5; }}
  </style>
  <rect x="0.5" y="0.5" width="959" height="399" rx="12" fill="{palette['background']}" stroke="{palette['border']}" />
  <text x="32" y="42" fill="{palette['text']}" font-size="22" font-weight="650">累计应用下载量</text>
  <text x="32" y="68" fill="{palette['muted']}" font-size="13">macOS DMG + Windows 安装版 / 便携版</text>
  <text x="928" y="43" text-anchor="end" fill="{palette['accent']}" font-size="26" font-weight="700">{latest_count:,}</text>
  <text x="928" y="67" text-anchor="end" fill="{palette['muted']}" font-size="12">更新于 {escape(latest_date)}</text>
  {render_grid(axis_maximum)}
  {area_element}
  <path d="{line_path}" fill="none" stroke="{palette['accent']}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
  <circle cx="{endpoint_x:.1f}" cy="{endpoint_y:.1f}" r="5" fill="{palette['background']}" stroke="{palette['accent']}" stroke-width="3" />
  {render_date_labels(parsed_dates, first_ordinal, day_span)}
</svg>
'''
