namespace MihomoMeter.Windows.Core.Application;

public sealed partial record DiagnosticExportEvent
{
    public static DiagnosticExportEvent CredentialOperationStarted(
        DateTimeOffset timestamp,
        string operation)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "credential.operation.started",
            operation: AllowedToken(operation, AllowedOperations));
    }

    public static DiagnosticExportEvent CredentialOperationFinished(
        DateTimeOffset timestamp,
        string operation,
        string status,
        int elapsedMilliseconds,
        int? hresult = null)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "credential.operation.finished",
            status: AllowedToken(status, AllowedStatuses),
            hresult: hresult,
            operation: AllowedToken(operation, AllowedOperations),
            elapsedMilliseconds: Math.Max(elapsedMilliseconds, 0));
    }

    public static DiagnosticExportEvent ConnectionAttemptStarted(
        DateTimeOffset timestamp,
        string trigger,
        int attemptNumber)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "connection.attempt.started",
            trigger: AllowedToken(trigger, AllowedTriggers),
            attemptNumber: Math.Max(attemptNumber, 1));
    }

    public static DiagnosticExportEvent ConnectionEstablished(DateTimeOffset timestamp)
    {
        return new DiagnosticExportEvent(timestamp, "connection.established");
    }

    public static DiagnosticExportEvent RuntimeConfigurationUnavailable(
        DateTimeOffset timestamp,
        string reason)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "runtime_configuration.unavailable",
            reason: AllowedToken(reason, AllowedReasons));
    }

    public static DiagnosticExportEvent ConnectionDataStale(
        DateTimeOffset timestamp,
        int timeoutSeconds,
        int reconnectAfterSeconds)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "connection.data_stale",
            timeoutSeconds: Math.Max(timeoutSeconds, 0),
            reconnectAfterSeconds: Math.Max(reconnectAfterSeconds, 0));
    }

    public static DiagnosticExportEvent ConnectionCancellationRequested(
        DateTimeOffset timestamp,
        string reason)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "connection.cancellation_requested",
            reason: AllowedToken(reason, AllowedReasons));
    }

    public static DiagnosticExportEvent ConnectionReconnectScheduled(
        DateTimeOffset timestamp,
        string reason,
        int delaySeconds)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "connection.reconnect_scheduled",
            reason: AllowedToken(reason, AllowedReasons),
            delaySeconds: Math.Max(delaySeconds, 0));
    }

    public static DiagnosticExportEvent ConnectionStopped(
        DateTimeOffset timestamp,
        string reason)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "connection.stopped",
            reason: AllowedToken(reason, AllowedReasons));
    }

    public static DiagnosticExportEvent ProfileQuotaQueryStarted(
        DateTimeOffset timestamp,
        string trigger,
        bool isCurrentProfile,
        string proxyKind,
        string userAgentSource)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "profile_quota.query.started",
            trigger: AllowedToken(trigger, AllowedTriggers),
            proxyKind: AllowedToken(proxyKind, AllowedProxyKinds),
            userAgentSource: AllowedToken(userAgentSource, AllowedUserAgentSources),
            isCurrentProfile: isCurrentProfile);
    }

    public static DiagnosticExportEvent ProfileQuotaQueryFinished(
        DateTimeOffset timestamp,
        string trigger,
        string outcome,
        int elapsedMilliseconds,
        int? retryAfterSeconds,
        int? httpStatus = null)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "profile_quota.query.finished",
            outcome: AllowedToken(outcome, AllowedOutcomes),
            trigger: AllowedToken(trigger, AllowedTriggers),
            elapsedMilliseconds: Math.Max(elapsedMilliseconds, 0),
            retryAfterSeconds: retryAfterSeconds is null
                ? null
                : Math.Max(retryAfterSeconds.Value, 0),
            httpStatus: httpStatus);
    }
}
