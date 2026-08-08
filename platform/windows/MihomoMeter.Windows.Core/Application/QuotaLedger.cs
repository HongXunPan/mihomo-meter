using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public interface IQuotaLedger : IAsyncDisposable
{
    Task<QuotaLedgerSnapshot> PrepareAsync(
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<QuotaLedgerSnapshot> UpsertSubscriptionAsync(
        TrackedSubscription subscription,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<QuotaLedgerSnapshot> SetSubscriptionStatusAsync(
        Guid subscriptionId,
        SubscriptionTrackingStatus status,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<QuotaLedgerSnapshot> RecordAsync(
        QuotaObservation observation,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<QuotaLedgerSnapshot> SaveQueryStateAsync(
        ProfileQuotaQueryState state,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<QuotaLedgerSnapshot> ConfirmCycleAsync(
        Guid cycleId,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task<QuotaLedgerSnapshot> ResetAsync(
        DateTimeOffset now,
        CancellationToken cancellationToken);
}

public sealed class QuotaLedgerException : Exception
{
    public QuotaLedgerException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
