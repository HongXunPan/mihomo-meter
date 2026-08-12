"""定义跨平台共享核心 P2 代理分类的阶段静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P2代理分类技术方案.md": (
        "状态：P2-0 方案与静态契约",
        "P2-F0 已先修正双端原生基线",
        "不超过 64 字节的 ASCII 输入",
        "0 | `unrecognized`",
        "不直接映射未知，必须执行原生回退",
        "mm_classify_proxy_type",
        "proxy_type_classification.json",
        "P2-1 不得接入生产",
        "P2-2 不得改变生产结果",
        "P2-4 不得停止逐次原生比较",
        "P2-6 不得删除原生分类",
        "P2-3、P2-5 与 P2-7",
        "DIRECT、REJECT 或未知被并入 Proxy",
    ),
    "docs/跨平台共享核心技术方案.md": (
        "跨平台共享核心P2代理分类技术方案.md",
        "未识别类型必须回退原生分类",
    ),
    "docs/架构概览.md": (
        "P2 代理分类",
        "跨平台共享核心P2代理分类技术方案.md",
    ),
    "CONTRIBUTING.md": (
        "跨平台共享核心P2代理分类技术方案.md",
        "P2-0",
    ),
    "Sources/Domain/ProxyClassifier.swift": (
        ".filter { $0.isLetter || $0.isNumber }",
        '"hysteria2"',
        '"socks5"',
    ),
    "Tests/ProxyClassifierTests.swift": (
        "testClassifiesEverySupportedConcreteProxyType",
        '"Hysteria2"',
        '"Socks5"',
    ),
    "platform/windows/MihomoMeter.Windows.Core/Domain/ProxyClassifier.cs": (
        "char.IsLetter(character) || char.IsNumber(character)",
        '"hysteria2"',
        '"socks5"',
    ),
    "platform/windows/MihomoMeter.Windows.Tests/ProxyClassifierTests.cs": (
        "ClassifiesEverySupportedConcreteProxyType",
        '"Hysteria2"',
        '"Socks5"',
    ),
}

FORBIDDEN_P2_0_MARKERS = {
    "SharedCore/src/lib.rs": ("mm_classify_proxy_type",),
    "SharedCore/include/mihomo_meter_shared_core.h": ("mm_classify_proxy_type",),
    "SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift": (
        "classifyProxyType",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs": (
        "ClassifyProxyType",
    ),
}


def validate_shared_core_p2(failures: list[str]) -> None:
    for relative_path, markers in REQUIRED_MARKERS.items():
        path = ROOT / relative_path
        if not path.is_file():
            failures.append(f"缺少 P2 文件：{relative_path}")
            continue
        content = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in content:
                failures.append(f"{relative_path} 缺少 P2 标记：{marker}")

    for relative_path, markers in FORBIDDEN_P2_0_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker in content:
                failures.append(
                    f"{relative_path} 在 P2-0 不得提前包含生产标记：{marker}"
                )
