using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ControllerEndpointTests
{
    [TestMethod]
    public void NormalizesLoopbackAddressWithoutScheme()
    {
        var endpoint = new ControllerEndpoint("127.0.0.1:9090");

        Assert.AreEqual("http://127.0.0.1:9090", endpoint.NormalizedAddress);
        Assert.AreEqual(
            "http://127.0.0.1:9090/version",
            endpoint.HttpUri("/version").AbsoluteUri);
        Assert.AreEqual(
            "ws://127.0.0.1:9090/connections?interval=500",
            endpoint.WebSocketUri("/connections", "interval=500").AbsoluteUri);
    }

    [TestMethod]
    public void AcceptsIpv6LoopbackAddress()
    {
        var endpoint = new ControllerEndpoint("http://[::1]:9090");

        Assert.AreEqual("http://[::1]:9090", endpoint.NormalizedAddress);
    }

    [TestMethod]
    public void RejectsUnsupportedAddresses()
    {
        AssertReason("http://192.168.1.2:9090", ControllerEndpointError.NonLoopbackAddress);
        AssertReason("http://127.0.0.1", ControllerEndpointError.MissingOrInvalidPort);
        AssertReason("http://127.0.0.1:9090/api", ControllerEndpointError.UnsupportedPath);
        AssertReason("http://127.0.0.1:9090?", ControllerEndpointError.InvalidAddress);
        AssertReason("http://127.0.0.1:9090#", ControllerEndpointError.InvalidAddress);
        AssertReason("http://user@127.0.0.1:9090", ControllerEndpointError.InvalidAddress);
    }

    private static void AssertReason(string address, ControllerEndpointError reason)
    {
        try
        {
            _ = new ControllerEndpoint(address);
            Assert.Fail("无效地址不应通过验证。");
        }
        catch (ControllerEndpointException exception)
        {
            Assert.AreEqual(reason, exception.Reason);
        }
    }
}
