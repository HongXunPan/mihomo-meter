using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SharedCoreTrafficShadowComparatorTests
{
    [TestMethod]
    [DataRow(SharedCoreTrafficFormat.ByteCount, "1.50 KB")]
    [DataRow(SharedCoreTrafficFormat.Rate, "1.50 KB/s")]
    [DataRow(SharedCoreTrafficFormat.CompactRate, "1.50K/s")]
    public void ComparatorMatchesEveryProductionFormat(
        SharedCoreTrafficFormat format,
        string nativeText)
    {
        var status = SharedCoreTrafficShadowComparator.Compare(
            1_500,
            nativeText,
            format,
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                SharedTrafficUnit.Kilobytes,
                2));

        Assert.AreEqual(SharedCoreTrafficShadowStatus.Matched, status);
    }

    [TestMethod]
    public void ComparatorStopsBeforeScalingForAbiMismatch()
    {
        var didScaleTraffic = false;

        var status = SharedCoreTrafficShadowComparator.Compare(
            1_500,
            "1.50 KB",
            SharedCoreTrafficFormat.ByteCount,
            () => 2,
            _ =>
            {
                didScaleTraffic = true;
                return new SharedTrafficScale(
                    1.5,
                    SharedTrafficUnit.Kilobytes,
                    2);
            });

        Assert.AreEqual(SharedCoreTrafficShadowStatus.AbiMismatch, status);
        Assert.IsFalse(didScaleTraffic);
    }

    [TestMethod]
    public void ComparatorMapsNativeCallFailureWithoutThrowing()
    {
        var status = SharedCoreTrafficShadowComparator.Compare(
            1_500,
            "1.50 KB",
            SharedCoreTrafficFormat.ByteCount,
            () => throw new DllNotFoundException("synthetic"),
            _ => throw new InvalidOperationException("不应调用。"));

        Assert.AreEqual(SharedCoreTrafficShadowStatus.NativeCallFailed, status);
    }

    [TestMethod]
    public void ComparatorReportsMismatchWithoutReturningSharedText()
    {
        var status = SharedCoreTrafficShadowComparator.Compare(
            1_500,
            "原生输出",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                SharedTrafficUnit.Kilobytes,
                2));

        Assert.AreEqual(SharedCoreTrafficShadowStatus.Mismatch, status);
    }

    [TestMethod]
    public void ComparatorRejectsUnsupportedDecimalPlaces()
    {
        var status = SharedCoreTrafficShadowComparator.Compare(
            1_500,
            "1.50 KB",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                SharedTrafficUnit.Kilobytes,
                3));

        Assert.AreEqual(SharedCoreTrafficShadowStatus.UnexpectedResult, status);
    }

    [TestMethod]
    public void ObservationGateReportsEachFormatAndStatusOnce()
    {
        var gate = new SharedCoreTrafficShadowObservationGate();
        var byteCountMatched = new SharedCoreTrafficShadowObservation(
            SharedCoreTrafficFormat.ByteCount,
            SharedCoreTrafficShadowStatus.Matched);

        Assert.IsTrue(gate.ShouldReport(byteCountMatched));
        Assert.IsFalse(gate.ShouldReport(byteCountMatched));
        Assert.IsTrue(gate.ShouldReport(new SharedCoreTrafficShadowObservation(
            SharedCoreTrafficFormat.ByteCount,
            SharedCoreTrafficShadowStatus.Mismatch)));
        Assert.IsTrue(gate.ShouldReport(new SharedCoreTrafficShadowObservation(
            SharedCoreTrafficFormat.Rate,
            SharedCoreTrafficShadowStatus.Matched)));

        gate.Reset();
        Assert.IsTrue(gate.ShouldReport(byteCountMatched));
    }

    [TestMethod]
    public void ShadowReportsMatchedObservationOnce()
    {
        var observations = new List<SharedCoreTrafficShadowObservation>();
        SharedCoreTrafficShadow.ConfigureReporter(observations.Add);
        try
        {
            _ = SharedCoreTrafficShadow.Observe(
                1_500,
                "1.50 KB",
                SharedCoreTrafficFormat.ByteCount);
            _ = SharedCoreTrafficShadow.Observe(
                1_500,
                "1.50 KB",
                SharedCoreTrafficFormat.ByteCount);

            CollectionAssert.AreEqual(
                new[]
                {
                    new SharedCoreTrafficShadowObservation(
                        SharedCoreTrafficFormat.ByteCount,
                        SharedCoreTrafficShadowStatus.Matched),
                },
                observations);
        }
        finally
        {
            SharedCoreTrafficShadow.ConfigureReporter(null);
        }
    }

    [TestMethod]
    public void ShadowReturnsNativeTextWhenDiagnosticReporterFails()
    {
        SharedCoreTrafficShadow.ConfigureReporter(_ => throw new InvalidOperationException(
            "synthetic"));
        try
        {
            Assert.AreEqual(
                "原生输出",
                SharedCoreTrafficShadow.Observe(
                    1_500,
                    "原生输出",
                    SharedCoreTrafficFormat.ByteCount));
        }
        finally
        {
            SharedCoreTrafficShadow.ConfigureReporter(null);
        }
    }
}
