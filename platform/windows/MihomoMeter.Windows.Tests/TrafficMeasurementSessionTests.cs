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
        Assert.AreEqual(1, measurement.LiveProxyConnections.Count);
        Assert.AreEqual(new TrafficRate(220, 580), measurement.LiveProxyConnections[0].Rate);
        Assert.AreEqual(1, measurement.LiveDirectConnections.Count);
        Assert.AreEqual(new TrafficRate(80, 220), measurement.LiveDirectConnections[0].Rate);
        Assert.AreEqual(1, measurement.ConnectionAttributionDeltas.Count);
        Assert.AreEqual(
            new TrafficBytes(220, 580),
            measurement.ConnectionAttributionDeltas[0].Bytes);
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

    [TestMethod]
    public void TracksOnlyReliablyClassifiedProxyMetadataAndClearsOnReset()
    {
        var session = new TrafficMeasurementSession(new ProxyCatalog(
            new Dictionary<string, string>
            {
                ["Synthetic Proxy"] = "Vmess",
                ["DIRECT"] = "Direct",
            }));
        var initial = Snapshot(
            Connection("proxy", "Synthetic Proxy", true, false),
            Connection("direct", "DIRECT", true, true));

        var baseline = session.Consume(initial);
        var upgraded = session.Consume(Snapshot(
            Connection("proxy", "Synthetic Proxy", false, true),
            Connection("direct", "DIRECT", true, true)));
        session.ResetBaseline();
        var reset = session.Consume(Snapshot(
            Connection("direct", "DIRECT", true, true)));

        Assert.AreEqual(
            new ConnectionAttributionCoverage(1, 1, 0, 0),
            baseline.AttributionCoverage);
        Assert.AreEqual(
            new ConnectionAttributionCoverage(1, 1, 1, 1),
            upgraded.AttributionCoverage);
        Assert.AreEqual(ConnectionAttributionCoverage.Empty, reset.AttributionCoverage);
    }

    [TestMethod]
    public void CounterResetClearsAttributionCoverage()
    {
        var session = new TrafficMeasurementSession(new ProxyCatalog(
            new Dictionary<string, string>
            {
                ["Synthetic Proxy"] = "Vmess",
            }));
        _ = session.Consume(new MihomoConnectionsSnapshot
        {
            UploadTotal = 100,
            DownloadTotal = 100,
            Connections = [Connection("proxy", "Synthetic Proxy", true, true)],
        });

        var reset = session.Consume(new MihomoConnectionsSnapshot
        {
            UploadTotal = 0,
            DownloadTotal = 0,
            Connections = [],
        });

        Assert.IsTrue(reset.CountersReset);
        Assert.AreEqual(ConnectionAttributionCoverage.Empty, reset.AttributionCoverage);
        Assert.AreEqual(0, reset.LiveProxyConnections.Count);
        Assert.AreEqual(0, reset.LiveDirectConnections.Count);
    }

    private static MihomoConnectionsSnapshot Snapshot(params MihomoConnectionResponse[] connections)
    {
        return new MihomoConnectionsSnapshot
        {
            UploadTotal = (ulong)connections.Sum(connection => (long)connection.Upload),
            DownloadTotal = (ulong)connections.Sum(connection => (long)connection.Download),
            Connections = [.. connections],
        };
    }

    private static MihomoConnectionResponse Connection(
        string id,
        string chain,
        bool hasHostname,
        bool hasApplication)
    {
        return new MihomoConnectionResponse
        {
            Id = id,
            Upload = 1,
            Download = 1,
            Chains = [chain],
            Metadata = new ConnectionMetadata(
                hasHostname ? "example.test" : null,
                hasApplication ? "Synthetic" : null),
        };
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
