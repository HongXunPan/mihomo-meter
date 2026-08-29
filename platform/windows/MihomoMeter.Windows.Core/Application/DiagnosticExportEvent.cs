namespace MihomoMeter.Windows.Core.Application;

public sealed partial record DiagnosticExportEvent
{
    private const string UnknownToken = "unknown";
    private static readonly HashSet<string> AllowedStages = new(StringComparer.Ordinal)
    {
        "not_started",
        "diagnostics_console_ready",
        "app_xaml_initialize_started",
        "app_xaml_initialize_completed",
        "app_launch_entered",
        "app_launch_completed",
        "redirected_activation_window_show_started",
        "redirected_activation_window_show_completed",
        "startup_activation_detected",
        "startup_secondary_instance_skipped",
        "single_instance_registration_started",
        "single_instance_redirect_started",
        "single_instance_redirect_completed",
        "single_instance_primary_ready",
        "single_instance_shutdown_completed",
        "single_instance_activation_received",
        "single_instance_foreground_handoff_unavailable",
        "shared_core_runtime_ready",
        "shared_core_runtime_abi_mismatch",
        "shared_core_runtime_native_call_failed",
        "shared_core_runtime_unexpected_result",
        "shared_core_runtime_unknown_failure",
        "main_window_xaml_initialize_started",
        "main_window_xaml_initialize_completed",
        "main_window_show_started",
        "main_window_show_completed",
        "notification_area_icon_added",
        "notification_area_icon_removed",
        "window_lifecycle_ready",
        "window_hidden_to_notification_area",
        "floating_widget_created",
        "floating_widget_destroyed",
        "floating_widget_enabled",
        "floating_widget_disabled",
        "application_exit_requested",
    };
    private static readonly HashSet<string> AllowedFailureSources = new(StringComparer.Ordinal)
    {
        "program_main",
        "single_instance_listener",
        "app_constructor",
        "app_launch_cleanup",
        "app_launch",
        "redirected_activation_dispatch",
        "xaml_unhandled_exception",
        "system_recovery_session_monitor",
        "system_recovery_monitor",
        "system_recovery_transition",
        "notification_area_tooltip",
        "notification_area_message",
        "notification_area_realtime_update",
        "main_window_show_dispatch",
        "floating_widget_toggle",
        "floating_widget_toggle_dispatch",
        "statistics_workspace_show_dispatch",
        "quota_workspace_show_dispatch",
        "connection_analytics_workspace_show_dispatch",
        "controller_settings_show_dispatch",
        "updates_show_dispatch",
        "live_connections_workspace_show_dispatch",
        "notification_area_statistics_start",
        "notification_area_statistics_start_dispatch",
        "notification_area_statistics_stop",
        "notification_area_statistics_stop_dispatch",
        "notification_area_quota_refresh",
        "notification_area_quota_refresh_dispatch",
        "application_exit_dispatch",
        "application_exit_cleanup",
        "floating_widget_message",
    };
    private static readonly HashSet<string> AllowedFormats = new(StringComparer.Ordinal)
    {
        "byte_count",
        "rate",
        "compact_rate",
        "unknown",
    };
    private static readonly HashSet<string> AllowedSources = new(StringComparer.Ordinal)
    {
        "shared_primary",
        "shared_shadow",
        "native_fallback",
        "unknown",
    };
    private static readonly HashSet<string> AllowedStatuses = new(StringComparer.Ordinal)
    {
        "matched",
        "succeeded",
        "unrecognized",
        "abi_mismatch",
        "native_call_failed",
        "unsupported_input",
        "input_too_long",
        "unexpected_result",
        "mismatch",
        "failed",
        "not_found",
        "cancelled",
        "unknown_failure",
        "unknown",
    };
    private static readonly HashSet<string> AllowedOperations = new(StringComparer.Ordinal)
    {
        "load",
        "save",
        "delete",
    };
    private static readonly HashSet<string> AllowedOutcomes = new(StringComparer.Ordinal)
    {
        "succeeded",
        "not_found",
        "failed",
        "cancelled",
        "insecure_url",
        "no_proxy",
        "insecure_redirect",
        "http_status",
        "missing_header",
        "invalid_header",
        "timeout",
        "network",
        "storage_failed",
    };
    private static readonly HashSet<string> AllowedTriggers = new(StringComparer.Ordinal)
    {
        "application_startup",
        "user_request",
        "automatic_retry",
        "manual",
        "automatic",
    };
    private static readonly HashSet<string> AllowedReasons = new(StringComparer.Ordinal)
    {
        "stream_closed",
        "stream_network",
        "stream_timeout",
        "data_stale",
        "authentication_failed",
        "unsupported_response",
        "controller_http",
        "controller_network",
        "controller_timeout",
        "configuration_failure",
        "monitoring_stopped",
        "application_exit",
        "terminal_failure",
        "runtime_configuration_unavailable",
        "stale_watchdog",
        "unknown",
    };
    private static readonly HashSet<string> AllowedProxyKinds = new(StringComparer.Ordinal)
    {
        "mixed",
        "http",
        "socks",
        "unknown",
    };
    private static readonly HashSet<string> AllowedUserAgentSources = new(StringComparer.Ordinal)
    {
        "mihomo_config",
        "mihomo_default",
        "unknown",
    };

