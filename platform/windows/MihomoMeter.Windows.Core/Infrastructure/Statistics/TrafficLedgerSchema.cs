using Microsoft.Data.Sqlite;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal static class TrafficLedgerSchema
{
    public const long CurrentVersion = 2;

    public static void Migrate(SqliteConnection connection)
    {
        using var versionCommand = connection.CreateCommand();
        versionCommand.CommandText = "PRAGMA user_version";
        var version = (long)(versionCommand.ExecuteScalar() ?? 0L);
        if (version > CurrentVersion)
        {
            throw new TrafficStatisticsException("本地统计数据库版本过新。");
        }

        if (version == CurrentVersion)
        {
            return;
        }

        using var transaction = connection.BeginTransaction();
        if (version == 0)
        {
            CreateCoreTables(connection, transaction);
        }

        if (version <= 1)
        {
            CreateIntervalTable(connection, transaction);
        }

        Execute(connection, transaction, $"PRAGMA user_version = {CurrentVersion}");
        transaction.Commit();
    }

    private static void CreateCoreTables(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE core_sessions (
              id TEXT PRIMARY KEY,
              mihomo_version TEXT NOT NULL,
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              end_reason TEXT
            )
            """);
        Execute(connection, transaction, """
            CREATE TABLE traffic_buckets (
              bucket_start INTEGER NOT NULL,
              local_day TEXT NOT NULL,
              time_zone_id TEXT NOT NULL,
              core_session_id TEXT NOT NULL,
              category TEXT NOT NULL,
              upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
              download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
              PRIMARY KEY(
                bucket_start,
                local_day,
                time_zone_id,
                core_session_id,
                category
              ),
              FOREIGN KEY(core_session_id) REFERENCES core_sessions(id)
            )
            """);
        Execute(connection, transaction, """
            CREATE INDEX traffic_buckets_retention
            ON traffic_buckets(bucket_start)
            """);
        Execute(connection, transaction, """
            CREATE TABLE traffic_daily_totals (
              local_day TEXT NOT NULL,
              category TEXT NOT NULL,
              upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
              download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
              PRIMARY KEY(local_day, category)
            )
            """);
        Execute(connection, transaction, """
            CREATE TABLE ledger_state (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              current_session_id TEXT,
              current_mihomo_version TEXT,
              last_observed_at INTEGER,
              last_kernel_upload INTEGER,
              last_kernel_download INTEGER
            )
            """);
        Execute(connection, transaction, "INSERT INTO ledger_state(id) VALUES (1)");
    }

    private static void CreateIntervalTable(
        SqliteConnection connection,
        SqliteTransaction transaction)
    {
        Execute(connection, transaction, """
            CREATE TABLE traffic_intervals (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              note TEXT,
              status TEXT NOT NULL CHECK(status IN ('active', 'completed', 'interrupted')),
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              end_reason TEXT,
              start_proxy_upload INTEGER NOT NULL CHECK(start_proxy_upload >= 0),
              start_proxy_download INTEGER NOT NULL CHECK(start_proxy_download >= 0),
              end_proxy_upload INTEGER CHECK(end_proxy_upload >= 0),
              end_proxy_download INTEGER CHECK(end_proxy_download >= 0),
              CHECK(
                (status = 'active'
                  AND ended_at IS NULL
                  AND end_reason IS NULL
                  AND end_proxy_upload IS NULL
                  AND end_proxy_download IS NULL)
                OR
                (status IN ('completed', 'interrupted')
                  AND ended_at IS NOT NULL
                  AND end_reason IS NOT NULL
                  AND end_proxy_upload IS NOT NULL
                  AND end_proxy_download IS NOT NULL)
              )
            )
            """);
        Execute(connection, transaction, """
            CREATE INDEX traffic_intervals_status_time
            ON traffic_intervals(status, started_at DESC, ended_at DESC)
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
