using Microsoft.VisualStudio.TestTools.UnitTesting;
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
}