    private DiagnosticExportEvent(
        DateTimeOffset timestamp,
        string category,
        string? source = null,
        string? status = null,
        string? stage = null,
        string? format = null,
        int? hresult = null,
        string? operation = null,
        string? outcome = null,
        string? trigger = null,
        string? reason = null,
        int? attemptNumber = null,
        int? elapsedMilliseconds = null,
        int? delaySeconds = null,
        int? retryAfterSeconds = null,
        int? timeoutSeconds = null,
        int? reconnectAfterSeconds = null,
        int? httpStatus = null,
        string? proxyKind = null,
        string? userAgentSource = null,
        bool? isCurrentProfile = null)
    {
        Timestamp = timestamp;
        Category = category;
        Source = source;
        Status = status;
        Stage = stage;
        Format = format;
        HResult = hresult;
        Operation = operation;
        Outcome = outcome;
        Trigger = trigger;
        Reason = reason;
        AttemptNumber = attemptNumber;
        ElapsedMilliseconds = elapsedMilliseconds;
        DelaySeconds = delaySeconds;
        RetryAfterSeconds = retryAfterSeconds;
        TimeoutSeconds = timeoutSeconds;
        ReconnectAfterSeconds = reconnectAfterSeconds;
        HttpStatus = httpStatus;
        ProxyKind = proxyKind;
        UserAgentSource = userAgentSource;
        IsCurrentProfile = isCurrentProfile;
    }

    public DateTimeOffset Timestamp { get; }

    public string Category { get; }

    public string? Source { get; }

    public string? Status { get; }

    public string? Stage { get; }

    public string? Format { get; }

    public int? HResult { get; }

    public string? Operation { get; }

    public string? Outcome { get; }

    public string? Trigger { get; }

    public string? Reason { get; }

    public int? AttemptNumber { get; }

    public int? ElapsedMilliseconds { get; }

    public int? DelaySeconds { get; }

    public int? RetryAfterSeconds { get; }

    public int? TimeoutSeconds { get; }

    public int? ReconnectAfterSeconds { get; }

    public int? HttpStatus { get; }

    public string? ProxyKind { get; }

    public string? UserAgentSource { get; }

    public bool? IsCurrentProfile { get; }

    public static DiagnosticExportEvent ApplicationStage(
        DateTimeOffset timestamp,
        string stage)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "application.stage",
            stage: AllowedToken(stage, AllowedStages));
    }

    public static DiagnosticExportEvent ApplicationFailure(
        DateTimeOffset timestamp,
        string source,
        string stage,
        int hresult)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "application.failure",
            source: AllowedToken(source, AllowedFailureSources),
            stage: AllowedToken(stage, AllowedStages),
            hresult: hresult);
    }

    public static DiagnosticExportEvent SharedCoreTrafficShadow(
        DateTimeOffset timestamp,
        string format,
        string status)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "shared_core.traffic_shadow",
            status: AllowedToken(status, AllowedStatuses),
            format: AllowedToken(format, AllowedFormats));
    }

    public static DiagnosticExportEvent SharedCoreProxyTypeShadow(
        DateTimeOffset timestamp,
        string source,
        string status)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "shared_core.proxy_type_shadow",
            source: AllowedToken(source, AllowedSources),
            status: AllowedToken(status, AllowedStatuses));
    }

    public static DiagnosticExportEvent SharedCoreProxyTypeRoute(
        DateTimeOffset timestamp,
        string source,
        string status)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "shared_core.proxy_type_route",
            source: AllowedToken(source, AllowedSources),
            status: AllowedToken(status, AllowedStatuses));
    }

    public static DiagnosticExportEvent SharedCoreTrafficRoute(
        DateTimeOffset timestamp,
        string format,
        string source,
        string status)
    {
        return new DiagnosticExportEvent(
            timestamp,
            "shared_core.traffic_route",
            source: AllowedToken(source, AllowedSources),
            status: AllowedToken(status, AllowedStatuses),
            format: AllowedToken(format, AllowedFormats));
    }

    private static string AllowedToken(string value, IReadOnlySet<string> allowedValues)
    {
        return allowedValues.Contains(value) ? value : UnknownToken;
    }
}

public interface IDiagnosticEventSink
{
    void Record(DiagnosticExportEvent diagnosticEvent);
}

public sealed class NullDiagnosticEventSink : IDiagnosticEventSink
{
    public static NullDiagnosticEventSink Instance { get; } = new();

    public void Record(DiagnosticExportEvent diagnosticEvent)
    {
    }
}
