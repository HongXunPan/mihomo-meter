"""校验 Windows 应用、通知区域与悬浮窗图标契约。"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "platform/windows/MihomoMeter.Windows.App"
ASSET_ROOT = APP_ROOT / "Assets"

EXPECTED_ICON_SIZES = {
    "MihomoMeter.ico": (16, 20, 24, 32, 40, 48, 64, 128, 256),
    "MihomoMeter.StatusOnLight.ico": (
        16,
        20,
        24,
        28,
        32,
        36,
        40,
        48,
        56,
        64,
        96,
        128,
    ),
    "MihomoMeter.StatusOnDark.ico": (
        16,
        20,
        24,
        28,
        32,
        36,
        40,
        48,
        56,
        64,
        96,
        128,
    ),
}


def validate_windows_icon_contract(errors: list[str]) -> None:
    for file_name, expected_sizes in EXPECTED_ICON_SIZES.items():
        path = ASSET_ROOT / file_name
        try:
            frames = read_ico_frames(path)
        except (OSError, ValueError, struct.error, zlib.error):
            errors.append(f"Windows 图标资源无法解析：{file_name}")
            continue

        sizes = tuple(frame[0] for frame in frames)
        if sizes != expected_sizes:
            errors.append(
                f"Windows 图标 {file_name} 尺寸必须严格等于 {expected_sizes}"
            )
        for size, payload in frames:
            if not png_has_transparency(payload):
                errors.append(f"Windows 图标 {file_name} 的 {size}px 图层必须包含透明像素")

    validate_icon_references(errors)


def read_ico_frames(path: Path) -> list[tuple[int, bytes]]:
    data = path.read_bytes()
    reserved, icon_type, count = struct.unpack_from("<HHH", data)
    if (reserved, icon_type) != (0, 1) or count == 0:
        raise ValueError("ICO 文件头无效")

    frames: list[tuple[int, bytes]] = []
    for index in range(count):
        offset = 6 + index * 16
        width, height, colors, entry_reserved, planes, bits, length, payload_offset = (
            struct.unpack_from("<BBBBHHII", data, offset)
        )
        width = width or 256
        height = height or 256
        if (
            width != height
            or colors != 0
            or entry_reserved != 0
            or planes != 1
            or bits != 32
        ):
            raise ValueError("ICO 图层目录无效")
        payload = data[payload_offset : payload_offset + length]
        if len(payload) != length or not payload.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("ICO 图层必须使用 RGBA PNG")
        frames.append((width, payload))
    return frames


def png_has_transparency(data: bytes) -> bool:
    position = 8
    compressed: list[bytes] = []
    width = height = 0
    while position < len(data):
        length = struct.unpack_from(">I", data, position)[0]
        chunk_type = data[position + 4 : position + 8]
        payload = data[position + 8 : position + 8 + length]
        position += 12 + length
        if chunk_type == b"IHDR":
            width, height, depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if (depth, color_type, interlace) != (8, 6, 0):
                return False
        elif chunk_type == b"IDAT":
            compressed.append(payload)
        elif chunk_type == b"IEND":
            break

    raw = zlib.decompress(b"".join(compressed))
    bytes_per_pixel = 4
    stride = width * bytes_per_pixel
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        row = bytearray(raw[offset : offset + stride])
        offset += stride
        unfilter_scanline(row, previous, filter_type, bytes_per_pixel)
        if any(row[index] < 255 for index in range(3, stride, bytes_per_pixel)):
            return True
        previous = row
    return False


def unfilter_scanline(
    row: bytearray,
    previous: bytearray,
    filter_type: int,
    bytes_per_pixel: int,
) -> None:
    for index in range(len(row)):
        left = row[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
        above = previous[index]
        upper_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
        if filter_type == 1:
            row[index] = (row[index] + left) & 0xFF
        elif filter_type == 2:
            row[index] = (row[index] + above) & 0xFF
        elif filter_type == 3:
            row[index] = (row[index] + (left + above) // 2) & 0xFF
        elif filter_type == 4:
            row[index] = (row[index] + paeth(left, above, upper_left)) & 0xFF
        elif filter_type != 0:
            raise ValueError(f"不支持的 PNG 过滤器：{filter_type}")


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    return above if above_distance <= upper_left_distance else upper_left


def validate_icon_references(errors: list[str]) -> None:
    required_markers = {
        APP_ROOT / "MihomoMeter.Windows.App.csproj": (
            "<ApplicationIcon>Assets\\MihomoMeter.ico</ApplicationIcon>",
            '<Content Include="Assets\\MihomoMeter.StatusOnLight.ico">',
            '<Content Include="Assets\\MihomoMeter.StatusOnDark.ico">',
        ),
        APP_ROOT / "Lifecycle/WindowsIconAssets.cs": (
            "appWindow.SetIcon",
            "LoadIconWithScaleDown",
            "MihomoMeter.StatusOnLight.ico",
            "MihomoMeter.StatusOnDark.ico",
        ),
        APP_ROOT / "MainWindow.xaml.cs": ("ApplyApplicationIcon",),
        APP_ROOT / "Lifecycle/SettingsWindowController.cs": (
            "ApplyApplicationIcon",
        ),
        APP_ROOT / "Lifecycle/QuotaTrendWindowController.cs": (
            "ApplyApplicationIcon",
        ),
        APP_ROOT / "Lifecycle/ConnectionAnalyticsTrendWindowController.cs": (
            "ApplyApplicationIcon",
        ),
        APP_ROOT / "Lifecycle/NotificationAreaController.cs": (
            "CreateApplicationIcon",
            "SystemMetricSmallIconWidth",
        ),
        APP_ROOT / "Lifecycle/FloatingWidgetWindow.cs": (
            "LogicalWidth = 108",
            "FloatingWidgetIconSet",
            "WindowMessageDpiChanged",
        ),
        APP_ROOT / "Lifecycle/FloatingWidgetPainter.cs": (
            "DrawIconEx",
            "DrawTextRight",
            "IsDarkColor",
        ),
    }
    for path, markers in required_markers.items():
        try:
            content = path.read_text(encoding="utf-8")
        except OSError:
            errors.append(f"缺少 Windows 图标契约文件：{path.relative_to(ROOT)}")
            continue
        for marker in markers:
            if marker not in content:
                errors.append(
                    f"{path.relative_to(ROOT)} 缺少 Windows 图标契约标记：{marker}"
                )
