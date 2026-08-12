"""定义跨平台共享核心 P1.4 懒原生回退的阶段静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P1.4懒原生回退技术方案.md": (
        "状态：P1.4-0 方案与门禁已锁定，生产调用点尚未改变",
        "共享优先、原生懒回退",
        "成功路径不得求值原生闭包",
        "status=succeeded",
        "`mismatch` 只保留为差分测试失败",
        "至少 10,000 个 `UInt64` 样本",
        "P1.4-1",
        "P1.4-2",
        "P1.4-3",
        "P1.4-4",
        "P1.4-5",
        "不允许顺带切换生产调用点",
        "恢复为 P1.3 逐次对照入口",
        "P1.3 对照路由",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "P1.4-0 懒原生回退方案已锁定",
        "跨平台共享核心P1.4懒原生回退技术方案.md",
    ),
    "CONTRIBUTING.md": (
        "P1.4 只按",
        "跨平台共享核心P1.4懒原生回退技术方案.md",
    ),
}

CURRENT_PRODUCTION_MARKERS = {
    "Sources/Presentation/TrafficStatisticsFormatter.swift": (
        "let nativeText = nativeBytes(value)",
        "nativeText: nativeText",
    ),
    "Sources/Presentation/TrafficRateFormatter.swift": (
        "let nativeText = nativeCompactString(from: bytesPerSecond)",
        "let nativeText = nativeString(from: bytesPerSecond)",
        "nativeText: nativeText",
    ),
    "platform/windows/MihomoMeter.Windows.App/Presentation/TrafficDisplayFormatter.cs": (
        "var nativeText = TrafficDisplayUnits.ByteCount(bytes);",
        "var nativeText = TrafficDisplayUnits.Rate(bytesPerSecond);",
        "var nativeText = TrafficDisplayUnits.CompactRate(bytesPerSecond);",
        "SharedCoreTrafficRoute.Resolve(",
    ),
}


def validate_shared_core_p1_4(failures: list[str]) -> None:
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"缺少 P1.4 文件：{relative_path}")
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少 P1.4 标记：{marker}")

    for relative_path, markers in CURRENT_PRODUCTION_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(
                    f"{relative_path} 在 P1.4-0 不得提前移除逐次对照：{marker}"
                )
