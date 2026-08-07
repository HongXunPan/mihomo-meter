using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Statistics.TrafficLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal sealed class TrafficIntervalPersistence
{
    private readonly SqliteConnection _connection;

    public TrafficIntervalPersistence(SqliteConnection connection)
    {
        _connection = connection;
    }

    public IReadOnlyList<TrafficInterval> Load(TrafficBytes currentProxyTotal)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, name, note, status, started_at, ended_at, end_reason,
                   start_proxy_upload, start_proxy_download,
                   end_proxy_upload, end_proxy_download
            FROM traffic_intervals
            ORDER BY CASE status WHEN 'active' THEN 0 ELSE 1 END,
                     CASE WHEN status = 'active' THEN started_at END DESC,
                     CASE WHEN status <> 'active' THEN ended_at END DESC,
                     started_at DESC
            """;
        using var reader = command.ExecuteReader();
        var intervals = new List<TrafficInterval>();
        while (reader.Read())
        {
            intervals.Add(ReadInterval(reader, currentProxyTotal));
        }

        return intervals;
    }

    public void Insert(
        Guid id,
        string name,
        string? note,
        DateTimeOffset startedAt,
        TrafficBytes baseline,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO traffic_intervals(
              id, name, note, status, started_at,
              start_proxy_upload, start_proxy_download
            ) VALUES ($id, $name, $note, 'active', $started, $upload, $download)
            """;
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        command.Parameters.AddWithValue("$name", name);
        command.Parameters.AddWithValue("$note", (object?)note ?? DBNull.Value);
        command.Parameters.AddWithValue("$started", startedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$upload", ToSqliteInteger(baseline.Upload));
        command.Parameters.AddWithValue("$download", ToSqliteInteger(baseline.Download));
        command.ExecuteNonQuery();
    }

    public void Complete(
        Guid id,
        DateTimeOffset endedAt,
        TrafficBytes baseline,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE traffic_intervals
            SET status = 'completed', ended_at = $ended, end_reason = 'user',
                end_proxy_upload = $upload, end_proxy_download = $download
            WHERE id = $id AND status = 'active'
            """;
        command.Parameters.AddWithValue("$ended", endedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$upload", ToSqliteInteger(baseline.Upload));
        command.Parameters.AddWithValue("$download", ToSqliteInteger(baseline.Download));
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        if (command.ExecuteNonQuery() != 1)
        {
            throw new TrafficIntervalOperationException("统计任务不存在或已经结束。");
        }
    }

    public void Rename(Guid id, string name, SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "UPDATE traffic_intervals SET name = $name WHERE id = $id";
        command.Parameters.AddWithValue("$name", name);
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        command.ExecuteNonQuery();
    }

    public void Delete(Guid id, SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "DELETE FROM traffic_intervals WHERE id = $id";
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        command.ExecuteNonQuery();
    }

    public void InterruptActive(
        DateTimeOffset endedAt,
        TrafficBytes baseline,
        TrafficIntervalEndReason reason,
        SqliteTransaction transaction)
    {
        if (reason == TrafficIntervalEndReason.User)
        {
            throw new TrafficIntervalOperationException("用户停止必须指定单个统计任务。");
        }

        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE traffic_intervals
            SET status = 'interrupted',
                ended_at = CASE WHEN started_at > $ended THEN started_at ELSE $ended END,
                end_reason = $reason,
                end_proxy_upload = $upload,
                end_proxy_download = $download
            WHERE status = 'active'
            """;
        command.Parameters.AddWithValue("$ended", endedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$reason", EndReasonName(reason));
        command.Parameters.AddWithValue("$upload", ToSqliteInteger(baseline.Upload));
        command.Parameters.AddWithValue("$download", ToSqliteInteger(baseline.Download));
        command.ExecuteNonQuery();
    }

    private static TrafficInterval ReadInterval(
        SqliteDataReader reader,
        TrafficBytes currentProxyTotal)
    {
        if (!Guid.TryParse(reader.GetString(0), out var id))
        {
            throw new TrafficStatisticsException("统计任务标识无效。");
        }

        var status = ParseStatus(reader.GetString(3));
        var name = reader.GetString(1);
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new TrafficStatisticsException("统计任务名称无效。");
        }

        var startBaseline = ReadBytes(reader, 7, 8);
        var endedAt = reader.IsDBNull(5)
            ? null
            : DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(5));
        var endReason = reader.IsDBNull(6)
            ? null
            : ParseEndReason(reader.GetString(6));
        var hasEndBaseline = !reader.IsDBNull(9) && !reader.IsDBNull(10);
        var endBaseline = hasEndBaseline ? ReadBytes(reader, 9, 10) : (TrafficBytes?)null;
        if (status == TrafficIntervalStatus.Active
            ? endedAt is not null || endReason is not null || endBaseline is not null
            : endedAt is null || endReason is null || endBaseline is null)
        {
            throw new TrafficStatisticsException("统计任务结束字段不完整。");
        }

        if ((status == TrafficIntervalStatus.Completed
                && endReason != TrafficIntervalEndReason.User)
            || (status == TrafficIntervalStatus.Interrupted
                && endReason == TrafficIntervalEndReason.User))
        {
            throw new TrafficStatisticsException("统计任务状态与结束原因不一致。");
        }

        var effectiveEnd = endBaseline ?? currentProxyTotal;
        var usage = TrafficBytes.NonnegativeDelta(effectiveEnd, startBaseline)
            ?? throw new TrafficStatisticsException("统计任务累计基线无效。");
        return new TrafficInterval(
            id,
            name,
            reader.IsDBNull(2) ? null : reader.GetString(2),
            status,
            DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(4)),
            endedAt,
            endReason,
            usage);
    }

    private static TrafficBytes ReadBytes(SqliteDataReader reader, int upload, int download)
    {
        return new TrafficBytes(
            checked((ulong)reader.GetInt64(upload)),
            checked((ulong)reader.GetInt64(download)));
    }

    private static TrafficIntervalStatus ParseStatus(string value)
    {
        return value switch
        {
            "active" => TrafficIntervalStatus.Active,
            "completed" => TrafficIntervalStatus.Completed,
            "interrupted" => TrafficIntervalStatus.Interrupted,
            _ => throw new TrafficStatisticsException("统计任务状态无效。"),
        };
    }

    private static TrafficIntervalEndReason ParseEndReason(string value)
    {
        return value switch
        {
            "user" => TrafficIntervalEndReason.User,
            "application_exit" => TrafficIntervalEndReason.ApplicationExit,
            "monitoring_stopped" => TrafficIntervalEndReason.MonitoringStopped,
            "recovery" => TrafficIntervalEndReason.Recovery,
            "statistics_unavailable" => TrafficIntervalEndReason.StatisticsUnavailable,
            _ => throw new TrafficStatisticsException("统计任务结束原因无效。"),
        };
    }

    private static string EndReasonName(TrafficIntervalEndReason reason)
    {
        return reason switch
        {
            TrafficIntervalEndReason.User => "user",
            TrafficIntervalEndReason.ApplicationExit => "application_exit",
            TrafficIntervalEndReason.MonitoringStopped => "monitoring_stopped",
            TrafficIntervalEndReason.Recovery => "recovery",
            TrafficIntervalEndReason.StatisticsUnavailable => "statistics_unavailable",
            _ => throw new TrafficStatisticsException("统计任务结束原因无效。"),
        };
    }
}
