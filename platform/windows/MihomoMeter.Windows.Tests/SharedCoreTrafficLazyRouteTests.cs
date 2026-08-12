using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class SharedCoreTrafficLazyRouteTests
{
    [TestMethod]
    public void LazyRouterDoesNotEvaluateFallbackOnSuccess()
    {
        var fallbackCount = 0;

        var result = SharedCoreTrafficRouter.RouteLazy(
            1_500,
            () =>
            {
                fallbackCount++;
                return "原生回退";
            },
            SharedCoreTrafficFormat.ByteCount,
            () => 1,
            _ => MatchingScale());

        Assert.AreEqual("1.50 KB", result.Text);
        Assert.AreEqual(SharedCoreTrafficRouteSource.SharedPrimary, result.Source);
        Assert.AreEqual(SharedCoreTrafficRouteStatus.Succeeded, result.Status);
        Assert.AreEqual(0, fallbackCount);
    }

    [TestMethod]
    public void LazyRouterStopsBeforeScalingForAbiMismatch()
    {
        var scaleCount = 0;

        AssertLazyFallback(
            SharedCoreTrafficRouteStatus.AbiMismatch,
            () => 2,
            _ =>
            {
                scaleCount++;
                return MatchingScale();
            });

        Assert.AreEqual(0, scaleCount);
    }

    [TestMethod]
    public void LazyRouterEvaluatesFallbackExactlyOnceForSharedFailures()
    {
        AssertLazyFallback(
            SharedCoreTrafficRouteStatus.NativeCallFailed,
            () => throw new DllNotFoundException("synthetic"),
            _ => MatchingScale());
        AssertLazyFallback(
            SharedCoreTrafficRouteStatus.UnexpectedResult,
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                SharedTrafficUnit.Kilobytes,
                3));
        AssertLazyFallback(
            SharedCoreTrafficRouteStatus.UnexpectedResult,
            () => 1,
            _ => new SharedTrafficScale(
                1.5,
                (SharedTrafficUnit)99,
                2));
        AssertLazyFallback(
            SharedCoreTrafficRouteStatus.UnknownFailure,
            () => 1,
            _ => throw new LazyRouteSyntheticException());
    }

    [TestMethod]
    public void LazyRouteIgnoresReporterFailureWithoutEvaluatingFallback()
    {
        var observations = new List<SharedCoreTrafficRouteObservation>();
        var fallbackCount = 0;
        SharedCoreTrafficRoute.ConfigureReporter(observation =>
        {
            observations.Add(observation);
            throw new InvalidOperationException("synthetic");
        });
        try
        {
            for (var index = 0; index < 2; index++)
            {
                var text = SharedCoreTrafficRoute.ResolveLazy(
                    1_500,
                    () =>
                    {
                        fallbackCount++;
                        return "原生回退";
                    },
                    SharedCoreTrafficFormat.ByteCount,
                    () => 1,
                    _ => MatchingScale());
                Assert.AreEqual("1.50 KB", text);
            }

            Assert.AreEqual(0, fallbackCount);
            CollectionAssert.AreEqual(
                new[]
                {
                    new SharedCoreTrafficRouteObservation(
                        SharedCoreTrafficFormat.ByteCount,
                        SharedCoreTrafficRouteSource.SharedPrimary,
                        SharedCoreTrafficRouteStatus.Succeeded),
                },
                observations);
        }
        finally
        {
            SharedCoreTrafficRoute.ConfigureReporter(null);
        }
    }

    [TestMethod]
    public void DeterministicDifferentialMatchesNativeFormatters()
    {
        foreach (var bytes in DeterministicValues())
        {
            var scale = MihomoMeterSharedCore.ScaleTraffic(bytes);
            Assert.AreEqual(
                TrafficDisplayUnits.ByteCount(bytes),
                SharedCoreTrafficDisplayFormatter.Format(
                    scale,
                    SharedCoreTrafficFormat.ByteCount),
                $"累计流量差分不一致：{bytes}");
            Assert.AreEqual(
                TrafficDisplayUnits.Rate(bytes),
                SharedCoreTrafficDisplayFormatter.Format(
                    scale,
                    SharedCoreTrafficFormat.Rate),
                $"完整速率差分不一致：{bytes}");
            Assert.AreEqual(
                TrafficDisplayUnits.CompactRate(bytes),
                SharedCoreTrafficDisplayFormatter.Format(
                    scale,
                    SharedCoreTrafficFormat.CompactRate),
                $"紧凑速率差分不一致：{bytes}");
        }
    }

    private static void AssertLazyFallback(
        SharedCoreTrafficRouteStatus expectedStatus,
        Func<uint> abiVersion,
        Func<ulong, SharedTrafficScale> scaleTraffic)
    {
        var fallbackCount = 0;
        var result = SharedCoreTrafficRouter.RouteLazy(
            1_500,
            () =>
            {
                fallbackCount++;
                return "原生回退";
            },
            SharedCoreTrafficFormat.ByteCount,
            abiVersion,
            scaleTraffic);

        Assert.AreEqual("原生回退", result.Text);
        Assert.AreEqual(SharedCoreTrafficRouteSource.NativeFallback, result.Source);
        Assert.AreEqual(expectedStatus, result.Status);
        Assert.AreEqual(1, fallbackCount);
    }

    private static SharedTrafficScale MatchingScale()
    {
        return new SharedTrafficScale(
            1.5,
            SharedTrafficUnit.Kilobytes,
            2);
    }

    private static IEnumerable<ulong> DeterministicValues()
    {
        foreach (var value in DeterministicBoundaryValues())
        {
            yield return value;
        }

        var generator = new SplitMix64(0x4D49_484F_4D45_5445);
        for (var index = 0; index < 10_000; index++)
        {
            yield return generator.Next();
        }
    }

    private static IEnumerable<ulong> DeterministicBoundaryValues()
    {
        var values = new SortedSet<ulong> { 0, ulong.MaxValue };
        ulong[] decimalUnits = [1_000, 1_000_000, 1_000_000_000, 1_000_000_000_000];

        foreach (var unit in decimalUnits)
        {
            AppendNeighborhood(values, unit);
            AppendNeighborhood(values, unit * 10);
            AppendNeighborhood(values, unit * 100);
            AppendNeighborhood(values, unit + unit * 5 / 1_000);
            AppendNeighborhood(values, unit * 9 + unit * 995 / 1_000);
            AppendNeighborhood(values, unit * 10 + unit * 5 / 100);
            AppendNeighborhood(values, unit * 99 + unit * 95 / 100);
            AppendNeighborhood(values, unit * 100 + unit / 2);
            AppendNeighborhood(values, unit * 999 + unit / 2);
        }

        return values;
    }

    private static void AppendNeighborhood(ISet<ulong> values, ulong center)
    {
        for (ulong distance = 0; distance <= 2; distance++)
        {
            values.Add(center + distance);
            if (center >= distance)
            {
                values.Add(center - distance);
            }
        }
    }

    private struct SplitMix64(ulong seed)
    {
        private ulong _state = seed;

        public ulong Next()
        {
            unchecked
            {
                _state += 0x9E37_79B9_7F4A_7C15;
                var value = _state;
                value = (value ^ (value >> 30)) * 0xBF58_476D_1CE4_E5B9;
                value = (value ^ (value >> 27)) * 0x94D0_49BB_1331_11EB;
                return value ^ (value >> 31);
            }
        }
    }

    private sealed class LazyRouteSyntheticException : Exception
    {
    }
}
