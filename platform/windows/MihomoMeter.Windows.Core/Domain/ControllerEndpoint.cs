namespace MihomoMeter.Windows.Core.Domain;

public sealed class ControllerEndpoint
{
    public ControllerEndpoint(string address)
    {
        var trimmedAddress = address.Trim();
        if (trimmedAddress.Length == 0)
        {
            throw new ControllerEndpointException(ControllerEndpointError.EmptyAddress);
        }

        var addressWithScheme = trimmedAddress.Contains("://", StringComparison.Ordinal)
            ? trimmedAddress
            : $"http://{trimmedAddress}";

        if (!Uri.TryCreate(addressWithScheme, UriKind.Absolute, out var uri))
        {
            throw new ControllerEndpointException(ControllerEndpointError.InvalidAddress);
        }

        var scheme = uri.Scheme.ToLowerInvariant();
        if (scheme is not ("http" or "https"))
        {
            throw new ControllerEndpointException(ControllerEndpointError.UnsupportedScheme);
        }

        if (uri.UserInfo.Length > 0
            || addressWithScheme.Contains('@')
            || addressWithScheme.Contains('?')
            || addressWithScheme.Contains('#'))
        {
            throw new ControllerEndpointException(ControllerEndpointError.InvalidAddress);
        }

        var host = uri.Host.Trim('[', ']').ToLowerInvariant();
        if (host is not ("127.0.0.1" or "::1"))
        {
            throw new ControllerEndpointException(ControllerEndpointError.NonLoopbackAddress);
        }

        if (!HasExplicitPort(uri.Authority) || uri.Port is < 1 or > 65_535)
        {
            throw new ControllerEndpointException(ControllerEndpointError.MissingOrInvalidPort);
        }

        if (uri.AbsolutePath is not ("" or "/"))
        {
            throw new ControllerEndpointException(ControllerEndpointError.UnsupportedPath);
        }

        var displayHost = host == "::1" ? "[::1]" : host;
        NormalizedAddress = $"{scheme}://{displayHost}:{uri.Port}";
    }

    public string NormalizedAddress { get; }

    public Uri HttpUri(string path)
    {
        return BuildUri(path, NormalizedAddress.StartsWith("https://", StringComparison.Ordinal)
            ? "https"
            : "http");
    }

    public Uri WebSocketUri(string path, string? query = null)
    {
        var scheme = NormalizedAddress.StartsWith("https://", StringComparison.Ordinal)
            ? "wss"
            : "ws";
        var uri = BuildUri(path, scheme);
        if (string.IsNullOrEmpty(query))
        {
            return uri;
        }

        return new UriBuilder(uri) { Query = query }.Uri;
    }

    private static bool HasExplicitPort(string authority)
    {
        if (authority.StartsWith("[", StringComparison.Ordinal))
        {
            var bracketIndex = authority.IndexOf(']');
            return bracketIndex >= 0
                && bracketIndex + 2 < authority.Length
                && authority[bracketIndex + 1] == ':'
                && int.TryParse(authority[(bracketIndex + 2)..], out _);
        }

        var colonIndex = authority.LastIndexOf(':');
        return colonIndex > 0
            && colonIndex + 1 < authority.Length
            && int.TryParse(authority[(colonIndex + 1)..], out _);
    }

    private Uri BuildUri(string path, string scheme)
    {
        var source = new Uri(NormalizedAddress);
        var builder = new UriBuilder(source)
        {
            Scheme = scheme,
            Path = path.StartsWith('/') ? path : $"/{path}",
        };
        return builder.Uri;
    }
}

public enum ControllerEndpointError
{
    EmptyAddress,
    InvalidAddress,
    UnsupportedScheme,
    NonLoopbackAddress,
    MissingOrInvalidPort,
    UnsupportedPath,
}

public sealed class ControllerEndpointException : Exception
{
    public ControllerEndpointException(ControllerEndpointError reason)
        : base(MessageFor(reason))
    {
        Reason = reason;
    }

    public ControllerEndpointError Reason { get; }

    private static string MessageFor(ControllerEndpointError reason)
    {
        return reason switch
        {
            ControllerEndpointError.EmptyAddress => "请输入 Mihomo 服务地址。",
            ControllerEndpointError.InvalidAddress => "Mihomo 服务地址格式无效。",
            ControllerEndpointError.UnsupportedScheme => "Mihomo 服务地址只支持 HTTP 或 HTTPS。",
            ControllerEndpointError.NonLoopbackAddress => "Windows W1 只允许连接 127.0.0.1 或 ::1。",
            ControllerEndpointError.MissingOrInvalidPort => "Mihomo 服务地址必须包含有效端口。",
            ControllerEndpointError.UnsupportedPath => "Mihomo 服务地址不能包含额外路径。",
            _ => "Mihomo 服务地址无效。",
        };
    }
}
