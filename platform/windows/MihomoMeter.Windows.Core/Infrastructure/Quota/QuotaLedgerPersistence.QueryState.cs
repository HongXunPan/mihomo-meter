using Microsoft.Data.Sqlite;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Quota;

internal sealed partial class QuotaLedgerPersistence
{
    public ProfileQuotaQueryState? LoadQueryState(Guid subscriptionId)
    {
        using var command = _connection.CreateCommand();
        command.CommandText = """
            SELECT subscription_id, last_attempt_at, next_attempt_at,
                   last_queried_url_fingerprint, consecutive_failures,
                   retry_day_start, automatic_retry_count, last_failure_category
            FROM quota_query_state WHERE subscription_id = $subscription
            """;
        command.Parameters.AddWithValue("$subscription", subscriptionId.ToString("D"));
        using var reader = command.ExecuteReader();
        if (!reader.Read())
        {
            return null;
        }

        if (!Guid.TryParse(reader.GetString(0), out var id))
        {
            throw new QuotaLedgerException("订阅查询状态标识无效。");
        }

        return new ProfileQuotaQueryState(
            id,
            OptionalDate(reader, 1),
            OptionalDate(reader, 2),
            reader.IsDBNull(3) ? null : reader.GetString(3),
            reader.GetInt32(4),
            OptionalDate(reader, 5),
            reader.GetInt32(6),
            reader.IsDBNull(7) ? null : reader.GetString(7));
    }

    public void UpsertQueryState(
        ProfileQuotaQueryState state,
        SqliteTransaction transaction)
    {
        using var command = _connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO quota_query_state(
              subscription_id, last_attempt_at, next_attempt_at,
              last_queried_url_fingerprint, consecutive_failures,
              retry_day_start, automatic_retry_count, last_failure_category)
            VALUES(
              $subscription, $last, $next, $fingerprint, $failures,
              $retry_day, $retry_count, $failure_category)
            ON CONFLICT(subscription_id) DO UPDATE SET
              last_attempt_at = excluded.last_attempt_at,
              next_attempt_at = excluded.next_attempt_at,
              last_queried_url_fingerprint = excluded.last_queried_url_fingerprint,
              consecutive_failures = excluded.consecutive_failures,
              retry_day_start = excluded.retry_day_start,
              automatic_retry_count = excluded.automatic_retry_count,
              last_failure_category = excluded.last_failure_category
            """;
        command.Parameters.AddWithValue("$subscription", state.SubscriptionId.ToString("D"));
        command.Parameters.AddWithValue(
            "$last",
            (object?)state.LastAttemptAt?.ToUnixTimeMilliseconds() ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$next",
            (object?)state.NextAttemptAt?.ToUnixTimeMilliseconds() ?? DBNull.Value);
        command.Parameters.AddWithValue(
            "$fingerprint",
            (object?)state.LastQueriedUrlFingerprint ?? DBNull.Value);
        command.Parameters.AddWithValue("$failures", state.ConsecutiveFailures);
        command.Parameters.AddWithValue(
            "$retry_day",
            (object?)state.RetryDayStart?.ToUnixTimeMilliseconds() ?? DBNull.Value);
        command.Parameters.AddWithValue("$retry_count", state.AutomaticRetryCount);
        command.Parameters.AddWithValue(
            "$failure_category",
            (object?)state.LastFailureCategory ?? DBNull.Value);
        command.ExecuteNonQuery();
    }

    private static DateTimeOffset? OptionalDate(SqliteDataReader reader, int index)
    {
        return reader.IsDBNull(index)
            ? null
            : DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(index));
    }
}
