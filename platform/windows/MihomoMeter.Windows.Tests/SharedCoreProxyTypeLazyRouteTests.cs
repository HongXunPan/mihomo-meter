using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SharedCoreProxyTypeLazyRouteTests
{
    private static readonly ProxyClassification Proxy = new(TrafficCategory.Proxy);
    private static readonly ProxyClassification Direct = new(TrafficCategory.Direct);
    private static readonly ProxyClassification Reject = new(TrafficCategory.Reject);
    private static readonly ProxyClassification Unknown = new(
        TrafficCategory.Unknown,
        UnknownTrafficReason.AmbiguousProxyType);

    [TestMethod]
    public void LazyRouterDoesNotEvaluateFallbackOnSharedSuccess()
    {
        (SharedProxyTypeClassification Shared, ProxyClassification Expected)[] cases =
        [
            (SharedProxyTypeClassification.Proxy, Proxy),
            (SharedProxyTypeClassification.Direct, Direct),
            (SharedProxyTypeClassification.Reject, Reject),
        ];

        foreach (var testCase in cases)
        {
            var fallbackCount = 0;
            var classifyCount = 0;
            var result = SharedCoreProxyTypeRouter.RouteLazy(
                "Synthetic",
                () =>
                {
                    fallbackCount += 1;
                    return Unknown;
                },
                _ =>
                {
                    classifyCount += 1;
                    return testCase.Shared;
                });

            Assert.AreEqual(testCase.Expected, result.Classification);
            Assert.AreEqual(SharedCoreProxyTypeRouteSource.SharedPrimary, result.Source);
            Assert.AreEqual(SharedCoreProxyTypeRouteStatus.Succeeded, result.Status);
            Assert.AreEqual(1, classifyCount);
            Assert.AreEqual(0, fallbackCount);
        }
    }

    [TestMethod]
    public void LazyRouterEvaluatesFallbackExactlyOnceForUnrecognizedAndSharedFailures()
    {
        AssertLazyFallback(
            SharedCoreProxyTypeRouteStatus.Unrecognized,
            _ => SharedProxyTypeClassification.Unrecognized);

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
        foreach (var failure in failures)
        {
            AssertLazyFallback(
                failure.Status,
                _ => throw new SharedProxyTypeAdapterException(
                    failure.Failure,
                    "synthetic"));
        }

        AssertLazyFallback(
            SharedCoreProxyTypeRouteStatus.NativeCallFailed,
            _ => throw new DllNotFoundException("synthetic"));
        AssertLazyFallback(
            SharedCoreProxyTypeRouteStatus.UnknownFailure,
            _ => throw new ArgumentException("synthetic"));
    }

    [TestMethod]
    public void LazyRouteIgnoresReporterFailureWithoutEvaluatingFallback()
    {
        var observations = new List<SharedCoreProxyTypeRouteObservation>();
        var fallbackCount = 0;
        SharedCoreProxyTypeRoute.ConfigureReporter(observation =>
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
                    SharedCoreProxyTypeRoute.ResolveLazy(
                        "Vmess",
                        () =>
                        {
                            fallbackCount += 1;
                            return Unknown;
                        },
                        _ => SharedProxyTypeClassification.Proxy));
            }

            Assert.AreEqual(0, fallbackCount);
            CollectionAssert.AreEqual(
                new[]
                {
                    new SharedCoreProxyTypeRouteObservation(
                        SharedCoreProxyTypeRouteSource.SharedPrimary,
                        SharedCoreProxyTypeRouteStatus.Succeeded),
                },
                observations);
        }
        finally
        {
            SharedCoreProxyTypeRoute.ConfigureReporter(null);
        }
    }

    private static void AssertLazyFallback(
        SharedCoreProxyTypeRouteStatus expectedStatus,
        Func<string, SharedProxyTypeClassification> classifyProxyType)
    {
        var fallbackCount = 0;
        var classifyCount = 0;
        var result = SharedCoreProxyTypeRouter.RouteLazy(
            "Synthetic",
            () =>
            {
                fallbackCount += 1;
                return Unknown;
            },
            rawType =>
            {
                classifyCount += 1;
                return classifyProxyType(rawType);
            });

        Assert.AreEqual(Unknown, result.Classification);
        Assert.AreEqual(SharedCoreProxyTypeRouteSource.NativeFallback, result.Source);
        Assert.AreEqual(expectedStatus, result.Status);
        Assert.AreEqual(1, classifyCount);
        Assert.AreEqual(1, fallbackCount);
    }
}
