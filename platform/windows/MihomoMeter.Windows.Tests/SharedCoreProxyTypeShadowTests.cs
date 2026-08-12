using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SharedCoreProxyTypeShadowTests
{
    private static readonly ProxyClassification Proxy = new(TrafficCategory.Proxy);
    private static readonly ProxyClassification Direct = new(TrafficCategory.Direct);
    private static readonly ProxyClassification Reject = new(TrafficCategory.Reject);
    private static readonly ProxyClassification Unknown = new(
        TrafficCategory.Unknown,
        UnknownTrafficReason.AmbiguousProxyType);

    [TestMethod]
    public void RouterMatchesEveryStableSharedClassificationWithoutChangingNativeResult()
    {
        (string RawType, ProxyClassification Native, SharedProxyTypeClassification Shared)[] cases =
        [
            ("Vmess", Proxy, SharedProxyTypeClassification.Proxy),
            ("Direct", Direct, SharedProxyTypeClassification.Direct),
            ("Reject", Reject, SharedProxyTypeClassification.Reject),
        ];

        foreach (var testCase in cases)
        {
            var result = SharedCoreProxyTypeRouter.Route(
                testCase.RawType,
                testCase.Native,
                _ => testCase.Shared);

            Assert.AreEqual(testCase.Native, result.Classification);
            Assert.AreEqual(SharedCoreProxyTypeRouteSource.SharedShadow, result.Source);
            Assert.AreEqual(SharedCoreProxyTypeRouteStatus.Matched, result.Status);
        }
    }

    [TestMethod]
    public void RouterKeepsNativeResultForUnrecognizedMismatchAndAdapterFailures()
    {
        var unrecognized = Route(SharedProxyTypeClassification.Unrecognized, Unknown);
        var mismatch = Route(SharedProxyTypeClassification.Direct, Proxy);
        (SharedProxyTypeAdapterFailure Failure, SharedCoreProxyTypeRouteStatus Status)[] failures =
        [
            (SharedProxyTypeAdapterFailure.UnsupportedAbiVersion,
                SharedCoreProxyTypeRouteStatus.AbiMismatch),
            (SharedProxyTypeAdapterFailure.NativeCallFailed,
                SharedCoreProxyTypeRouteStatus.NativeCallFailed),
            (SharedProxyTypeAdapterFailure.UnsupportedProxyTypeInput,
                SharedCoreProxyTypeRouteStatus.UnsupportedInput),
            (SharedProxyTypeAdapterFailure.ProxyTypeInputTooLong,
                SharedCoreProxyTypeRouteStatus.InputTooLong),
            (SharedProxyTypeAdapterFailure.UnsupportedProxyTypeCategory,
                SharedCoreProxyTypeRouteStatus.UnexpectedResult),
        ];

        Assert.AreEqual(Unknown, unrecognized.Classification);
        Assert.AreEqual(SharedCoreProxyTypeRouteSource.NativeFallback, unrecognized.Source);
        Assert.AreEqual(SharedCoreProxyTypeRouteStatus.Unrecognized, unrecognized.Status);
        Assert.AreEqual(Proxy, mismatch.Classification);
        Assert.AreEqual(SharedCoreProxyTypeRouteStatus.Mismatch, mismatch.Status);

        foreach (var failure in failures)
        {
            var result = SharedCoreProxyTypeRouter.Route(
                "Synthetic",
                Proxy,
                _ => throw new SharedProxyTypeAdapterException(
                    failure.Failure,
                    "synthetic"));
            Assert.AreEqual(Proxy, result.Classification);
            Assert.AreEqual(SharedCoreProxyTypeRouteSource.NativeFallback, result.Source);
            Assert.AreEqual(failure.Status, result.Status);
        }

        var unknownFailure = SharedCoreProxyTypeRouter.Route(
            "Synthetic",
            Proxy,
            _ => throw new ArgumentException("synthetic"));
        Assert.AreEqual(Proxy, unknownFailure.Classification);
        Assert.AreEqual(SharedCoreProxyTypeRouteStatus.UnknownFailure, unknownFailure.Status);
    }

    [TestMethod]
    public void ShadowDeduplicatesSourceAndStatusAndIgnoresReporterFailure()
    {
        var observations = new List<SharedCoreProxyTypeShadowObservation>();
        SharedCoreProxyTypeShadow.ConfigureReporter(observation =>
        {
            observations.Add(observation);
            throw new InvalidOperationException("synthetic");
        });
        try
        {
            for (var index = 0; index < 2; index += 1)
            {
                Assert.AreEqual(
                    Proxy,
                    SharedCoreProxyTypeShadow.Observe(
                        "Vmess",
                        Proxy,
                        _ => SharedProxyTypeClassification.Proxy));
            }
            Assert.AreEqual(
                Unknown,
                SharedCoreProxyTypeShadow.Observe(
                    "Selector",
                    Unknown,
                    _ => SharedProxyTypeClassification.Unrecognized));

            CollectionAssert.AreEqual(
                new[]
                {
                    new SharedCoreProxyTypeShadowObservation(
                        SharedCoreProxyTypeRouteSource.SharedShadow,
                        SharedCoreProxyTypeRouteStatus.Matched),
                    new SharedCoreProxyTypeShadowObservation(
                        SharedCoreProxyTypeRouteSource.NativeFallback,
                        SharedCoreProxyTypeRouteStatus.Unrecognized),
                },
                observations);
        }
        finally
        {
            SharedCoreProxyTypeShadow.ConfigureReporter(null);
        }
    }

    [TestMethod]
    public void ObservationGateKeysBySourceAndStatus()
    {
        var gate = new SharedCoreProxyTypeShadowObservationGate();
        var matched = new SharedCoreProxyTypeShadowObservation(
            SharedCoreProxyTypeRouteSource.SharedShadow,
            SharedCoreProxyTypeRouteStatus.Matched);
        var fallback = new SharedCoreProxyTypeShadowObservation(
            SharedCoreProxyTypeRouteSource.NativeFallback,
            SharedCoreProxyTypeRouteStatus.Matched);

        Assert.IsTrue(gate.ShouldReport(matched));
        Assert.IsFalse(gate.ShouldReport(matched));
        Assert.IsTrue(gate.ShouldReport(fallback));
        gate.Reset();
        Assert.IsTrue(gate.ShouldReport(matched));
    }

    private static SharedCoreProxyTypeRouteResult Route(
        SharedProxyTypeClassification sharedClassification,
        ProxyClassification nativeClassification)
    {
        return SharedCoreProxyTypeRouter.Route(
            "Synthetic",
            nativeClassification,
            _ => sharedClassification);
    }
}
