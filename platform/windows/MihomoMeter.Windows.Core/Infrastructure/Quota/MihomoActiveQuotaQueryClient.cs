using System.Net;
using System.Net.Http.Headers;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

public sealed class MihomoActiveQuotaQueryClient : IActiveQuotaQueryClient
{
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(15);
    private const int MaximumRedirects = 5;

    public async Task<ActiveQuotaQueryResult> QueryAsync(
        Uri subscriptionUri,
        MihomoLocalProxy proxy,
        string userAgent,
        CancellationToken cancellationToken)
    {
        EnsureHttps(subscriptionUri, ActiveQuotaQueryFailureCategory.InsecureUrl);
        using var handler = CreateHandler(proxy);
        using var client = new HttpClient(handler, disposeHandler: false);
        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(RequestTimeout);
        var current = subscriptionUri;
        try
        {
            for (var redirect = 0; redirect <= MaximumRedirects; redirect += 1)
            {
                using var request = new HttpRequestMessage(HttpMethod.Get, current);
                request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("*/*"));
                _ = request.Headers.TryAddWithoutValidation("User-Agent", userAgent);
                using var response = await client
                    .SendAsync(
                        request,
                        HttpCompletionOption.ResponseHeadersRead,
                        timeoutSource.Token)
                    .ConfigureAwait(false);
                if (IsRedirect(response.StatusCode))
                {
                    if (redirect == MaximumRedirects || response.Headers.Location is null)
                    {
                        throw new ActiveQuotaQueryException(
                            ActiveQuotaQueryFailureCategory.InsecureRedirect);
                    }

                    current = response.Headers.Location.IsAbsoluteUri
                        ? response.Headers.Location
                        : new Uri(current, response.Headers.Location);
                    EnsureHttps(
                        current,
                        ActiveQuotaQueryFailureCategory.InsecureRedirect);
                    continue;
                }

                if (!response.IsSuccessStatusCode)
                {
                    throw new ActiveQuotaQueryException(
                        ActiveQuotaQueryFailureCategory.HttpStatus,
                        (int)response.StatusCode);
                }

                var value = Header(response)
                    ?? throw new ActiveQuotaQueryException(
                        ActiveQuotaQueryFailureCategory.MissingHeader,
                        (int)response.StatusCode);
                return SubscriptionUserInfoParser.Parse(value);
            }
        }
        catch (ActiveQuotaQueryException)
        {
            throw;
        }
        catch (OperationCanceledException) when (
            !cancellationToken.IsCancellationRequested)
        {
            throw new ActiveQuotaQueryException(ActiveQuotaQueryFailureCategory.Timeout);
        }
        catch (HttpRequestException)
        {
            throw new ActiveQuotaQueryException(ActiveQuotaQueryFailureCategory.Network);
        }
        catch (FormatException)
        {
            throw new ActiveQuotaQueryException(
                ActiveQuotaQueryFailureCategory.InvalidHeader);
        }

        throw new ActiveQuotaQueryException(
            ActiveQuotaQueryFailureCategory.InsecureRedirect);
    }

    internal static SocketsHttpHandler CreateHandler(MihomoLocalProxy proxy)
    {
        return new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            UseCookies = false,
            UseProxy = true,
            Proxy = new WebProxy(proxy.ProxyUri, bypassOnLocal: false),
            ConnectTimeout = RequestTimeout,
        };
    }

    internal static string? Header(HttpResponseMessage response)
    {
        if (response.Headers.TryGetValues("Subscription-Userinfo", out var standard))
        {
            return standard.FirstOrDefault();
        }

        return response.Headers
            .Where(header => header.Key.EndsWith(
                "-subscription-userinfo",
                StringComparison.OrdinalIgnoreCase))
            .OrderBy(header => header.Key, StringComparer.OrdinalIgnoreCase)
            .SelectMany(header => header.Value)
            .FirstOrDefault();
    }

    private static bool IsRedirect(HttpStatusCode statusCode)
    {
        return (int)statusCode is >= 300 and < 400;
    }

    internal static void EnsureHttps(
        Uri uri,
        ActiveQuotaQueryFailureCategory failureCategory)
    {
        if (!uri.IsAbsoluteUri
            || !string.Equals(
                uri.Scheme,
                Uri.UriSchemeHttps,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new ActiveQuotaQueryException(failureCategory);
        }
    }
}
