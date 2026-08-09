using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

public sealed partial class SQLiteTrafficLedger : IProxyDailyTrafficProvider
{
    public async Task<TrafficBytes> ProxyTrafficAsync(
        string localDay,
        TimeZoneInfo timeZone,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            return PreparedPersistence(timeZone, now).Daily.Totals(localDay).Proxy;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (TrafficStatisticsException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is SqliteException
                or IOException
                or UnauthorizedAccessException
                or OverflowException
                or InvalidCastException
                or FormatException)
        {
            throw new TrafficStatisticsException("本地统计数据库暂不可用。", exception);
        }
        finally
        {
            _gate.Release();
        }
    }
}
