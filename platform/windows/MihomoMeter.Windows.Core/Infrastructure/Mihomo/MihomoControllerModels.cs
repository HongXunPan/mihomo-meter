using System.Text.Json;
using System.Text.Json.Serialization;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

public sealed record MihomoVersionResponse
{
    [JsonPropertyName("meta")]
    public required bool Meta { get; init; }

    [JsonPropertyName("version")]
    public required string Version { get; init; }
}

public sealed record MihomoProxiesResponse
{
    [JsonPropertyName("proxies")]
    public required Dictionary<string, MihomoProxyResponse> Proxies { get; init; }

    public ProxyCatalog ToCatalog()
    {
        return new ProxyCatalog(Proxies.ToDictionary(
            item => item.Key,
            item => item.Value.Type,
            StringComparer.Ordinal));
    }
}

public sealed record MihomoProxyResponse
{
    [JsonPropertyName("name")]
    public required string Name { get; init; }

    [JsonPropertyName("type")]
    public required string Type { get; init; }
}

public sealed record MihomoConnectionsSnapshot
{
    [JsonPropertyName("downloadTotal")]
    public required ulong DownloadTotal { get; init; }

    [JsonPropertyName("uploadTotal")]
    public required ulong UploadTotal { get; init; }

    [JsonPropertyName("connections")]
    public required List<MihomoConnectionResponse> Connections { get; init; }

    public ConnectionTrafficSnapshot ToTrafficSnapshot()
    {
        return new ConnectionTrafficSnapshot(
            new TrafficBytes(UploadTotal, DownloadTotal),
            Connections.Select(connection => new ConnectionTrafficSample(
                connection.Id,
                new TrafficBytes(connection.Upload, connection.Download),
                connection.Chains,
                connection.MetadataAvailability)).ToArray());
    }
}

public sealed record MihomoConnectionResponse
{
    [JsonPropertyName("id")]
    public required string Id { get; init; }

    [JsonPropertyName("upload")]
    public required ulong Upload { get; init; }

    [JsonPropertyName("download")]
    public required ulong Download { get; init; }

    [JsonPropertyName("chains")]
    public required List<string> Chains { get; init; }

    [JsonPropertyName("metadata")]
    [JsonConverter(typeof(ConnectionMetadataAvailabilityJsonConverter))]
    public ConnectionMetadataAvailability MetadataAvailability { get; init; } =
        ConnectionMetadataAvailability.Unavailable;
}

public static class MihomoJsonDecoder
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = false,
    };

    public static T Decode<T>(ReadOnlySpan<byte> data)
    {
        try
        {
            var response = JsonSerializer.Deserialize<T>(data, Options)
                ?? throw new MihomoResponseException();
            if (!IsValidResponse(response))
            {
                throw new MihomoResponseException();
            }

            return response;
        }
        catch (JsonException exception)
        {
            throw new MihomoResponseException(exception);
        }
        catch (NotSupportedException exception)
        {
            throw new MihomoResponseException(exception);
        }
    }

    private static bool IsValidResponse<T>(T response)
    {
        return response switch
        {
            MihomoVersionResponse version => !string.IsNullOrWhiteSpace(version.Version),
            MihomoProxiesResponse proxies => IsValidProxies(proxies),
            MihomoConnectionsSnapshot connections => IsValidConnections(connections),
            MihomoProxyProvidersResponse providers => providers.Providers is not null
                && providers.Providers.All(item => item.Value is not null),
            _ => true,
        };
    }

    private static bool IsValidProxies(MihomoProxiesResponse response)
    {
        return response.Proxies is not null
            && response.Proxies.All(item =>
                !string.IsNullOrEmpty(item.Key)
                && item.Value is not null
                && !string.IsNullOrWhiteSpace(item.Value.Name)
                && !string.IsNullOrWhiteSpace(item.Value.Type));
    }

    private static bool IsValidConnections(MihomoConnectionsSnapshot response)
    {
        if (response.Connections is null)
        {
            return false;
        }

        var identifiers = new HashSet<string>(StringComparer.Ordinal);
        return response.Connections.All(connection =>
            connection is not null
            && !string.IsNullOrWhiteSpace(connection.Id)
            && connection.Chains is not null
            && connection.Chains.All(chain => chain is not null)
            && identifiers.Add(connection.Id));
    }
}

public sealed class MihomoResponseException : Exception
{
    public MihomoResponseException()
        : base("当前 Mihomo 响应结构暂不受支持。")
    {
    }

    public MihomoResponseException(Exception innerException)
        : base("当前 Mihomo 响应结构暂不受支持。", innerException)
    {
    }
}
