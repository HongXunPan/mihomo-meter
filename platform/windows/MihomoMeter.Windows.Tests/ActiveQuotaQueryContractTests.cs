using System.Net;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Quota;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ActiveQuotaQueryContractTests
{
    [TestMethod]
    public void RejectsNonHttpsSubscriptionAndRedirectTargets()
    {
        var subscriptionError = Assert.ThrowsExactly<ActiveQuotaQueryException>(() =>
            MihomoActiveQuotaQueryClient.EnsureHttps(
                new Uri("http://example.com/sub"),
                ActiveQuotaQueryFailureCategory.InsecureUrl));
        var redirectError = Assert.ThrowsExactly<ActiveQuotaQueryException>(() =>
            MihomoActiveQuotaQueryClient.EnsureHttps(
                new Uri("http://example.com/redirect"),
                ActiveQuotaQueryFailureCategory.InsecureRedirect));

        Assert.AreEqual(ActiveQuotaQueryFailureCategory.InsecureUrl, subscriptionError.Category);
        Assert.AreEqual(
            ActiveQuotaQueryFailureCategory.InsecureRedirect,
            redirectError.Category);
    }

    [TestMethod]
    public void PrefersStandardHeaderAndAcceptsCompatibleSuffix()
    {
        using var response = new HttpResponseMessage(HttpStatusCode.OK);
        response.Headers.TryAddWithoutValidation(
            "X-Metadata-Subscription-Userinfo",
            "upload=9; download=8; total=100");
        response.Headers.TryAddWithoutValidation(
            "Subscription-Userinfo",
            "upload=1; download=2; total=100");

        Assert.AreEqual(
            "upload=1; download=2; total=100",
            MihomoActiveQuotaQueryClient.Header(response));

        response.Headers.Remove("Subscription-Userinfo");
        Assert.AreEqual(
            "upload=9; download=8; total=100",
            MihomoActiveQuotaQueryClient.Header(response));
    }

    [TestMethod]
    public void HandlerAlwaysUsesSelectedMihomoProxyWithoutAutoRedirect()
    {
        var proxy = new MihomoLocalProxy(MihomoLocalProxyKind.Socks, "127.0.0.1", 7892);
        using var handler = MihomoActiveQuotaQueryClient.CreateHandler(proxy);

        Assert.IsTrue(handler.UseProxy);
        Assert.IsFalse(handler.AllowAutoRedirect);
        Assert.IsFalse(handler.UseCookies);
        Assert.IsNotNull(handler.Proxy);
        Assert.AreEqual(
            new Uri("socks5://127.0.0.1:7892"),
            handler.Proxy.GetProxy(new Uri("https://example.com/sub")));
    }
}
