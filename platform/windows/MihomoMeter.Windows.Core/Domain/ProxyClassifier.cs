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

public delegate ProxyClassification LazyProxyTypeResolver(
    string rawType,
    Func<ProxyClassification> nativeFallback);

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
    private readonly Func<string, ProxyClassification, ProxyClassification>? _resolveProxyType;
    private readonly LazyProxyTypeResolver? _resolveProxyTypeLazily;

    public ProxyClassifier(
        ProxyCatalog catalog,
        Func<string, ProxyClassification, ProxyClassification>? resolveProxyType = null)
    {
        _catalog = catalog;
        _resolveProxyType = resolveProxyType ?? ((_, nativeClassification) =>
            nativeClassification);
    }

    public ProxyClassifier(
        ProxyCatalog catalog,
        LazyProxyTypeResolver resolveProxyTypeLazily)
    {
        _catalog = catalog;
        _resolveProxyTypeLazily = resolveProxyTypeLazily;
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

        if (_resolveProxyTypeLazily is not null)
        {
            return _resolveProxyTypeLazily(rawType, () => ClassifyNatively(rawType));
        }

        var nativeClassification = ClassifyNatively(rawType);
        return _resolveProxyType!(rawType, nativeClassification);
    }

    private static ProxyClassification ClassifyNatively(string rawType)
    {
        var normalizedType = string.Concat(rawType
            .ToLowerInvariant()
            .Where(character => char.IsLetter(character) || char.IsNumber(character)));

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
