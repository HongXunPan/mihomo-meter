using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Quota.QuotaLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal sealed partial class QuotaLedgerPersistence
{
    public QuotaCycle? OpenCycle(Guid subscriptionId)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, subscription_id, started_at, ended_at,
                   start_reason, is_user_confirmed
            FROM quota_cycles
            WHERE subscription_id = $subscription AND ended_at IS NULL
            """;
        command.Parameters.AddWithValue("$subscription", subscriptionId.ToString("D"));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadCycle(reader) : null;
    }

    public QuotaCycle? LoadCycle(Guid cycleId)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT id, subscription_id, started_at, ended_at,
                   start_reason, is_user_confirmed
            FROM quota_cycles WHERE id = $id
            """;
        command.Parameters.AddWithValue("$id", cycleId.ToString("D"));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadCycle(reader) : null;
    }

    public QuotaCycle InsertCycle(
        Guid subscriptionId,
        DateTimeOffset startedAt,
        QuotaCycleStartReason reason,
        bool isUserConfirmed,
        SqliteTransaction transaction)
    {
        var cycle = new QuotaCycle(
            Guid.NewGuid(),
            subscriptionId,
            startedAt,
            null,
            reason,
            isUserConfirmed);
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO quota_cycles(
              id, subscription_id, started_at, start_reason, is_user_confirmed)
            VALUES ($id, $subscription, $started, $reason, $confirmed)
            """;
        command.Parameters.AddWithValue("$id", cycle.Id.ToString("D"));
        command.Parameters.AddWithValue("$subscription", cycle.SubscriptionId.ToString("D"));
        command.Parameters.AddWithValue("$started", cycle.StartedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$reason", CycleReason(cycle.StartReason));
        command.Parameters.AddWithValue("$confirmed", cycle.IsUserConfirmed ? 1 : 0);
        command.ExecuteNonQuery();
        return cycle;
    }

    public void CloseCycle(
        Guid cycleId,
        DateTimeOffset endedAt,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE quota_cycles SET ended_at = $ended
            WHERE id = $id AND ended_at IS NULL
            """;
        command.Parameters.AddWithValue("$ended", endedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$id", cycleId.ToString("D"));
        if (command.ExecuteNonQuery() != 1)
        {
            throw new QuotaLedgerException("当前订阅周期不存在或已经结束。");
        }
    }

    public void ConfirmCycle(Guid cycleId, SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE quota_cycles SET is_user_confirmed = 1
            WHERE id = $id AND is_user_confirmed = 0
            """;
        command.Parameters.AddWithValue("$id", cycleId.ToString("D"));
        if (command.ExecuteNonQuery() != 1)
        {
            throw new QuotaLedgerException("没有可确认的订阅周期。");
        }

        using var eventCommand = _connection.CreateCommand();
        eventCommand.Transaction = transaction;
        eventCommand.CommandText = """
            UPDATE quota_events SET is_user_confirmed = 1
            WHERE current_snapshot_id IN (
              SELECT id FROM quota_snapshots WHERE cycle_id = $cycle
            ) AND kind = 'usage_reset'
            """;
        eventCommand.Parameters.AddWithValue("$cycle", cycleId.ToString("D"));
        eventCommand.ExecuteNonQuery();
    }

    private static QuotaCycle ReadCycle(SqliteDataReader reader)
    {
        if (!Guid.TryParse(reader.GetString(0), out var id)
            || !Guid.TryParse(reader.GetString(1), out var subscriptionId))
        {
            throw new QuotaLedgerException("订阅周期标识无效。");
        }

        return new QuotaCycle(
            id,
            subscriptionId,
            DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(2)),
            reader.IsDBNull(3)
                ? null
                : DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(3)),
            CycleReason(reader.GetString(4)),
            reader.GetInt64(5) == 1);
    }
}
