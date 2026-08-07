using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class TrafficMeasurementSessionTests
{
    [TestMethod]
    public void SharedFixturesEstablishBaselineAndThenProduceRates()
    {
        var timeProvider = new ManualTimeProvider();
        var proxies = MihomoJsonDecoder.Decode<MihomoProxiesResponse>(
            FixtureLoader.Load("proxies"));
        var initial = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            FixtureLoader.Load("connections-initial"));
        var next = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            FixtureLoader.Load("connections-next"));
        var session = new TrafficMeasurementSession(proxies.ToCatalog(), timeProvider);

        var baseline = session.Consume(initial);
        timeProvider.Advance(TimeSpan.FromSeconds(1));
        var measurement = session.Consume(next);

        Assert.IsNull(baseline.RateWindow);
        Assert.IsInstanceOfType<TrafficLedgerBaselineEstablished>(baseline.LedgerObservation.Transition);
        Assert.IsNotNull(measurement.RateWindow);
        Assert.AreEqual((ulong)220, measurement.RateWindow.Smoothed.Proxy.UploadBytesPerSecond);
        Assert.AreEqual((ulong)580, measurement.RateWindow.Smoothed.Proxy.DownloadBytesPerSecond);
        var ledgerDelta = measurement.LedgerObservation.Transition as TrafficLedgerDelta;
        Assert.IsNotNull(ledgerDelta);
        Assert.AreEqual((ulong)220, ledgerDelta.Report.Categories.Proxy.Upload);
        Assert.AreEqual((ulong)580, ledgerDelta.Report.Categories.Proxy.Download);
        Assert.AreEqual(timeProvider.GetUtcNow(), measurement.LedgerObservation.ObservedAt);
    }

    [TestMethod]
    public void RequestsCatalogRefreshOnlyWhileLeafIsMissing()
    {
        var session = new TrafficMeasurementSession(new ProxyCatalog(
            new Dictionary<string, string>()));
        var snapshot = new MihomoConnectionsSnapshot
        {
            UploadTotal = 10,
            DownloadTotal = 20,
            Connections =
            [
                new MihomoConnectionResponse
                {
                    Id = "synthetic",
                    Upload = 10,
                    Download = 20,
                    Chains = ["Synthetic Proxy"],
                },
            ],
        };

        var missing = session.Consume(snapshot);
        session.UpdateCatalog(new ProxyCatalog(new Dictionary<string, string>
        {
            ["Synthetic Proxy"] = "Vmess",
        }));
        var resolved = session.Consume(snapshot);

        Assert.IsTrue(missing.RequiresCatalogRefresh);
        Assert.IsFalse(resolved.RequiresCatalogRefresh);
    }

    private sealed class ManualTimeProvider : TimeProvider
    {
        private long _timestamp;
        private DateTimeOffset _utcNow = DateTimeOffset.FromUnixTimeSeconds(1_700_000_000);

        public override long TimestampFrequency => TimeSpan.TicksPerSecond;

        public override long GetTimestamp()
        {
            return _timestamp;
        }

        public override DateTimeOffset GetUtcNow()
        {
            return _utcNow;
        }

        public void Advance(TimeSpan duration)
        {
            _timestamp += duration.Ticks;
            _utcNow += duration;
        }
    }
}
