using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Text;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class MihomoControllerModelsTests
{
    [TestMethod]
    public void DecodesSharedVersionAndProxyFixtures()
    {
        var version = MihomoJsonDecoder.Decode<MihomoVersionResponse>(
            FixtureLoader.Load("version"));
        var proxies = MihomoJsonDecoder.Decode<MihomoProxiesResponse>(
            FixtureLoader.Load("proxies"));

        Assert.AreEqual("v1.19.0", version.Version);
        Assert.AreEqual("Vmess", proxies.Proxies["Synthetic Proxy"].Type);
        Assert.AreEqual("Direct", proxies.ToCatalog().TypeFor("DIRECT"));
    }

    [TestMethod]
    public void DecodesSharedConnectionFixture()
    {
        var response = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            FixtureLoader.Load("connections-next"));
        var snapshot = response.ToTrafficSnapshot();

        Assert.AreEqual(2, snapshot.Connections.Count);
        Assert.AreEqual((ulong)1_400, snapshot.KernelTotal.Upload);
        Assert.AreEqual((ulong)2_900, snapshot.KernelTotal.Download);
    }

    [TestMethod]
    public void RejectsUnsupportedPayload()
    {
        Assert.ThrowsExactly<MihomoResponseException>(() =>
            MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>("{}"u8));
        Assert.ThrowsExactly<MihomoResponseException>(() =>
            MihomoJsonDecoder.Decode<MihomoProxiesResponse>("{\"proxies\":null}"u8));
        Assert.ThrowsExactly<MihomoResponseException>(() =>
            MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
                """
                {
                  "downloadTotal": 1,
                  "uploadTotal": 1,
                  "connections": [
                    { "id": "duplicate", "upload": 0, "download": 0, "chains": [] },
                    { "id": "duplicate", "upload": 0, "download": 0, "chains": [] }
                  ]
                }
                """u8));
    }

    [TestMethod]
    public void DecodesOnlySanitizedMetadata()
    {
        var response = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            """
            {
              "downloadTotal": 0,
              "uploadTotal": 0,
              "connections": [{
                "id": "synthetic",
                "upload": 0,
                "download": 0,
                "chains": ["Synthetic Proxy"],
                "metadata": {
                  "host": "example.test",
                  "processPath": "C:\\Program Files\\Synthetic\\synthetic.exe"
                }
              }]
            }
            """u8);

        Assert.AreEqual(
            new ConnectionMetadata("example.test", "synthetic.exe"),
            response.ToTrafficSnapshot().Connections[0].Metadata);
    }

    [TestMethod]
    public void RejectsIpMalformedAndOversizedMetadataForCoverage()
    {
        var oversized = new string('x', 2_049);
        var payload = Encoding.UTF8.GetBytes($$"""
            {
              "downloadTotal": 0,
              "uploadTotal": 0,
              "connections": [{
                "id": "synthetic",
                "upload": 0,
                "download": 0,
                "chains": ["Synthetic Proxy"],
                "metadata": {
                  "host": "203.0.113.1",
                  "sniffHost": "{{oversized}}",
                  "process": 42,
                  "processPath": "/"
                }
              }]
            }
            """);

        var response = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(payload);

        Assert.AreEqual(
            ConnectionMetadata.Unavailable,
            response.ToTrafficSnapshot().Connections[0].Metadata);
    }

    [TestMethod]
    public void UsesSniffHostAndApplicationBundleFallbacks()
    {
        var response = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            """
            {
              "downloadTotal": 0,
              "uploadTotal": 0,
              "connections": [{
                "id": "synthetic",
                "upload": 0,
                "download": 0,
                "chains": ["Synthetic Proxy"],
                "metadata": {
                  "host": " ",
                  "sniffHost": "fallback.test",
                  "process": " ",
                  "processPath": "C:\\Apps\\Synthetic.app\\Contents\\helper"
                }
              }]
            }
            """u8);

        Assert.AreEqual(
            new ConnectionMetadata("fallback.test", "Synthetic"),
            response.ToTrafficSnapshot().Connections[0].Metadata);
    }

    [TestMethod]
    public void DecodesStartAndToleratesMalformedOptionalValues()
    {
        var valid = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            """
            {
              "downloadTotal": 0,
              "uploadTotal": 0,
              "connections": [{
                "id": "valid",
                "upload": 0,
                "download": 0,
                "chains": [],
                "start": "2026-08-08T01:02:03.456Z"
              }]
            }
            """u8);
        var malformed = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            """
            {
              "downloadTotal": 0,
              "uploadTotal": 0,
              "connections": [{
                "id": "malformed",
                "upload": 0,
                "download": 0,
                "chains": [],
                "start": { "future": true }
              }]
            }
            """u8);

        Assert.AreEqual(
            DateTimeOffset.Parse("2026-08-08T01:02:03.456Z"),
            valid.Connections[0].StartedAt);
        Assert.IsNull(malformed.Connections[0].StartedAt);
    }

    [DataRow("always", MihomoProcessMatchingMode.Always)]
    [DataRow(" STRICT ", MihomoProcessMatchingMode.Strict)]
    [DataRow("off", MihomoProcessMatchingMode.Off)]
    [TestMethod]
    public void MapsKnownProcessMatchingModes(
        string value,
        MihomoProcessMatchingMode expected)
    {
        var response = MihomoJsonDecoder.Decode<MihomoRuntimeConfigurationResponse>(
            Encoding.UTF8.GetBytes($$"""{"find-process-mode":"{{value}}"}"""));

        Assert.AreEqual(expected, response.ToProcessMatchingMode());
    }

    [TestMethod]
    public void KeepsUnknownProcessMatchingModeUnavailable()
    {
        var response = MihomoJsonDecoder.Decode<MihomoRuntimeConfigurationResponse>(
            """{"find-process-mode":"future"}"""u8);

        Assert.IsNull(response.ToProcessMatchingMode());
    }

    [TestMethod]
    public void DecodesRuleAndRuntimeConfiguration()
    {
        var connections = MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(
            """
            {
              "downloadTotal": 0,
              "uploadTotal": 0,
              "connections": [{
                "id": "synthetic",
                "upload": 0,
                "download": 0,
                "chains": ["Synthetic Proxy"],
                "rule": "DOMAIN-SUFFIX"
              }]
            }
            """u8);
        var configuration = MihomoJsonDecoder.Decode<MihomoRuntimeConfigurationResponse>(
            """
            {
              "mode": "rule",
              "allow-lan": false,
              "ipv6": true,
              "mixed-port": 7890,
              "find-process-mode": "strict",
              "tun": {
                "enable": true,
                "stack": "system",
                "auto-route": true
              }
            }
            """u8).ToRuntimeConfiguration();

        Assert.AreEqual("DOMAIN-SUFFIX", connections.ToTrafficSnapshot().Connections[0].Rule);
        Assert.AreEqual("rule", configuration.Mode);
        Assert.AreEqual(true, configuration.IsTunEnabled);
        Assert.AreEqual("system", configuration.TunStack);
        Assert.AreEqual(true, configuration.AutomaticallyRoutesTraffic);
        Assert.AreEqual(true, configuration.IsIPv6Enabled);
        Assert.AreEqual(false, configuration.AllowsLan);
        Assert.AreEqual(7890, configuration.MixedPort);
        Assert.AreEqual(MihomoProcessMatchingMode.Strict, configuration.ProcessMatchingMode);
    }
}
