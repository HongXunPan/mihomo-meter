"""定义跨平台共享核心 P1.3 受保护主路径的静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P1.3受保护主路径技术方案.md": (
        "状态：P1.3-0 设计已锁定，尚未启用共享主路径",
        "受保护主路径仅在共享文本与原生文本完全一致时返回共享文本",
        "ABI 不匹配、动态库调用失败、未知单位、不支持的小数位、文本不一致或其他未知错误",
        "不增加用户开关、持久化模式或可远程修改的配置",
        "shared_core.traffic_route",
        "result=shared_primary",
        "native_fallback",
        "P1.3-1",
        "P1.3-2",
        "P1.3-3",
        "P1.3-4",
        "P1.3-5",
        "不删除原生格式化实现",
        "每个平台至少连续连接 30 分钟",
        "只回滚该格式的调用点",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "状态：P1.3-0 受保护主路径设计已锁定",
        "跨平台共享核心P1.3受保护主路径技术方案.md",
    ),
    "docs/架构概览.md": (
        "P1.3 已锁定",
        "跨平台共享核心P1.3受保护主路径技术方案.md",
    ),
}


def validate_shared_core_p1_3(failures: list[str]) -> None:
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"缺少 P1.3 文件：{relative_path}")
            continue

        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少 P1.3 标记：{marker}")
