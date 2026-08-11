using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SharedCoreRuntimeProbeTests
{
    [TestMethod]
    public void ProductionRuntimeProbeLoadsSharedCore()
    {
        Assert.AreEqual(SharedCoreRuntimeStatus.Ready, SharedCoreRuntimeProbe.Run());
    }

    [TestMethod]
    public void RuntimeProbeStopsBeforeNativeCallForAbiMismatch()
    {
        var didScaleTraffic = false;

        var status = SharedCoreRuntimeProbe.Run(
            () => 2,
            _ =>
            {
                didScaleTraffic = true;
                return new SharedTrafficScale(
                    1.5,
                    SharedTrafficUnit.Kilobytes,
                    2);
            });

        Assert.AreEqual(SharedCoreRuntimeStatus.AbiMismatch, status);
        Assert.IsFalse(didScaleTraffic);
    }

    [TestMethod]
    public void RuntimeProbeContainsNativeLoadFailure()
    {
        var status = SharedCoreRuntimeProbe.Run(
            () => throw new DllNotFoundException(),
            _ => throw new AssertFailedException("不应调用缩放函数。"));

        Assert.AreEqual(SharedCoreRuntimeStatus.NativeCallFailed, status);
    }

    [TestMethod]
    public void RuntimeProbeRejectsUnexpectedResult()
    {
        var status = SharedCoreRuntimeProbe.Run(
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                SharedTrafficUnit.Megabytes,
                2));

        Assert.AreEqual(SharedCoreRuntimeStatus.UnexpectedResult, status);
    }
}
