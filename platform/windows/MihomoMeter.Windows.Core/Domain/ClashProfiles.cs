namespace MihomoMeter.Windows.Core.Domain;

public sealed record ClashProfile
{
    public ClashProfile(string uid, string name, Uri subscriptionUri)
    {
        Uid = uid.Trim();
        Name = name.Trim();
        var isSupportedScheme = string.Equals(
                subscriptionUri.Scheme,
                Uri.UriSchemeHttp,
                StringComparison.OrdinalIgnoreCase)
            || string.Equals(
                subscriptionUri.Scheme,
                Uri.UriSchemeHttps,
                StringComparison.OrdinalIgnoreCase);
        if (Uid.Length == 0
            || Name.Length == 0
            || !subscriptionUri.IsAbsoluteUri
            || !isSupportedScheme
            || string.IsNullOrWhiteSpace(subscriptionUri.Host))
        {
            throw new QuotaDomainException("Profile 身份数据无效。");
        }

        SubscriptionUri = subscriptionUri;
    }

    public string Uid { get; }

    public string Name { get; }

    public Uri SubscriptionUri { get; }

    public bool SupportsActiveQuery => string.Equals(
        SubscriptionUri.Scheme,
        Uri.UriSchemeHttps,
        StringComparison.OrdinalIgnoreCase);

    public override string ToString() => Name;
}

public sealed record ClashProfileCatalog(
    string? CurrentUid,
    IReadOnlyList<ClashProfile> Profiles,
    int IgnoredRemoteProfileCount)
{
    public ClashProfile? CurrentProfile => Profiles.FirstOrDefault(
        profile => string.Equals(profile.Uid, CurrentUid, StringComparison.Ordinal));

    public static ClashProfileCatalog Empty { get; } = new(
        null,
        Array.Empty<ClashProfile>(),
        0);
}

public enum MihomoLocalProxyKind
{
    Mixed,
    Http,
    Socks,
}

public sealed record MihomoLocalProxy(MihomoLocalProxyKind Kind, string Host, int Port)
{
    public Uri ProxyUri => new(
        Kind == MihomoLocalProxyKind.Socks
            ? $"socks5://{Host}:{Port}"
            : $"http://{Host}:{Port}");
}

public sealed record MihomoQuotaRuntimeConfiguration(
    MihomoLocalProxy? Proxy,
    string UserAgent,
    bool UsesConfiguredUserAgent);
