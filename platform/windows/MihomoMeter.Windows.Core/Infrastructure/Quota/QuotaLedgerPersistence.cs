using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal sealed partial class QuotaLedgerPersistence : IDisposable
{
    private readonly SqliteConnection _connection;

    public QuotaLedgerPersistence(string databasePath)
    {
        var directory = Path.GetDirectoryName(databasePath)
            ?? throw new QuotaLedgerException("无法确定订阅配额目录。");
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
            Execute("PRAGMA foreign_keys = ON");
            Execute("PRAGMA journal_mode = WAL");
            Execute("PRAGMA synchronous = NORMAL");
            Execute("PRAGMA busy_timeout = 3000");
            QuotaLedgerSchema.Migrate(_connection);
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

    public T Transaction<T>(Func<SqliteTransaction, T> operation)
    {
        using var transaction = _connection.BeginTransaction();
        var result = operation(transaction);
        transaction.Commit();
        return result;
    }

    public void Transaction(Action<SqliteTransaction> operation)
    {
        _ = Transaction(transaction =>
        {
            operation(transaction);
            return true;
        });
    }

    public void Reset(SqliteTransaction transaction)
    {
        Execute(transaction, "DELETE FROM quota_query_state");
        Execute(transaction, "DELETE FROM quota_events");
        Execute(transaction, "DELETE FROM quota_snapshots");
        Execute(transaction, "DELETE FROM quota_cycles");
        Execute(transaction, "DELETE FROM subscriptions");
    }

    private void Execute(string sql)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private void Execute(SqliteTransaction transaction, string sql)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }
}
