using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class MihomoMeterSharedCoreTests
{
    [TestMethod]
    public void AbiVersionMatchesP0Contract()
    {
        Assert.AreEqual(1U, MihomoMeterSharedCore.AbiVersion);
    }

    [TestMethod]
    [DataRow(0UL, 0.0, SharedTrafficUnit.Bytes, 0U)]
    [DataRow(1_500UL, 1.5, SharedTrafficUnit.Kilobytes, 2U)]
    [DataRow(10_000UL, 10.0, SharedTrafficUnit.Kilobytes, 1U)]
    [DataRow(100_000UL, 100.0, SharedTrafficUnit.Kilobytes, 0U)]
    [DataRow(1_000_000_000_000UL, 1.0, SharedTrafficUnit.Terabytes, 2U)]
    public void TrafficScalingUsesDecimalUnitsAndMacPrecision(
        ulong bytes,
        double expectedValue,
        SharedTrafficUnit expectedUnit,
        uint expectedDecimalPlaces)
    {
        var result = MihomoMeterSharedCore.ScaleTraffic(bytes);

        Assert.AreEqual(expectedValue, result.Value, double.Epsilon);
        Assert.AreEqual(expectedUnit, result.Unit);
        Assert.AreEqual(expectedDecimalPlaces, result.DecimalPlaces);
    }

    [TestMethod]
    public void TrafficScalingMatchesProductionFormattersForCanonicalVectors()
    {
        var fixturePath = Path.Combine(
            AppContext.BaseDirectory,
            "Fixtures",
            "shared-core-traffic-scale.json");
        var fixture = JsonSerializer.Deserialize<TrafficScaleFixture>(
            File.ReadAllText(fixturePath))
            ?? throw new InvalidOperationException("无法读取统一流量缩放向量。");

        Assert.AreEqual(1, fixture.SchemaVersion);
        Assert.IsTrue(fixture.ByteValues.Length > 0);

        foreach (var rawValue in fixture.ByteValues)
        {
            Assert.IsTrue(
                ulong.TryParse(
                    rawValue,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out var bytes),
                $"统一流量缩放向量包含无效字节值：{rawValue}。");

            var sharedScale = MihomoMeterSharedCore.ScaleTraffic(bytes);
            Assert.AreEqual(
                TrafficDisplayUnits.ByteCount(bytes),
                SharedCoreTrafficDisplayFormatter.Format(
                    sharedScale,
                    SharedCoreTrafficFormat.ByteCount),
                $"Windows 累计流量格式化差分不一致：{rawValue}。");
            Assert.AreEqual(
                TrafficDisplayUnits.Rate(bytes),
                SharedCoreTrafficDisplayFormatter.Format(
                    sharedScale,
                    SharedCoreTrafficFormat.Rate),
                $"Windows 完整速率格式化差分不一致：{rawValue}。");
            Assert.AreEqual(
                TrafficDisplayUnits.CompactRate(bytes),
                SharedCoreTrafficDisplayFormatter.Format(
                    sharedScale,
                    SharedCoreTrafficFormat.CompactRate),
                $"Windows 紧凑速率格式化差分不一致：{rawValue}。");
        }
    }

    [TestMethod]
    public void ProxyTypeClassificationMatchesNativeClassifierForCanonicalVectors()
    {
        var fixturePath = Path.Combine(
            AppContext.BaseDirectory,
            "Fixtures",
            "shared-core-proxy-type-classification.json");
        var fixture = JsonSerializer.Deserialize<ProxyTypeClassificationFixture>(
            File.ReadAllText(fixturePath))
            ?? throw new InvalidOperationException("无法读取统一代理类型分类向量。");

        Assert.AreEqual(1, fixture.SchemaVersion);
        Assert.IsTrue(fixture.Cases.Length > 0);

        foreach (var testCase in fixture.Cases)
        {
            var nativeResult = ClassifyNatively(testCase.RawType);
            switch (testCase.Expected)
            {
                case "proxy":
                    Assert.AreEqual(
                        SharedProxyTypeClassification.Proxy,
                        MihomoMeterSharedCore.ClassifyProxyType(testCase.RawType));
                    Assert.AreEqual(new ProxyClassification(TrafficCategory.Proxy), nativeResult);
                    break;
                case "direct":
                    Assert.AreEqual(
                        SharedProxyTypeClassification.Direct,
                        MihomoMeterSharedCore.ClassifyProxyType(testCase.RawType));
                    Assert.AreEqual(new ProxyClassification(TrafficCategory.Direct), nativeResult);
                    break;
                case "reject":
                    Assert.AreEqual(
                        SharedProxyTypeClassification.Reject,
                        MihomoMeterSharedCore.ClassifyProxyType(testCase.RawType));
                    Assert.AreEqual(new ProxyClassification(TrafficCategory.Reject), nativeResult);
                    break;
                case "unrecognized":
                    Assert.AreEqual(
                        SharedProxyTypeClassification.Unrecognized,
                        MihomoMeterSharedCore.ClassifyProxyType(testCase.RawType));
                    Assert.AreEqual(
                        new ProxyClassification(
                            TrafficCategory.Unknown,
                            UnknownTrafficReason.AmbiguousProxyType),
                        nativeResult);
                    break;
                case "unsupported_input":
                    Assert.AreEqual(
                        SharedProxyTypeAdapterFailure.UnsupportedProxyTypeInput,
                        Assert.ThrowsExactly<SharedProxyTypeAdapterException>(() =>
                            MihomoMeterSharedCore.ClassifyProxyType(testCase.RawType)).Failure);
                    Assert.AreEqual(
                        UnknownTrafficReason.AmbiguousProxyType,
                        nativeResult.UnknownReason);
                    break;
                case "input_too_long":
                    Assert.AreEqual(
                        SharedProxyTypeAdapterFailure.ProxyTypeInputTooLong,
                        Assert.ThrowsExactly<SharedProxyTypeAdapterException>(() =>
                            MihomoMeterSharedCore.ClassifyProxyType(testCase.RawType)).Failure);
                    Assert.AreEqual(
                        UnknownTrafficReason.AmbiguousProxyType,
                        nativeResult.UnknownReason);
                    break;
                default:
                    Assert.Fail($"统一代理类型分类向量包含未知预期：{testCase.Expected}。");
                    break;
            }
        }
    }

    private static ProxyClassification ClassifyNatively(string rawType)
    {
        var classifier = new ProxyClassifier(new ProxyCatalog(
            new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Synthetic Proxy"] = rawType,
            }));
        return classifier.Classify(["Synthetic Proxy"]);
    }

    private sealed class TrafficScaleFixture
    {
        [JsonPropertyName("schemaVersion")]
        public int SchemaVersion { get; init; }

        [JsonPropertyName("byteValues")]
        public string[] ByteValues { get; init; } = [];
    }

    private sealed class ProxyTypeClassificationFixture
    {
        [JsonPropertyName("schemaVersion")]
        public int SchemaVersion { get; init; }

        [JsonPropertyName("cases")]
        public ProxyTypeClassificationCase[] Cases { get; init; } = [];
    }

    private sealed class ProxyTypeClassificationCase
    {
        [JsonPropertyName("rawType")]
        public string RawType { get; init; } = string.Empty;

        [JsonPropertyName("expected")]
        public string Expected { get; init; } = string.Empty;
    }
}
