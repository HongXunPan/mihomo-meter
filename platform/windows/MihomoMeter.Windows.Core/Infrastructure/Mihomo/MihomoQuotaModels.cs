using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

public sealed record MihomoProxyProvidersResponse
{
    [JsonPropertyName("providers")]
    public required Dictionary<string, MihomoProxyProviderResponse> Providers { get; init; }

    public RuntimeQuotaCandidateSelection ToRuntimeSelection()
    {
        var candidates = Providers
            .Select(item => item.Value.ToCandidate(item.Key))
            .Where(candidate => candidate is not null)
            .Cast<RuntimeQuotaCandidate>()
            .ToArray();
        return RuntimeQuotaCandidateSelection.From(candidates);
    }
}

public sealed record MihomoProxyProviderResponse
{
    [JsonPropertyName("updatedAt")]
    public string? UpdatedAt { get; init; }

    [JsonPropertyName("subscriptionInfo")]
    public JsonElement? SubscriptionInfo { get; init; }

    internal RuntimeQuotaCandidate? ToCandidate(string sourceKey)
    {
        var normalizedKey = sourceKey.Trim();
        if (normalizedKey.Length == 0
            || SubscriptionInfo is not JsonElement value
            || !TryReadSubscriptionInfo(value, out var info))
        {
            return null;
        }

        try
        {
            var traffic = new QuotaTraffic(
                checked((ulong)info.Upload),
                checked((ulong)info.Download),
                checked((ulong)info.Total));
            return new RuntimeQuotaCandidate(
                normalizedKey,
                ParseDate(UpdatedAt),
                traffic,
                info.Expire is > 0
                    ? DateTimeOffset.FromUnixTimeSeconds(
                        info.Expire.Value)
                    : null);
        }
        catch (Exception exception) when (
            exception is QuotaDomainException
                or OverflowException
                or ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    private static bool TryReadSubscriptionInfo(
        JsonElement value,
        out MihomoSubscriptionInfoResponse info)
    {
        info = default;
        if (value.ValueKind != JsonValueKind.Object
            || !TryReadInteger(value, "Upload", "upload", out var upload)
            || !TryReadInteger(value, "Download", "download", out var download)
            || !TryReadInteger(value, "Total", "total", out var total)
            || upload < 0
            || download < 0
            || total <= 0)
        {
            return false;
        }

        _ = TryReadInteger(value, "Expire", "expire", out var expire);
        info = new MihomoSubscriptionInfoResponse(upload, download, total, expire);
        return true;
    }

    private static bool TryReadInteger(
        JsonElement value,
        string primaryName,
        string fallbackName,
        out long result)
    {
        result = 0;
        return ((value.TryGetProperty(primaryName, out var property)
                    || value.TryGetProperty(fallbackName, out property))
                && property.ValueKind == JsonValueKind.Number
                && property.TryGetInt64(out result));
    }

    private static DateTimeOffset? ParseDate(string? value)
    {
        return DateTimeOffset.TryParse(
            value,
            CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
            out var result)
            ? result
            : null;
    }
}

internal readonly record struct MihomoSubscriptionInfoResponse(
    long Upload,
    long Download,
    long Total,
    long? Expire);

public sealed record MihomoQuotaConfigurationResponse
{
    [JsonPropertyName("mixed-port")]
    public int MixedPort { get; init; }

    [JsonPropertyName("port")]
    public int HttpPort { get; init; }

    [JsonPropertyName("socks-port")]
    public int SocksPort { get; init; }

    [JsonPropertyName("global-ua")]
    public string? GlobalUserAgent { get; init; }

    public MihomoQuotaRuntimeConfiguration ToRuntimeConfiguration()
    {
        var proxy = Proxy(MihomoLocalProxyKind.Mixed, MixedPort)
            ?? Proxy(MihomoLocalProxyKind.Http, HttpPort)
            ?? Proxy(MihomoLocalProxyKind.Socks, SocksPort);
        var normalizedUserAgent = GlobalUserAgent?.Trim();
        var usesConfiguredUserAgent = !string.IsNullOrEmpty(normalizedUserAgent)
            && normalizedUserAgent.All(character => !char.IsControl(character));
        return new MihomoQuotaRuntimeConfiguration(
            proxy,
            usesConfiguredUserAgent ? normalizedUserAgent! : "clash.meta",
            usesConfiguredUserAgent);
    }

    private static MihomoLocalProxy? Proxy(MihomoLocalProxyKind kind, int port)
    {
        return port is > 0 and <= 65_535
            ? new MihomoLocalProxy(kind, "127.0.0.1", port)
            : null;
    }
}
