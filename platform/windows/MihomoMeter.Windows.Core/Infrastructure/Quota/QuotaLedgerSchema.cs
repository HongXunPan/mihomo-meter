using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal static class QuotaLedgerSchema
{
    public const long CurrentVersion = 1;

    public static void Migrate(SqliteConnection connection)
    {
        using var versionCommand = connection.CreateCommand();
        versionCommand.CommandText = "PRAGMA user_version";
        var version = (long)(versionCommand.ExecuteScalar() ?? 0L);
        if (version > CurrentVersion)
        {
            throw new QuotaLedgerException("订阅配额数据库版本过新。");
        }

        if (version == CurrentVersion)
        {
            return;
        }

        using var transaction = connection.BeginTransaction();
        CreateSubscriptions(connection, transaction);
        CreateCycles(connection, transaction);
        CreateSnapshots(connection, transaction);
        CreateEvents(connection, transaction);
        CreateQueryState(connection, transaction);
        Execute(connection, transaction, $"PRAGMA user_version = {CurrentVersion}");
        transaction.Commit();
    }

    private static void CreateSubscriptions(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE subscriptions (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL CHECK(length(trim(name)) > 0),
              identity_mode TEXT NOT NULL CHECK(identity_mode IN ('runtime_single', 'clash_profile')),
              clash_profile_uid TEXT,
              url_fingerprint TEXT,
              refresh_interval_minutes INTEGER,
              status TEXT NOT NULL CHECK(status IN ('active', 'paused', 'archived', 'unsupported')),
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              CHECK(created_at <= updated_at),
              CHECK(
                (identity_mode = 'runtime_single'
                  AND clash_profile_uid IS NULL
                  AND url_fingerprint IS NULL
                  AND refresh_interval_minutes IS NULL)
                OR
                (identity_mode = 'clash_profile'
                  AND length(trim(clash_profile_uid)) > 0
                  AND length(trim(url_fingerprint)) > 0
                  AND refresh_interval_minutes IN (60, 180, 360, 720, 1440))
              )
            )
            """);
        Execute(connection, transaction, """
            CREATE UNIQUE INDEX subscriptions_runtime_single
            ON subscriptions(identity_mode)
            WHERE identity_mode = 'runtime_single'
            """);
        Execute(connection, transaction, """
            CREATE UNIQUE INDEX subscriptions_profile_uid
            ON subscriptions(clash_profile_uid)
            WHERE identity_mode = 'clash_profile'
            """);
    }

    private static void CreateCycles(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE quota_cycles (
              id TEXT PRIMARY KEY,
              subscription_id TEXT NOT NULL,
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              start_reason TEXT NOT NULL CHECK(start_reason IN ('initial', 'usage_reset')),
              is_user_confirmed INTEGER NOT NULL CHECK(is_user_confirmed IN (0, 1)),
              CHECK(ended_at IS NULL OR ended_at >= started_at),
              FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
            )
            """);
        Execute(connection, transaction, """
            CREATE UNIQUE INDEX quota_cycles_one_open
            ON quota_cycles(subscription_id)
            WHERE ended_at IS NULL
            """);
        Execute(connection, transaction, """
            CREATE INDEX quota_cycles_history
            ON quota_cycles(subscription_id, started_at DESC)
            """);
    }

    private static void CreateSnapshots(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE quota_snapshots (
              id TEXT PRIMARY KEY,
              subscription_id TEXT NOT NULL,
              cycle_id TEXT NOT NULL,
              observed_at INTEGER NOT NULL,
              source_updated_at INTEGER,
              source TEXT NOT NULL CHECK(source IN ('mihomo_runtime', 'meter_active_query')),
              upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
              download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
              total_bytes INTEGER NOT NULL CHECK(total_bytes > 0),
              used_bytes INTEGER NOT NULL CHECK(used_bytes >= 0),
              remaining_bytes INTEGER NOT NULL CHECK(remaining_bytes >= 0),
              expire_at INTEGER,
              CHECK(used_bytes = upload_bytes + download_bytes),
              CHECK(remaining_bytes = CASE WHEN total_bytes > used_bytes THEN total_bytes - used_bytes ELSE 0 END),
              UNIQUE(subscription_id, observed_at),
              FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE,
              FOREIGN KEY(cycle_id) REFERENCES quota_cycles(id) ON DELETE CASCADE
            )
            """);
        Execute(connection, transaction, """
            CREATE INDEX quota_snapshots_history
            ON quota_snapshots(subscription_id, observed_at DESC)
            """);
    }

    private static void CreateEvents(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE quota_events (
              id TEXT PRIMARY KEY,
              subscription_id TEXT NOT NULL,
              previous_snapshot_id TEXT NOT NULL,
              current_snapshot_id TEXT NOT NULL,
              occurred_at INTEGER NOT NULL,
              kind TEXT NOT NULL CHECK(kind IN ('usage_reset', 'total_increased', 'total_decreased', 'expiration_changed')),
              is_user_confirmed INTEGER NOT NULL CHECK(is_user_confirmed IN (0, 1)),
              UNIQUE(current_snapshot_id, kind),
              FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE,
              FOREIGN KEY(previous_snapshot_id) REFERENCES quota_snapshots(id) ON DELETE CASCADE,
              FOREIGN KEY(current_snapshot_id) REFERENCES quota_snapshots(id) ON DELETE CASCADE
            )
            """);
        Execute(connection, transaction, """
            CREATE INDEX quota_events_history
            ON quota_events(subscription_id, occurred_at DESC)
            """);
    }

    private static void CreateQueryState(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE quota_query_state (
              subscription_id TEXT PRIMARY KEY,
              last_attempt_at INTEGER,
              next_attempt_at INTEGER,
              last_queried_url_fingerprint TEXT,
              consecutive_failures INTEGER NOT NULL CHECK(consecutive_failures >= 0),
              retry_day_start INTEGER,
              automatic_retry_count INTEGER NOT NULL CHECK(automatic_retry_count >= 0),
              last_failure_category TEXT,
              FOREIGN KEY(subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
            )
            """);
    }

    private static void Execute(
        SqliteConnection connection,
        SqliteTransaction transaction,
        string sql)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }
}
