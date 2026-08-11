"""定义跨平台共享核心 P1.2b 验收结果的静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACCEPTANCE_RECORD = ROOT / "docs/跨平台共享核心P1.2b验收记录-2026-08-11.md"

REQUIRED_MARKERS = (
    "状态：通过",
    "确认日期：2026-08-11",
    "macOS 26.5.2（25F84，x86_64）",
    "Windows 10 22H2 x64 标准用户",
    "2 次独立启动，包含冷启动；连续连接至少 30 分钟",
    "启动探针 `ready`",
    "`byte_count matched`",
    "`rate matched`",
    "`compact_rate matched`",
    "异常事件 | 无 | 无",
    "现行展示保持 | 通过 | 通过",
    "只放行 P1.3 主路径评估",
    "生产输出继续由原生算法决定",
)


def validate_shared_core_acceptance(failures: list[str]) -> None:
    if not ACCEPTANCE_RECORD.is_file():
        failures.append("缺少跨平台共享核心 P1.2b 验收记录")
        return

    content = ACCEPTANCE_RECORD.read_text(encoding="utf-8")
    for marker in REQUIRED_MARKERS:
        if marker not in content:
            failures.append(f"P1.2b 验收记录缺少标记：{marker}")
