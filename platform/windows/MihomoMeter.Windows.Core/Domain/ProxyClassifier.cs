namespace MihomoMeter.Windows.Core.Domain;

public sealed class ProxyCatalog
{
    private readonly IReadOnlyDictionary<string, string> _typesByName;

    public ProxyCatalog(IReadOnlyDictionary<string, string> typesByName)
    {
        _typesByName = new Dictionary<string, string>(typesByName, StringComparer.Ordinal);
    }

    public string? TypeFor(string name)
    {
        return _typesByName.TryGetValue(name, out var type) ? type : null;
    }
}

public sealed record ProxyClassification(
    TrafficCategory Category,
    UnknownTrafficReason? UnknownReason = null);

public enum UnknownTrafficReason
{
    EmptyChain,
    MissingCatalogEntry,
    AmbiguousProxyType,
}

public sealed class ProxyClassifier
{
    private static readonly HashSet<string> ConcreteProxyTypes = new(StringComparer.Ordinal)
    {
        "anytls",
        "http",
        "hysteria",
        "hysteria2",
        "shadowsocks",
        "shadowsocksr",
        "snell",
        "socks5",
        "ssh",
        "trojan",
        "tuic",
        "vless",
        "vmess",
        "wireguard",
    };

    private readonly ProxyCatalog _catalog;

    public ProxyClassifier(ProxyCatalog catalog)
    {
        _catalog = catalog;
    }

    public ProxyClassification Classify(IReadOnlyList<string> chains)
    {
        if (chains.Count == 0 || chains[0].Length == 0)
        {
            return new ProxyClassification(TrafficCategory.Unknown, UnknownTrafficReason.EmptyChain);
        }

        var rawType = _catalog.TypeFor(chains[0]);
        if (rawType is null)
        {
            return new ProxyClassification(
                TrafficCategory.Unknown,
                UnknownTrafficReason.MissingCatalogEntry);
        }

        var normalizedType = string.Concat(rawType
            .ToLowerInvariant()
            .Where(char.IsLetter));

        return normalizedType switch
        {
            "direct" => new ProxyClassification(TrafficCategory.Direct),
            "reject" or "rejectdrop" => new ProxyClassification(TrafficCategory.Reject),
            _ when ConcreteProxyTypes.Contains(normalizedType) =>
                new ProxyClassification(TrafficCategory.Proxy),
            _ => new ProxyClassification(
                TrafficCategory.Unknown,
                UnknownTrafficReason.AmbiguousProxyType),
        };
    }
}
