using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Quota.QuotaLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal sealed partial class QuotaLedgerPersistence
{
    public IReadOnlyList<TrackedSubscription> LoadSubscriptions()
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, name, identity_mode, clash_profile_uid, url_fingerprint,
                   refresh_interval_minutes, status, created_at, updated_at
            FROM subscriptions
            WHERE status != 'archived'
            ORDER BY CASE identity_mode WHEN 'runtime_single' THEN 0 ELSE 1 END,
                     updated_at DESC
            """;
        using var reader = command.ExecuteReader();
        var subscriptions = new List<TrackedSubscription>();
        while (reader.Read())
        {
            subscriptions.Add(ReadSubscription(reader));
        }

        return subscriptions;
    }

    public TrackedSubscription? LoadSubscription(Guid id)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, name, identity_mode, clash_profile_uid, url_fingerprint,
                   refresh_interval_minutes, status, created_at, updated_at
            FROM subscriptions WHERE id = $id
            """;
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadSubscription(reader) : null;
    }

    public TrackedSubscription? LoadRuntimeSubscription()
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, name, identity_mode, clash_profile_uid, url_fingerprint,
                   refresh_interval_minutes, status, created_at, updated_at
            FROM subscriptions WHERE identity_mode = 'runtime_single'
            """;
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadSubscription(reader) : null;
    }

    public TrackedSubscription? LoadProfileSubscription(string uid)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, name, identity_mode, clash_profile_uid, url_fingerprint,
                   refresh_interval_minutes, status, created_at, updated_at
            FROM subscriptions WHERE clash_profile_uid = $uid
            """;
        command.Parameters.AddWithValue("$uid", uid);
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadSubscription(reader) : null;
    }

    public void UpsertSubscription(
        TrackedSubscription subscription,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO subscriptions(
              id, name, identity_mode, clash_profile_uid, url_fingerprint,
              refresh_interval_minutes, status, created_at, updated_at)
            VALUES(
              $id, $name, $mode, $uid, $fingerprint,
              $interval, $status, $created, $updated)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              url_fingerprint = excluded.url_fingerprint,
              refresh_interval_minutes = excluded.refresh_interval_minutes,
              status = excluded.status,
              updated_at = excluded.updated_at
            """;
        command.Parameters.AddWithValue("$id", subscription.Id.ToString("D"));
        command.Parameters.AddWithValue("$name", subscription.Name);
        command.Parameters.AddWithValue("$mode", Identity(subscription.IdentityMode));
        command.Parameters.AddWithValue(
            "$uid",
            (object?)subscription.ClashProfileUid ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$fingerprint",
            (object?)subscription.UrlFingerprint ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$interval",
            (object?)subscription.RefreshIntervalMinutes ?? DBNull.Value);
        command.Parameters.AddWithValue("$status", Status(subscription.Status));
        command.Parameters.AddWithValue("$created", subscription.CreatedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$updated", subscription.UpdatedAt.ToUnixTimeMilliseconds());
        command.ExecuteNonQuery();
    }

    public void SetSubscriptionStatus(
        Guid id,
        SubscriptionTrackingStatus status,
        DateTimeOffset updatedAt,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE subscriptions SET status = $status, updated_at = $updated
            WHERE id = $id
            """;
        command.Parameters.AddWithValue("$status", Status(status));
        command.Parameters.AddWithValue("$updated", updatedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        if (command.ExecuteNonQuery() != 1)
        {
            throw new QuotaLedgerException("未找到订阅身份。");
        }
    }

    private static TrackedSubscription ReadSubscription(SqliteDataReader reader)
    {
        if (!Guid.TryParse(reader.GetString(0), out var id))
        {
            throw new QuotaLedgerException("订阅身份标识无效。");
        }

        return new TrackedSubscription(
            id,
            reader.GetString(1),
            Identity(reader.GetString(2)),
            reader.IsDBNull(3) ? null : reader.GetString(3),
            reader.IsDBNull(4) ? null : reader.GetString(4),
            reader.IsDBNull(5) ? null : reader.GetInt32(5),
            Status(reader.GetString(6)),
            DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(7)),
            DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(8)));
    }
}
