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
}
