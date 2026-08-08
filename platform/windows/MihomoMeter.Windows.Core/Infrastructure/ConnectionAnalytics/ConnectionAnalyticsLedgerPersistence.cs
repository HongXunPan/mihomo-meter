using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.ConnectionAnalytics;

internal sealed partial class ConnectionAnalyticsLedgerPersistence : IDisposable
{
    private readonly SqliteConnection _connection;

    public ConnectionAnalyticsLedgerPersistence(string databasePath)
    {
        var directory = Path.GetDirectoryName(databasePath)
            ?? throw new ConnectionAnalyticsException("无法确定连接归因数据库目录。");
        Directory.CreateDirectory(directory);
        var connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = databasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Pooling = false,
        }.ToString();
        _connection = new SqliteConnection(connectionString);
        try
        {
            _connection.Open();
            Execute("PRAGMA journal_mode = WAL");
            Execute("PRAGMA synchronous = NORMAL");
            Execute("PRAGMA busy_timeout = 3000");
            ConnectionAnalyticsLedgerSchema.Migrate(_connection);
        }
        catch
        {
            _connection.Dispose();
            throw;
        }
    }

    public void Dispose()
    {
        _connection.Dispose();
    }

    public void Transaction(Action<SqliteTransaction> operation)
    {
        using var transaction = _connection.BeginTransaction();
        operation(transaction);
        transaction.Commit();
    }

    public bool IsHistoryEnabled()
    {
        using var command = _connection.CreateCommand();
        command.CommandText =
            "SELECT history_enabled FROM connection_analytics_settings WHERE id = 1";
        var value = command.ExecuteScalar();
        if (value is not long enabled)
        {
            throw new ConnectionAnalyticsException("连接归因设置缺失。");
        }
        return enabled == 1;
    }

    public void SetHistoryEnabled(bool isEnabled)
    {
        using var command = _connection.CreateCommand();
        command.CommandText =
            "UPDATE connection_analytics_settings SET history_enabled = $enabled WHERE id = 1";
        command.Parameters.AddWithValue("$enabled", isEnabled ? 1L : 0L);
        if (command.ExecuteNonQuery() != 1)
        {
            throw new ConnectionAnalyticsException("连接归因设置更新失败。");
        }
    }

    public HashSet<ConnectionAttributionStorageKey> ExistingKeys(
        string localDay,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            SELECT application_name, hostname
            FROM connection_daily_attribution
            WHERE local_day = $day
            """;
        command.Parameters.AddWithValue("$day", localDay);
        using var reader = command.ExecuteReader();
        var keys = new HashSet<ConnectionAttributionStorageKey>();
        while (reader.Read())
        {
            keys.Add(new ConnectionAttributionStorageKey(
                localDay,
                reader.GetString(0),
                reader.GetString(1)));
        }
        return keys;
    }

    public void Upsert(
        ConnectionAttributionAggregate aggregate,
        SqliteTransaction transaction)
    {
        var existing = StoredBytes(aggregate.Key, transaction);
        var next = new TrafficBytes(
            checked(existing.Upload + aggregate.Bytes.Upload),
            checked(existing.Download + aggregate.Bytes.Download));
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO connection_daily_attribution(
              local_day, application_name, hostname, upload_bytes, download_bytes
            ) VALUES ($day, $application, $hostname, $upload, $download)
            ON CONFLICT(local_day, application_name, hostname) DO UPDATE SET
              upload_bytes = excluded.upload_bytes,
              download_bytes = excluded.download_bytes
            """;
        command.Parameters.AddWithValue("$day", aggregate.Key.LocalDay);
        command.Parameters.AddWithValue("$application", aggregate.Key.ApplicationName);
        command.Parameters.AddWithValue("$hostname", aggregate.Key.Hostname);
        command.Parameters.AddWithValue("$upload", SqliteInteger(next.Upload));
        command.Parameters.AddWithValue("$download", SqliteInteger(next.Download));
        command.ExecuteNonQuery();
    }

    public void Prune(string cutoffLocalDay, SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText =
            "DELETE FROM connection_daily_attribution WHERE local_day < $cutoff";
        command.Parameters.AddWithValue("$cutoff", cutoffLocalDay);
        command.ExecuteNonQuery();
    }

    public void ClearHistory(SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "DELETE FROM connection_daily_attribution";
        command.ExecuteNonQuery();
    }

    private TrafficBytes StoredBytes(
        ConnectionAttributionStorageKey key,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            SELECT upload_bytes, download_bytes
            FROM connection_daily_attribution
            WHERE local_day = $day
              AND application_name = $application
              AND hostname = $hostname
            """;
        command.Parameters.AddWithValue("$day", key.LocalDay);
        command.Parameters.AddWithValue("$application", key.ApplicationName);
        command.Parameters.AddWithValue("$hostname", key.Hostname);
        using var reader = command.ExecuteReader();
        return reader.Read()
            ? ReadBytes(reader, 0, 1)
            : TrafficBytes.Zero;
    }

    private void Execute(string sql)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private static long SqliteInteger(ulong value)
    {
        if (value > long.MaxValue)
        {
            throw new ConnectionAnalyticsException("连接归因累计值超出数据库支持范围。");
        }
        return (long)value;
    }

    private static TrafficBytes ReadBytes(
        SqliteDataReader reader,
        int uploadIndex,
        int downloadIndex)
    {
        return new TrafficBytes(
            checked((ulong)reader.GetInt64(uploadIndex)),
            checked((ulong)reader.GetInt64(downloadIndex)));
    }
}
