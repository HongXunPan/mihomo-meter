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

    private sealed class TrafficScaleFixture
    {
        [JsonPropertyName("schemaVersion")]
        public int SchemaVersion { get; init; }

        [JsonPropertyName("byteValues")]
        public string[] ByteValues { get; init; } = [];
    }
}
