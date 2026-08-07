using Microsoft.Data.Sqlite;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal sealed class TrafficLedgerMaintenancePersistence
{
    private readonly SqliteConnection _connection;

    public TrafficLedgerMaintenancePersistence(SqliteConnection connection)
    {
        _connection = connection;
    }

    public void Reset(SqliteTransaction transaction)
    {
        Execute("DELETE FROM traffic_intervals", transaction);
        Execute("DELETE FROM traffic_buckets", transaction);
        Execute("DELETE FROM traffic_daily_totals", transaction);
        Execute("DELETE FROM core_sessions", transaction);
        Execute("""
            UPDATE ledger_state
            SET current_session_id = NULL,
                current_mihomo_version = NULL,
                last_observed_at = NULL,
                last_kernel_upload = NULL,
                last_kernel_download = NULL
            WHERE id = 1
            """, transaction);
    }

    public void PruneBuckets(DateTimeOffset cutoff, SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "DELETE FROM traffic_buckets WHERE bucket_start < $cutoff";
        command.Parameters.AddWithValue("$cutoff", cutoff.ToUnixTimeSeconds());
        command.ExecuteNonQuery();
    }

    private void Execute(string sql, SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }
}
