using System.Text.Json;
using System.Text.Json.Serialization;

namespace MihomoMeter.Windows.Core.Application;

public sealed record DiagnosticExportEnvironment(
    string Platform,
    string Version,
    string Build,
    string OperatingSystem,
    string Architecture);

public sealed record DiagnosticExportRuntime(string ConnectionState);

public sealed record DiagnosticExportEvent
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
        "unknown_failure",
        "unknown",
    };

    private DiagnosticExportEvent(
        DateTimeOffset timestamp,
        string category,
        string? source = null,
        string? status = null,
        string? stage = null,
        string? format = null,
        int? hresult = null)
    {
        Timestamp = timestamp;
        Category = category;
        Source = source;
        Status = status;
        Stage = stage;
        Format = format;
        HResult = hresult;
    }

    public DateTimeOffset Timestamp { get; }

    public string Category { get; }

    public string? Source { get; }

    public string? Status { get; }

    public string? Stage { get; }

    public string? Format { get; }

    public int? HResult { get; }

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

public sealed record DiagnosticExportReport(
    int SchemaVersion,
    DateTimeOffset GeneratedAt,
    DiagnosticExportEnvironment Application,
    DiagnosticExportRuntime Runtime,
    IReadOnlyList<DiagnosticExportEvent> Events)
{
    public const int CurrentSchemaVersion = 1;
    public const int MaximumEventCount = 200;

    public static DiagnosticExportReport Create(
        DateTimeOffset generatedAt,
        DiagnosticExportEnvironment application,
        string connectionState,
        IReadOnlyList<DiagnosticExportEvent> events)
    {
        ArgumentNullException.ThrowIfNull(application);
        ArgumentNullException.ThrowIfNull(connectionState);
        ArgumentNullException.ThrowIfNull(events);
        return new DiagnosticExportReport(
            CurrentSchemaVersion,
            generatedAt,
            application,
            new DiagnosticExportRuntime(connectionState),
            events.TakeLast(MaximumEventCount).ToArray());
    }

    public byte[] Encode()
    {
        return JsonSerializer.SerializeToUtf8Bytes(
            this,
            new JsonSerializerOptions
            {
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = true,
            });
    }
}
