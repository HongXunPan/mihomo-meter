using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum QuotaAvailability
{
    Loading,
    Available,
    Unavailable,
}

public enum RuntimeQuotaObservationStatus
{
    ControllerUnavailable,
    Checking,
    NoCandidate,
    SingleCandidate,
    MultipleCandidates,
    Failed,
}

public sealed record QuotaTrackingState(
    QuotaAvailability Availability,
    QuotaLedgerSnapshot Ledger,
    ClashProfileCatalog Catalog,
    string? ProfileDirectoryPath,
    RuntimeQuotaObservationStatus RuntimeStatus,
    int RuntimeCandidateCount,
    bool ControllerAvailable,
    bool ActiveQueryAvailable,
    bool OperationInProgress,
    string? Message)
{
    public static QuotaTrackingState Loading(DateTimeOffset now) => new(
        QuotaAvailability.Loading,
        QuotaLedgerSnapshot.Empty(now),
        ClashProfileCatalog.Empty,
        null,
        RuntimeQuotaObservationStatus.ControllerUnavailable,
        0,
        false,
        false,
        false,
        null);
}

public interface IQuotaTrackingLifecycle
{
    Task ControllerValidatedAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);

    Task ControllerUnavailableAsync(CancellationToken cancellationToken);
}
