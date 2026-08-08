using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Quota.QuotaLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal sealed partial class QuotaLedgerPersistence
{
    public IReadOnlyList<QuotaEvent> LoadEvents(Guid subscriptionId, int limit)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, subscription_id, previous_snapshot_id, current_snapshot_id,
                   occurred_at, kind, is_user_confirmed
            FROM quota_events
            WHERE subscription_id = $subscription
            ORDER BY occurred_at DESC LIMIT $limit
            """;
        command.Parameters.AddWithValue("$subscription", subscriptionId.ToString("D"));
        command.Parameters.AddWithValue("$limit", limit);
        using var reader = command.ExecuteReader();
        var events = new List<QuotaEvent>();
        while (reader.Read())
        {
            events.Add(ReadEvent(reader));
        }

        return events;
    }

    public void InsertEvents(
        SubscriptionQuotaSnapshot previous,
        SubscriptionQuotaSnapshot current,
        bool startedResetCycle,
        SqliteTransaction transaction)
    {
        if (startedResetCycle)
        {
            InsertEvent(previous, current, QuotaEventKind.UsageReset, false, transaction);
        }

        if (current.Traffic.TotalBytes > previous.Traffic.TotalBytes)
        {
            InsertEvent(previous, current, QuotaEventKind.TotalIncreased, true, transaction);
        }
        else if (current.Traffic.TotalBytes < previous.Traffic.TotalBytes)
        {
            InsertEvent(previous, current, QuotaEventKind.TotalDecreased, true, transaction);
        }

        if (current.ExpireAt != previous.ExpireAt)
        {
            InsertEvent(previous, current, QuotaEventKind.ExpirationChanged, true, transaction);
        }
    }

    private void InsertEvent(
        SubscriptionQuotaSnapshot previous,
        SubscriptionQuotaSnapshot current,
        QuotaEventKind kind,
        bool isUserConfirmed,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO quota_events(
              id, subscription_id, previous_snapshot_id, current_snapshot_id,
              occurred_at, kind, is_user_confirmed)
            VALUES ($id, $subscription, $previous, $current, $occurred, $kind, $confirmed)
            """;
        command.Parameters.AddWithValue("$id", Guid.NewGuid().ToString("D"));
        command.Parameters.AddWithValue("$subscription", current.SubscriptionId.ToString("D"));
        command.Parameters.AddWithValue("$previous", previous.Id.ToString("D"));
        command.Parameters.AddWithValue("$current", current.Id.ToString("D"));
        command.Parameters.AddWithValue("$occurred", current.ObservedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$kind", EventKind(kind));
        command.Parameters.AddWithValue("$confirmed", isUserConfirmed ? 1 : 0);
        command.ExecuteNonQuery();
    }

    private static QuotaEvent ReadEvent(SqliteDataReader reader)
    {
        if (!Guid.TryParse(reader.GetString(0), out var id)
            || !Guid.TryParse(reader.GetString(1), out var subscriptionId)
            || !Guid.TryParse(reader.GetString(2), out var previousSnapshotId)
            || !Guid.TryParse(reader.GetString(3), out var currentSnapshotId))
        {
            throw new QuotaLedgerException("订阅变化事件标识无效。");
        }

        return new QuotaEvent(
            id,
            subscriptionId,
            previousSnapshotId,
            currentSnapshotId,
            DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(4)),
            EventKind(reader.GetString(5)),
            reader.GetInt64(6) == 1);
    }
}
