using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal sealed record TrafficLedgerRuntimeState(
    Guid? CurrentSessionId = null,
    string? CurrentMihomoVersion = null,
    DateTimeOffset? LastObservedAt = null,
    TrafficBytes? LastKernelTotal = null);
