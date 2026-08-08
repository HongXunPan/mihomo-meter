using System.Net;
using System.Net.Http.Headers;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

public interface IMihomoControllerClient
{
    Task<MihomoVersionResponse> FetchVersionAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);

    Task<MihomoProxiesResponse> FetchProxiesAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);

    Task<MihomoProcessConfigurationResponse> FetchProcessConfigurationAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);
}

public interface IMihomoQuotaControllerClient
{
    Task<MihomoProxyProvidersResponse> FetchProxyProvidersAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);

    Task<MihomoQuotaConfigurationResponse> FetchQuotaConfigurationAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);
}

public sealed class MihomoControllerClient : IMihomoControllerClient, IMihomoQuotaControllerClient
{
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(5);
    private readonly HttpClient _httpClient;

    public MihomoControllerClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public Task<MihomoVersionResponse> FetchVersionAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return GetAsync<MihomoVersionResponse>(
            endpoint.HttpUri("/version"),
            secret,
            cancellationToken);
    }

    public Task<MihomoProxiesResponse> FetchProxiesAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return GetAsync<MihomoProxiesResponse>(
            endpoint.HttpUri("/proxies"),
            secret,
            cancellationToken);
    }

    public Task<MihomoProcessConfigurationResponse> FetchProcessConfigurationAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return GetAsync<MihomoProcessConfigurationResponse>(
            endpoint.HttpUri("/configs"),
            secret,
            cancellationToken);
    }

    public Task<MihomoProxyProvidersResponse> FetchProxyProvidersAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return GetAsync<MihomoProxyProvidersResponse>(
            endpoint.HttpUri("/providers/proxies"),
            secret,
            cancellationToken);
    }

    public Task<MihomoQuotaConfigurationResponse> FetchQuotaConfigurationAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        return GetAsync<MihomoQuotaConfigurationResponse>(
            endpoint.HttpUri("/configs"),
            secret,
            cancellationToken);
    }

    private async Task<T> GetAsync<T>(
        Uri uri,
        string secret,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        if (secret.Length > 0)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", secret);
        }

        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(RequestTimeout);

        try
        {
            using var response = await _httpClient
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeoutSource.Token)
                .ConfigureAwait(false);

            if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            {
                throw new MihomoControllerException(MihomoControllerError.AuthenticationFailed);
            }

            if (!response.IsSuccessStatusCode)
            {
                throw new MihomoControllerException(
                    MihomoControllerError.HttpStatus,
                    (int)response.StatusCode);
            }

            var data = await response.Content
                .ReadAsByteArrayAsync(timeoutSource.Token)
                .ConfigureAwait(false);
            try
            {
                return MihomoJsonDecoder.Decode<T>(data);
            }
            catch (MihomoResponseException exception)
            {
                throw new MihomoControllerException(
                    MihomoControllerError.UnsupportedResponse,
                    innerException: exception);
            }
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new MihomoControllerException(MihomoControllerError.Timeout);
        }
        catch (HttpRequestException exception)
        {
            throw new MihomoControllerException(
                MihomoControllerError.Network,
                innerException: exception);
        }
    }
}

public enum MihomoControllerError
{
    AuthenticationFailed,
    HttpStatus,
    UnsupportedResponse,
    Network,
    Timeout,
}

public sealed class MihomoControllerException : Exception
{
    public MihomoControllerException(
        MihomoControllerError reason,
        int? statusCode = null,
        Exception? innerException = null)
        : base(MessageFor(reason, statusCode), innerException)
    {
        Reason = reason;
        StatusCode = statusCode;
    }

    public MihomoControllerError Reason { get; }

    public int? StatusCode { get; }

    private static string MessageFor(MihomoControllerError reason, int? statusCode)
    {
        return reason switch
        {
            MihomoControllerError.AuthenticationFailed => "鉴权失败，请检查访问密钥。",
            MihomoControllerError.HttpStatus => $"Mihomo 服务返回异常状态（HTTP {statusCode}）。",
            MihomoControllerError.UnsupportedResponse => "当前 Mihomo 响应结构暂不受支持。",
            MihomoControllerError.Timeout => "连接 Mihomo 服务超时。",
            MihomoControllerError.Network => "无法连接 Mihomo 服务，请检查地址和 Mihomo 状态。",
            _ => "Mihomo 服务通信失败。",
        };
    }
}
