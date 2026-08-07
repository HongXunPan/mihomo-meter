namespace MihomoMeter.Windows.Core.Domain;

public sealed record TrafficLedgerObservation(
    DateTimeOffset ObservedAt,
    TrafficBytes KernelTotal,
    TrafficLedgerTransition Transition);

public abstract record TrafficLedgerTransition;

public sealed record TrafficLedgerBaselineEstablished : TrafficLedgerTransition;

public sealed record TrafficLedgerDelta(TrafficDeltaReport Report) : TrafficLedgerTransition;

public sealed record TrafficLedgerCountersReset : TrafficLedgerTransition;
