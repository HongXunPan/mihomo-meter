using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ProxyClassifierTests
{
    private static readonly ProxyClassifier Classifier = new(new ProxyCatalog(
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["DIRECT"] = "Direct",
            ["REJECT"] = "Reject",
            ["REJECT-DROP"] = "RejectDrop",
            ["Synthetic Group"] = "Selector",
            ["Synthetic Proxy"] = "Vmess",
        }));

    [TestMethod]
    public void ClassifiesConcreteLeafWithoutUsingOuterGroup()
    {
        var result = Classifier.Classify(["Synthetic Proxy", "Synthetic Group"]);

        Assert.AreEqual(TrafficCategory.Proxy, result.Category);
        Assert.IsNull(result.UnknownReason);
    }

    [TestMethod]
    public void ClassifiesEverySupportedConcreteProxyType()
    {
        string[] supportedTypes =
        [
            "AnyTLS",
            "Http",
            "Hysteria",
            "Hysteria2",
            "Shadowsocks",
            "ShadowsocksR",
            "Snell",
            "Socks5",
            "Ssh",
            "Trojan",
            "Tuic",
            "Vless",
            "Vmess",
            "WireGuard",
        ];

        foreach (var type in supportedTypes)
        {
            var classifier = new ProxyClassifier(new ProxyCatalog(
                new Dictionary<string, string>(StringComparer.Ordinal)
                {
                    ["Synthetic Proxy"] = type,
                }));

            Assert.AreEqual(
                new ProxyClassification(TrafficCategory.Proxy),
                classifier.Classify(["Synthetic Proxy"]),
                $"{type} 应归类为 Proxy");
        }
    }

    [TestMethod]
    public void KeepsDirectAndRejectSeparateFromProxy()
    {
        Assert.AreEqual(TrafficCategory.Direct, Classifier.Classify(["DIRECT"]).Category);
        Assert.AreEqual(TrafficCategory.Reject, Classifier.Classify(["REJECT"]).Category);
        Assert.AreEqual(TrafficCategory.Reject, Classifier.Classify(["REJECT-DROP"]).Category);
    }

    [TestMethod]
    public void DoesNotGuessMissingOrAmbiguousLeaf()
    {
        Assert.AreEqual(
            UnknownTrafficReason.EmptyChain,
            Classifier.Classify([]).UnknownReason);
        Assert.AreEqual(
            UnknownTrafficReason.MissingCatalogEntry,
            Classifier.Classify(["Missing"]).UnknownReason);
        Assert.AreEqual(
            UnknownTrafficReason.AmbiguousProxyType,
            Classifier.Classify(["Synthetic Group"]).UnknownReason);
    }

    [TestMethod]
    public void InvokesInjectedResolverOnlyAfterCatalogHitWithNativeClassification()
    {
        var invocations = new List<(string RawType, ProxyClassification Classification)>();
        var classifier = new ProxyClassifier(
            new ProxyCatalog(new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Synthetic Proxy"] = "Vmess",
            }),
            (rawType, nativeClassification) =>
            {
                invocations.Add((rawType, nativeClassification));
                return nativeClassification;
            });

        _ = classifier.Classify([]);
        _ = classifier.Classify(["Missing"]);
        Assert.AreEqual(
            new ProxyClassification(TrafficCategory.Proxy),
            classifier.Classify(["Synthetic Proxy"]));
        Assert.AreEqual(1, invocations.Count);
        Assert.AreEqual("Vmess", invocations[0].RawType);
        Assert.AreEqual(
            new ProxyClassification(TrafficCategory.Proxy),
            invocations[0].Classification);
    }

    [TestMethod]
    public void LazyResolverControlsWhetherNativeClassificationIsEvaluated()
    {
        var invocations = new List<string>();
        var sharedClassifier = new ProxyClassifier(
            new ProxyCatalog(new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Synthetic"] = "Selector",
            }),
            (LazyProxyTypeResolver)((rawType, _) =>
            {
                invocations.Add(rawType);
                return new ProxyClassification(TrafficCategory.Proxy);
            }));
        Assert.AreEqual(
            new ProxyClassification(TrafficCategory.Proxy),
            sharedClassifier.Classify(["Synthetic"]));

        var fallbackClassifier = new ProxyClassifier(
            new ProxyCatalog(new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["Synthetic"] = "Selector",
            }),
            (LazyProxyTypeResolver)((_, nativeFallback) => nativeFallback()));
        Assert.AreEqual(
            new ProxyClassification(
                TrafficCategory.Unknown,
                UnknownTrafficReason.AmbiguousProxyType),
            fallbackClassifier.Classify(["Synthetic"]));
        CollectionAssert.AreEqual(new[] { "Selector" }, invocations);
    }
}
