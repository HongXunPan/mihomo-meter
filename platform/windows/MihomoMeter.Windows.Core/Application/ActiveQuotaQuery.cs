using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public interface IActiveQuotaQueryClient
{
    Task<ActiveQuotaQueryResult> QueryAsync(
        Uri subscriptionUri,
        MihomoLocalProxy proxy,
        string userAgent,
        CancellationToken cancellationToken);
}

public static class SubscriptionUserInfoParser
{
    public static ActiveQuotaQueryResult Parse(string headerValue)
    {
        var values = new Dictionary<string, ulong>(StringComparer.OrdinalIgnoreCase);
        foreach (var field in headerValue.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = field.Split('=', 2, StringSplitOptions.TrimEntries);
            if (parts.Length != 2
                || parts[0].Length == 0
                || !double.TryParse(
                    parts[1],
                    System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture,
                    out var number)
                || !double.IsFinite(number)
                || number < 0
                || number > long.MaxValue)
            {
                continue;
            }

            values[parts[0]] = checked((ulong)Math.Truncate(number));
        }

        if (!values.TryGetValue("upload", out var upload)
            || !values.TryGetValue("download", out var download)
            || !values.TryGetValue("total", out var total))
        {
            throw new ActiveQuotaQueryException(
                ActiveQuotaQueryFailureCategory.InvalidHeader);
        }

        try
        {
            return new ActiveQuotaQueryResult(
                new QuotaTraffic(upload, download, total),
                values.TryGetValue("expire", out var expire) && expire > 0
                    ? DateTimeOffset.FromUnixTimeSeconds(checked((long)expire))
                    : null);
        }
        catch (Exception exception) when (
            exception is QuotaDomainException
                or OverflowException
                or ArgumentOutOfRangeException)
        {
            throw new ActiveQuotaQueryException(
                ActiveQuotaQueryFailureCategory.InvalidHeader);
        }
    }
}
