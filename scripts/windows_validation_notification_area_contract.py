"""校验 Windows 通知区域菜单的命令 ID 契约。"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMMAND_IDS_FILE = (
    ROOT
    / "platform/windows/MihomoMeter.Windows.App/Lifecycle"
    / "NotificationAreaMenu.CommandIds.cs"
)

EXPECTED_COMMAND_IDS = {
    "OpenCommand": 1001,
    "ToggleFloatingWidgetCommand": 1002,
    "ExitCommand": 1003,
    "StartStatisticsCommand": 2001,
    "OverflowStatisticsCommand": 2002,
    "ViewStatisticsCommandBase": 2100,
    "StopStatisticsCommandBase": 2200,
    "OpenQuotaCommand": 3001,
    "RefreshQuotaCommand": 3002,
    "OpenProxyConnectionsCommand": 4001,
    "OpenDirectConnectionsCommand": 4002,
}


def validate_notification_area_command_ids(errors: list[str]) -> None:
    content = COMMAND_IDS_FILE.read_text(encoding="utf-8")
    assignments = {
        name: int(value)
        for name, value in re.findall(
            r"private const uint (\w+) = (\d+);",
            content,
        )
    }

    if assignments != EXPECTED_COMMAND_IDS:
        errors.append("通知区域菜单命令 ID 必须保持已分配的独立编号段")
        return

    if len(assignments.values()) != len(set(assignments.values())):
        errors.append("通知区域菜单命令 ID 不得重复")

    lifecycle_root = COMMAND_IDS_FILE.parent
    menu_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(lifecycle_root.glob("NotificationAreaMenu*.cs"))
    )
    if "commands.Add(" in menu_sources:
        errors.append("通知区域菜单命令必须通过 RegisterCommand 统一注册")
