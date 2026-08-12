using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SharedCoreTrafficRouterTests
{
    [TestMethod]
    public void RouterReturnsSharedTextOnlyForExactMatch()
    {
        var result = SharedCoreTrafficRouter.Route(
            1_500,
            "1.50 KB",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => MatchingScale());

        Assert.AreEqual("1.50 KB", result.Text);
        Assert.AreEqual(SharedCoreTrafficRouteSource.SharedPrimary, result.Source);
        Assert.AreEqual(SharedCoreTrafficShadowStatus.Matched, result.Status);
    }

    [TestMethod]
    public void RouterFallsBackToNativeTextForMismatchAndSharedFailures()
    {
        var mismatch = SharedCoreTrafficRouter.Route(
            1_500,
            "原生输出",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => MatchingScale());
        var abiMismatch = SharedCoreTrafficRouter.Route(
            1_500,
            "原生输出",
            SharedCoreTrafficFormat.ByteCount,
            () => 2,
            _ => throw new InvalidOperationException("不应调用。"));
        var nativeCallFailed = SharedCoreTrafficRouter.Route(
            1_500,
            "原生输出",
            SharedCoreTrafficFormat.ByteCount,
            () => throw new DllNotFoundException("synthetic"),
            _ => throw new InvalidOperationException("不应调用。"));
        var unexpectedResult = SharedCoreTrafficRouter.Route(
            1_500,
            "原生输出",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                SharedTrafficUnit.Kilobytes,
                3));
        var unknownFailure = SharedCoreTrafficRouter.Route(
            1_500,
            "原生输出",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => throw new SyntheticException());

        AssertFallback(mismatch, SharedCoreTrafficShadowStatus.Mismatch);
        AssertFallback(abiMismatch, SharedCoreTrafficShadowStatus.AbiMismatch);
        AssertFallback(nativeCallFailed, SharedCoreTrafficShadowStatus.NativeCallFailed);
        AssertFallback(unexpectedResult, SharedCoreTrafficShadowStatus.UnexpectedResult);
        AssertFallback(unknownFailure, SharedCoreTrafficShadowStatus.UnknownFailure);
    }

    [TestMethod]
    public void ShadowAlwaysReturnsNativeTextWithInjectedSharedCandidate()
    {
        Assert.AreEqual(
            "原生输出",
            SharedCoreTrafficShadow.Observe(
                1_500,
                "原生输出",
                SharedCoreTrafficFormat.ByteCount,
                () => 1,
                _ => MatchingScale()));
    }

    [TestMethod]
    public void RouteDeduplicatesObservationsAndIgnoresReporterFailure()
    {
        var observations = new List<SharedCoreTrafficRouteObservation>();
        SharedCoreTrafficRoute.ConfigureReporter(observation =>
        {
            observations.Add(observation);
            throw new InvalidOperationException("synthetic");
        });
        try
        {
            var firstText = ResolveMatchingRoute();
            var secondText = ResolveMatchingRoute();

            Assert.AreEqual("1.50 KB", firstText);
            Assert.AreEqual("1.50 KB", secondText);
            CollectionAssert.AreEqual(
                new[]
                {
                    new SharedCoreTrafficRouteObservation(
                        SharedCoreTrafficFormat.ByteCount,
                        SharedCoreTrafficRouteSource.SharedPrimary,
                        SharedCoreTrafficRouteStatus.Matched),
                },
                observations);
        }
        finally
        {
            SharedCoreTrafficRoute.ConfigureReporter(null);
        }
    }

    private static SharedTrafficScale MatchingScale()
    {
        return new SharedTrafficScale(
            1.5,
            SharedTrafficUnit.Kilobytes,
            2);
    }

    private static string ResolveMatchingRoute()
    {
        return SharedCoreTrafficRoute.Resolve(
            1_500,
            "1.50 KB",
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => MatchingScale());
    }

    private static void AssertFallback(
        SharedCoreTrafficRouteResult result,
        SharedCoreTrafficShadowStatus expectedStatus)
    {
        Assert.AreEqual("原生输出", result.Text);
        Assert.AreEqual(SharedCoreTrafficRouteSource.NativeFallback, result.Source);
        Assert.AreEqual(expectedStatus, result.Status);
    }

    private sealed class SyntheticException : Exception
    {
    }
}
