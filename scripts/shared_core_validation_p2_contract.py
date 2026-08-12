"""定义跨平台共享核心 P2 代理分类的阶段静态契约。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_MARKERS = {
    "docs/跨平台共享核心P2代理分类技术方案.md": (
        "状态：P2-1 ABI、双端适配器与统一向量已实现",
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
        "P2-1",
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
    "SharedCore/src/lib.rs": (
        "pub unsafe extern \"C\" fn mm_classify_proxy_type(",
        "MAXIMUM_PROXY_TYPE_INPUT_LENGTH",
        "PROXY_TYPE_UNRECOGNIZED",
        "proxy_type_classification_validates_abi_pointers",
    ),
    "SharedCore/include/mihomo_meter_shared_core.h": (
        "MM_PROXY_TYPE_MAX_INPUT_LENGTH 64u",
        "mm_proxy_type_classification_t",
        "mm_classify_proxy_type",
    ),
    "SharedCore/TestVectors/proxy_type_classification.json": (
        '"Hysteria2"',
        '"Socks5"',
        '"unsupported_input"',
        '"input_too_long"',
    ),
    "SharedCore/Adapters/Swift/MihomoMeterSharedCoreAdapter.swift": (
        "enum SharedProxyTypeClassification",
        "static func classifyProxyType(",
        "unsupportedProxyTypeInput",
        "proxyTypeInputTooLong",
    ),
    "SharedCore/Adapters/Swift/Probe/main.swift": (
        "ProxyTypeClassificationFixture",
        "MihomoMeterSharedCoreAdapter.classifyProxyType",
        "ProxyClassifier(",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Application/MihomoMeterSharedCore.cs": (
        "public enum SharedProxyTypeClassification",
        "public static SharedProxyTypeClassification ClassifyProxyType(",
        'EntryPoint = "mm_classify_proxy_type"',
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeterSharedCoreTests.cs": (
        "ProxyTypeClassificationMatchesNativeClassifierForCanonicalVectors",
        "MihomoMeterSharedCore.ClassifyProxyType(",
        "ClassifyNatively(",
    ),
    "platform/windows/MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj": (
        "proxy_type_classification.json",
        "shared-core-proxy-type-classification.json",
    ),
    "scripts/test_shared_core_macos.sh": (
        "proxy_type_classification.json",
        '"${proxy_fixture_path}"',
    ),
}

FORBIDDEN_P2_1_PRODUCTION_MARKERS = {
    "Sources/Domain/ProxyClassifier.swift": (
        "MihomoMeterSharedCoreAdapter",
        "SharedProxyTypeClassification",
    ),
    "platform/windows/MihomoMeter.Windows.Core/Domain/ProxyClassifier.cs": (
        "MihomoMeterSharedCore",
        "SharedProxyTypeClassification",
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

    for relative_path, markers in FORBIDDEN_P2_1_PRODUCTION_MARKERS.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker in content:
                failures.append(
                    f"{relative_path} 在 P2-1 不得提前接入共享分类：{marker}"
                )
