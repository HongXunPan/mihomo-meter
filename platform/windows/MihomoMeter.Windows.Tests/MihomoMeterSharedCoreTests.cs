using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

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
    public void TrafficScalingMatchesProductionFormatterForCanonicalVectors()
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

            var productionText = TrafficDisplayUnits.ByteCount(bytes);
            var sharedText = FormatByteCount(MihomoMeterSharedCore.ScaleTraffic(bytes));
            Assert.AreEqual(
                productionText,
                sharedText,
                $"Windows 累计流量格式化差分不一致：{rawValue}。");
        }
    }

    private static string FormatByteCount(SharedTrafficScale scale)
    {
        var format = scale.DecimalPlaces switch
        {
            0 => "0",
            1 => "0.0",
            2 => "0.00",
            _ => throw new InvalidOperationException(
                $"共享核心返回了不支持的小数位数：{scale.DecimalPlaces}。"),
        };
        var unit = scale.Unit switch
        {
            SharedTrafficUnit.Bytes => "B",
            SharedTrafficUnit.Kilobytes => "KB",
            SharedTrafficUnit.Megabytes => "MB",
            SharedTrafficUnit.Gigabytes => "GB",
            SharedTrafficUnit.Terabytes => "TB",
            _ => throw new InvalidOperationException($"共享核心返回未知流量单位：{scale.Unit}。"),
        };
        return $"{scale.Value.ToString(format, CultureInfo.InvariantCulture)} {unit}";
    }

    private sealed class TrafficScaleFixture
    {
        [JsonPropertyName("schemaVersion")]
        public int SchemaVersion { get; init; }

        [JsonPropertyName("byteValues")]
        public string[] ByteValues { get; init; } = [];
    }
}
