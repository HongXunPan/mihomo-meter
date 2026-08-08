using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.ConnectionAnalytics;

internal sealed partial class ConnectionAnalyticsLedgerPersistence
{
    public IReadOnlyList<ConnectionAnalyticsDay> DailyTotals(string cutoffLocalDay)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT local_day,
                   SUM(upload_bytes), SUM(download_bytes),
                   SUM(CASE WHEN hostname != $unknownHostname THEN upload_bytes ELSE 0 END),
                   SUM(CASE WHEN hostname != $unknownHostname THEN download_bytes ELSE 0 END),
                   SUM(CASE WHEN application_name != $unknownApplication
                            THEN upload_bytes ELSE 0 END),
                   SUM(CASE WHEN application_name != $unknownApplication
                            THEN download_bytes ELSE 0 END),
                   SUM(CASE WHEN hostname != $unknownHostname
                                 AND application_name != $unknownApplication
                            THEN upload_bytes ELSE 0 END),
                   SUM(CASE WHEN hostname != $unknownHostname
                                 AND application_name != $unknownApplication
                            THEN download_bytes ELSE 0 END)
            FROM connection_daily_attribution
            WHERE local_day >= $cutoff
            GROUP BY local_day
            ORDER BY local_day
            """;
        command.Parameters.AddWithValue(
            "$unknownHostname",
            ConnectionAttributionLabel.UnknownHostname);
        command.Parameters.AddWithValue(
            "$unknownApplication",
            ConnectionAttributionLabel.UnknownApplication);
        command.Parameters.AddWithValue("$cutoff", cutoffLocalDay);
        using var reader = command.ExecuteReader();
        var days = new List<ConnectionAnalyticsDay>();
        while (reader.Read())
        {
            var total = ReadBytes(reader, 1, 2);
            days.Add(new ConnectionAnalyticsDay(
                reader.GetString(0),
                total,
                new ConnectionAnalyticsCoverage(
                    total,
                    ReadBytes(reader, 3, 4),
                    ReadBytes(reader, 5, 6),
                    ReadBytes(reader, 7, 8))));
        }
        return days;
    }

    public IReadOnlyList<ConnectionAttributionRecord> Records(string localDay)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT application_name, hostname, upload_bytes, download_bytes
            FROM connection_daily_attribution
            WHERE local_day = $day
            ORDER BY upload_bytes + download_bytes DESC, application_name, hostname
            """;
        command.Parameters.AddWithValue("$day", localDay);
        using var reader = command.ExecuteReader();
        var records = new List<ConnectionAttributionRecord>();
        while (reader.Read())
        {
            records.Add(new ConnectionAttributionRecord(
                localDay,
                reader.GetString(0),
                reader.GetString(1),
                ReadBytes(reader, 2, 3)));
        }
        return records;
    }

    public IReadOnlyList<ConnectionAnalyticsTrendPoint> Trend(
        ConnectionAnalyticsTrendQuery query,
        string cutoffLocalDay)
    {
        var conditions = new List<string> { "local_day >= $cutoff" };
        if (query.ApplicationName is not null)
        {
            conditions.Add("application_name = $application");
        }
        if (query.Hostname is not null)
        {
            conditions.Add("hostname = $hostname");
        }

        using var command = _connection.CreateCommand();
        command.CommandText = $"""
            SELECT local_day, SUM(upload_bytes), SUM(download_bytes)
            FROM connection_daily_attribution
            WHERE {string.Join(" AND ", conditions)}
            GROUP BY local_day
            ORDER BY local_day
            """;
        command.Parameters.AddWithValue("$cutoff", cutoffLocalDay);
        if (query.ApplicationName is not null)
        {
            command.Parameters.AddWithValue("$application", query.ApplicationName);
        }
        if (query.Hostname is not null)
        {
            command.Parameters.AddWithValue("$hostname", query.Hostname);
        }

        using var reader = command.ExecuteReader();
        var points = new List<ConnectionAnalyticsTrendPoint>();
        while (reader.Read())
        {
            points.Add(new ConnectionAnalyticsTrendPoint(
                reader.GetString(0),
                ReadBytes(reader, 1, 2)));
        }
        return points;
    }
}
