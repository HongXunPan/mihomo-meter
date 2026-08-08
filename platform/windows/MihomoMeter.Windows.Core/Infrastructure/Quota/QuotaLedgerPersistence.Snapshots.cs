using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Quota.QuotaLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal sealed partial class QuotaLedgerPersistence
{
    public SubscriptionQuotaSnapshot? LatestSnapshot(Guid subscriptionId)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = SnapshotSelect + "\n" + """
            WHERE subscription_id = $subscription
            ORDER BY observed_at DESC LIMIT 1
            """;
        command.Parameters.AddWithValue("$subscription", subscriptionId.ToString("D"));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadSnapshot(reader) : null;
    }

    public IReadOnlyList<SubscriptionQuotaSnapshot> LoadSnapshots(
        Guid subscriptionId,
        DateTimeOffset start,
        DateTimeOffset end)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = SnapshotSelect + "\n" + """
            WHERE subscription_id = $subscription
              AND COALESCE(source_updated_at, observed_at) >= $start
              AND COALESCE(source_updated_at, observed_at) <= $end
            ORDER BY COALESCE(source_updated_at, observed_at), observed_at
            """;
        command.Parameters.AddWithValue("$subscription", subscriptionId.ToString("D"));
        command.Parameters.AddWithValue("$start", start.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$end", end.ToUnixTimeMilliseconds());
        using var reader = command.ExecuteReader();
        var snapshots = new List<SubscriptionQuotaSnapshot>();
        while (reader.Read())
        {
            snapshots.Add(ReadSnapshot(reader));
        }

        return snapshots;
    }

    public SubscriptionQuotaSnapshot InsertObservation(
        QuotaObservation observation,
        Guid cycleId,
        SqliteTransaction transaction)
    {
        var snapshot = new SubscriptionQuotaSnapshot(
            Guid.NewGuid(),
            observation.SubscriptionId,
            cycleId,
            observation.ObservedAt,
            observation.SourceUpdatedAt,
            observation.Source,
            observation.Traffic,
            observation.ExpireAt);
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO quota_snapshots(
              id, subscription_id, cycle_id, observed_at, source_updated_at, source,
              upload_bytes, download_bytes, total_bytes, used_bytes, remaining_bytes, expire_at)
            VALUES(
              $id, $subscription, $cycle, $observed, $source_updated, $source,
              $upload, $download, $total, $used, $remaining, $expire)
            """;
        command.Parameters.AddWithValue("$id", snapshot.Id.ToString("D"));
        command.Parameters.AddWithValue("$subscription", snapshot.SubscriptionId.ToString("D"));
        command.Parameters.AddWithValue("$cycle", snapshot.CycleId.ToString("D"));
        command.Parameters.AddWithValue("$observed", snapshot.ObservedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue(
            "$source_updated",
            (object?)snapshot.SourceUpdatedAt?.ToUnixTimeMilliseconds() ?? DBNull.Value);
        command.Parameters.AddWithValue("$source", Source(snapshot.Source));
        command.Parameters.AddWithValue("$upload", Bytes(snapshot.Traffic.UploadBytes));
        command.Parameters.AddWithValue("$download", Bytes(snapshot.Traffic.DownloadBytes));
        command.Parameters.AddWithValue("$total", Bytes(snapshot.Traffic.TotalBytes));
        command.Parameters.AddWithValue("$used", Bytes(snapshot.Traffic.UsedBytes));
        command.Parameters.AddWithValue("$remaining", Bytes(snapshot.Traffic.RemainingBytes));
        command.Parameters.AddWithValue(
            "$expire",
            (object?)snapshot.ExpireAt?.ToUnixTimeMilliseconds() ?? DBNull.Value);
        command.ExecuteNonQuery();
        return snapshot;
    }

    private const string SnapshotSelect = """
        SELECT id, subscription_id, cycle_id, observed_at, source_updated_at, source,
               upload_bytes, download_bytes, total_bytes, expire_at
        FROM quota_snapshots
        """;

    private static SubscriptionQuotaSnapshot ReadSnapshot(SqliteDataReader reader)
    {
        if (!Guid.TryParse(reader.GetString(0), out var id)
            || !Guid.TryParse(reader.GetString(1), out var subscriptionId)
            || !Guid.TryParse(reader.GetString(2), out var cycleId))
        {
            throw new QuotaLedgerException("订阅配额快照标识无效。");
        }

        return new SubscriptionQuotaSnapshot(
            id,
            subscriptionId,
            cycleId,
            DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(3)),
            reader.IsDBNull(4)
                ? null
                : DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(4)),
            Source(reader.GetString(5)),
            new QuotaTraffic(
                Bytes(reader.GetInt64(6)),
                Bytes(reader.GetInt64(7)),
                Bytes(reader.GetInt64(8))),
            reader.IsDBNull(9)
                ? null
                : DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(9)));
    }
}
