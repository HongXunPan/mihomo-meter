using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.ConnectionAnalytics;

internal static class ConnectionAnalyticsLedgerSchema
{
    public const long CurrentVersion = 1;

    public static void Migrate(SqliteConnection connection)
    {
        using var versionCommand = connection.CreateCommand();
        versionCommand.CommandText = "PRAGMA user_version";
        var version = (long)(versionCommand.ExecuteScalar() ?? 0L);
        if (version > CurrentVersion)
        {
            throw new ConnectionAnalyticsException("连接归因数据库版本过新。");
        }

        if (version == CurrentVersion)
        {
            return;
        }

        using var transaction = connection.BeginTransaction();
        Execute(connection, transaction, """
            CREATE TABLE connection_analytics_settings (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              history_enabled INTEGER NOT NULL CHECK(history_enabled IN (0, 1))
            )
            """);
        Execute(
            connection,
            transaction,
            "INSERT INTO connection_analytics_settings(id, history_enabled) VALUES (1, 0)");
        Execute(connection, transaction, """
            CREATE TABLE connection_daily_attribution (
              local_day TEXT NOT NULL,
              application_name TEXT NOT NULL,
              hostname TEXT NOT NULL,
              upload_bytes INTEGER NOT NULL CHECK(upload_bytes >= 0),
              download_bytes INTEGER NOT NULL CHECK(download_bytes >= 0),
              PRIMARY KEY(local_day, application_name, hostname)
            )
            """);
        Execute(connection, transaction, """
            CREATE INDEX connection_daily_attribution_retention
            ON connection_daily_attribution(local_day)
            """);
        Execute(connection, transaction, $"PRAGMA user_version = {CurrentVersion}");
        transaction.Commit();
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
