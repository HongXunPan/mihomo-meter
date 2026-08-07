using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Domain;
using static MihomoMeter.Windows.Core.Infrastructure.Statistics.TrafficLedgerStorageValues;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal sealed class TrafficLedgerPersistence : IDisposable
{
    private readonly SqliteConnection _connection;

    public TrafficLedgerPersistence(string databasePath)
    {
        var directory = Path.GetDirectoryName(databasePath)
            ?? throw new TrafficStatisticsException("无法确定本地统计目录。");
        Directory.CreateDirectory(directory);

        var connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = databasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Pooling = false,
        }.ToString();
        _connection = new SqliteConnection(connectionString);
        Intervals = new TrafficIntervalPersistence(_connection);
        Daily = new TrafficDailyPersistence(_connection);
        Maintenance = new TrafficLedgerMaintenancePersistence(_connection);
        try
        {
            _connection.Open();
            Execute("PRAGMA foreign_keys = ON");
            Execute("PRAGMA journal_mode = WAL");
            Execute("PRAGMA synchronous = NORMAL");
            Execute("PRAGMA busy_timeout = 3000");
            TrafficLedgerSchema.Migrate(_connection);
        }
        catch
        {
            _connection.Dispose();
            throw;
        }
    }

    public TrafficIntervalPersistence Intervals { get; }

    public TrafficDailyPersistence Daily { get; }

    public TrafficLedgerMaintenancePersistence Maintenance { get; }

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

    public TrafficLedgerRuntimeState LoadRuntimeState()
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT current_session_id,
                   current_mihomo_version,
                   last_observed_at,
                   last_kernel_upload,
                   last_kernel_download
            FROM ledger_state WHERE id = 1
            """;
        using var reader = command.ExecuteReader();
        if (!reader.Read())
        {
            throw new TrafficStatisticsException("本地统计运行状态缺失。");
        }

        Guid? sessionId = null;
        if (!reader.IsDBNull(0))
        {
            if (!Guid.TryParse(reader.GetString(0), out var parsedSessionId))
            {
                throw new TrafficStatisticsException("本地统计会话标识无效。");
            }

            sessionId = parsedSessionId;
        }

        DateTimeOffset? lastObservedAt = reader.IsDBNull(2)
            ? null
            : DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(2));
        TrafficBytes? lastKernelTotal = reader.IsDBNull(3) || reader.IsDBNull(4)
            ? null
            : new TrafficBytes(
                checked((ulong)reader.GetInt64(3)),
                checked((ulong)reader.GetInt64(4)));
        return new TrafficLedgerRuntimeState(
            sessionId,
            reader.IsDBNull(1) ? null : reader.GetString(1),
            lastObservedAt,
            lastKernelTotal);
    }

    public void SaveRuntimeState(
        TrafficLedgerRuntimeState state,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE ledger_state
            SET current_session_id = $session,
                current_mihomo_version = $version,
                last_observed_at = $observed,
                last_kernel_upload = $upload,
                last_kernel_download = $download
            WHERE id = 1
            """;
        command.Parameters.AddWithValue(
            "$session",
            (object?)state.CurrentSessionId?.ToString("D") ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$version",
            (object?)state.CurrentMihomoVersion ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$observed",
            (object?)state.LastObservedAt?.ToUnixTimeMilliseconds() ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$upload",
            state.LastKernelTotal is null
                ? DBNull.Value
                : ToSqliteInteger(state.LastKernelTotal.Value.Upload));
        command.Parameters.AddWithValue(
            "$download",
            state.LastKernelTotal is null
                ? DBNull.Value
                : ToSqliteInteger(state.LastKernelTotal.Value.Download));
        command.ExecuteNonQuery();
    }

    public void CreateCoreSession(
        Guid id,
        string version,
        DateTimeOffset startedAt,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO core_sessions(id, mihomo_version, started_at)
            VALUES ($id, $version, $started)
            """;
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        command.Parameters.AddWithValue("$version", version);
        command.Parameters.AddWithValue("$started", startedAt.ToUnixTimeMilliseconds());
        command.ExecuteNonQuery();
    }

    public void CloseCoreSession(
        Guid id,
        DateTimeOffset endedAt,
        string reason,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            UPDATE core_sessions
            SET ended_at = $ended, end_reason = $reason
            WHERE id = $id AND ended_at IS NULL
            """;
        command.Parameters.AddWithValue("$ended", endedAt.ToUnixTimeMilliseconds());
        command.Parameters.AddWithValue("$reason", reason);
        command.Parameters.AddWithValue("$id", id.ToString("D"));
        command.ExecuteNonQuery();
    }

    public void Add(
        CategorizedTrafficBytes categories,
        DateTimeOffset observedAt,
        TimeZoneInfo timeZone,
        Guid coreSessionId,
        SqliteTransaction transaction)
    {
        var bucketStart = observedAt.ToUnixTimeSeconds() / 60 * 60;
        var localDay = TrafficDailyPersistence.LocalDay(observedAt, timeZone);
        foreach (var category in Enum.GetValues<TrafficCategory>())
        {
            var bytes = BytesFor(categories, category);
            if (bytes == TrafficBytes.Zero)
            {
                continue;
            }

            AddBucket(
                bucketStart,
                localDay,
                timeZone.Id,
                coreSessionId,
                category,
                bytes,
                transaction);
            AddDailyTotal(localDay, category, bytes, transaction);
        }
    }

    private void AddBucket(
        long bucketStart,
        string localDay,
        string timeZoneId,
        Guid sessionId,
        TrafficCategory category,
        TrafficBytes delta,
        SqliteTransaction transaction)
    {
        var stored = ReadStoredBytes(
            """
            SELECT upload_bytes, download_bytes FROM traffic_buckets
            WHERE bucket_start = $bucket
              AND local_day = $day
              AND time_zone_id = $zone
              AND core_session_id = $session
              AND category = $category
            """,
            command =>
            {
                command.Parameters.AddWithValue("$bucket", bucketStart);
                command.Parameters.AddWithValue("$day", localDay);
                command.Parameters.AddWithValue("$zone", timeZoneId);
                command.Parameters.AddWithValue("$session", sessionId.ToString("D"));
                command.Parameters.AddWithValue("$category", CategoryName(category));
            },
            transaction);
        var next = AddChecked(stored, delta);

        using var insert = _connection.CreateCommand();
        insert.Transaction = transaction;
        insert.CommandText = """
            INSERT OR IGNORE INTO traffic_buckets(
              bucket_start, local_day, time_zone_id, core_session_id, category,
              upload_bytes, download_bytes)
            VALUES ($bucket, $day, $zone, $session, $category, 0, 0)
            """;
        insert.Parameters.AddWithValue("$bucket", bucketStart);
        insert.Parameters.AddWithValue("$day", localDay);
        insert.Parameters.AddWithValue("$zone", timeZoneId);
        insert.Parameters.AddWithValue("$session", sessionId.ToString("D"));
        insert.Parameters.AddWithValue("$category", CategoryName(category));
        insert.ExecuteNonQuery();

        using var update = _connection.CreateCommand();
        update.Transaction = transaction;
        update.CommandText = """
            UPDATE traffic_buckets
            SET upload_bytes = $upload,
                download_bytes = $download
            WHERE bucket_start = $bucket
              AND local_day = $day
              AND time_zone_id = $zone
              AND core_session_id = $session
              AND category = $category
            """;
        update.Parameters.AddWithValue("$day", localDay);
        update.Parameters.AddWithValue("$zone", timeZoneId);
        update.Parameters.AddWithValue("$upload", ToSqliteInteger(next.Upload));
        update.Parameters.AddWithValue("$download", ToSqliteInteger(next.Download));
        update.Parameters.AddWithValue("$bucket", bucketStart);
        update.Parameters.AddWithValue("$session", sessionId.ToString("D"));
        update.Parameters.AddWithValue("$category", CategoryName(category));
        update.ExecuteNonQuery();
    }

    private void AddDailyTotal(
        string localDay,
        TrafficCategory category,
        TrafficBytes delta,
        SqliteTransaction transaction)
    {
        var stored = ReadStoredBytes(
            """
            SELECT upload_bytes, download_bytes FROM traffic_daily_totals
            WHERE local_day = $day AND category = $category
            """,
            command =>
            {
                command.Parameters.AddWithValue("$day", localDay);
                command.Parameters.AddWithValue("$category", CategoryName(category));
            },
            transaction);
        var next = AddChecked(stored, delta);

        using var insert = _connection.CreateCommand();
        insert.Transaction = transaction;
        insert.CommandText = """
            INSERT OR IGNORE INTO traffic_daily_totals(
              local_day, category, upload_bytes, download_bytes)
            VALUES ($day, $category, 0, 0)
            """;
        insert.Parameters.AddWithValue("$day", localDay);
        insert.Parameters.AddWithValue("$category", CategoryName(category));
        insert.ExecuteNonQuery();

        using var update = _connection.CreateCommand();
        update.Transaction = transaction;
        update.CommandText = """
            UPDATE traffic_daily_totals
            SET upload_bytes = $upload, download_bytes = $download
            WHERE local_day = $day AND category = $category
            """;
        update.Parameters.AddWithValue("$upload", ToSqliteInteger(next.Upload));
        update.Parameters.AddWithValue("$download", ToSqliteInteger(next.Download));
        update.Parameters.AddWithValue("$day", localDay);
        update.Parameters.AddWithValue("$category", CategoryName(category));
        update.ExecuteNonQuery();
    }

    private TrafficBytes ReadStoredBytes(
        string sql,
        Action<SqliteCommand> bind,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        bind(command);
        using var reader = command.ExecuteReader();
        return reader.Read()
            ? new TrafficBytes(
                checked((ulong)reader.GetInt64(0)),
                checked((ulong)reader.GetInt64(1)))
            : TrafficBytes.Zero;
    }

    private void Execute(string sql)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }
}
