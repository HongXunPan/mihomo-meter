using System.Globalization;
using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Statistics.TrafficLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal sealed class TrafficDailyPersistence
{
    private const int RecentDayCount = 30;
    private readonly SqliteConnection _connection;

    public TrafficDailyPersistence(SqliteConnection connection)
    {
        _connection = connection;
    }

    public CategorizedTrafficBytes Totals(string? localDay = null)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = localDay is null
            ? "SELECT category, upload_bytes, download_bytes FROM traffic_daily_totals"
            : """
                SELECT category, upload_bytes, download_bytes
                FROM traffic_daily_totals WHERE local_day = $day
                """;
        if (localDay is not null)
        {
            command.Parameters.AddWithValue("$day", localDay);
        }

        var totals = CategorizedTrafficBytes.Zero;
        using var reader = command.ExecuteReader();
        while (reader.Read())
        {
            var category = ParseCategory(reader.GetString(0));
            var bytes = new TrafficBytes(
                checked((ulong)reader.GetInt64(1)),
                checked((ulong)reader.GetInt64(2)));
            var existing = BytesFor(totals, category);
            var nextUpload = checked(existing.Upload + bytes.Upload);
            var nextDownload = checked(existing.Download + bytes.Download);
            if (nextUpload > (ulong)long.MaxValue || nextDownload > (ulong)long.MaxValue)
            {
                throw new TrafficStatisticsException("本地统计字节累计超出支持范围。");
            }

            totals = totals with
            {
                Proxy = category == TrafficCategory.Proxy
                    ? new TrafficBytes(nextUpload, nextDownload)
                    : totals.Proxy,
                Direct = category == TrafficCategory.Direct
                    ? new TrafficBytes(nextUpload, nextDownload)
                    : totals.Direct,
                Reject = category == TrafficCategory.Reject
                    ? new TrafficBytes(nextUpload, nextDownload)
                    : totals.Reject,
                Unknown = category == TrafficCategory.Unknown
                    ? new TrafficBytes(nextUpload, nextDownload)
                    : totals.Unknown,
            };
        }

        return totals;
    }

    public IReadOnlyList<TrafficDailyTotal> RecentProxyDays(
        DateTimeOffset now,
        TimeZoneInfo timeZone)
    {
        var localDays = RecentLocalDays(now, timeZone);
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT local_day, upload_bytes, download_bytes
            FROM traffic_daily_totals
            WHERE category = $category
              AND local_day >= $start
              AND local_day <= $end
            ORDER BY local_day
            """;
        command.Parameters.AddWithValue("$category", CategoryName(TrafficCategory.Proxy));
        command.Parameters.AddWithValue("$start", localDays[0]);
        command.Parameters.AddWithValue("$end", localDays[^1]);
        using var reader = command.ExecuteReader();
        var stored = new Dictionary<string, TrafficBytes>(StringComparer.Ordinal);
        while (reader.Read())
        {
            stored.Add(
                reader.GetString(0),
                new TrafficBytes(
                    checked((ulong)reader.GetInt64(1)),
                    checked((ulong)reader.GetInt64(2))));
        }

        return localDays
            .Select(day => new TrafficDailyTotal(
                day,
                stored.GetValueOrDefault(day, TrafficBytes.Zero)))
            .ToArray();
    }

    public static IReadOnlyList<TrafficDailyTotal> EmptyRecentProxyDays(
        DateTimeOffset now,
        TimeZoneInfo timeZone)
    {
        return RecentLocalDays(now, timeZone)
            .Select(day => new TrafficDailyTotal(day, TrafficBytes.Zero))
            .ToArray();
    }

    public static string LocalDay(DateTimeOffset date, TimeZoneInfo timeZone)
    {
        return TimeZoneInfo
            .ConvertTime(date, timeZone)
            .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    }

    private static string[] RecentLocalDays(
        DateTimeOffset now,
        TimeZoneInfo timeZone)
    {
        var localToday = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(now, timeZone).Date);
        return Enumerable.Range(0, RecentDayCount)
            .Select(offset => localToday.AddDays(offset - RecentDayCount + 1)
                .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture))
            .ToArray();
    }
}
