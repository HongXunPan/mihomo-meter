using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal sealed record FloatingWidgetDisplaySnapshot(
    string FirstLine,
    string SecondLine,
    string AccessibleText);

internal sealed record NotificationAreaRealtimeMenuSnapshot(
    MonitorConnectionState State,
    string StateText,
    string ToolTip,
    string ProxyRateText,
    string DirectRateText,
    string RejectRateText,
    string UnknownRateText,
    string CoverageText,
    string ProxySummary,
    string ProxyDetails,
    string RuleSummary,
    string RuleDetails,
    string RuntimeSummary,
    IReadOnlyList<string> RuntimeDetails,
    FloatingWidgetDisplaySnapshot Widget)
{
    public static NotificationAreaRealtimeMenuSnapshot Disconnected => Create(
        TrafficMonitorSnapshot.Disconnected);

    public static NotificationAreaRealtimeMenuSnapshot Create(TrafficMonitorSnapshot snapshot)
    {
        var stateText = StateTitle(snapshot.State);
        var proxyRate = snapshot.Rates?.Proxy;
        var compactDownload = TrafficDisplayFormatter.CompactRate(
            proxyRate?.DownloadBytesPerSecond);
        var compactUpload = TrafficDisplayFormatter.CompactRate(
            proxyRate?.UploadBytesPerSecond);
        var routing = new RoutingStatusPresentation(
            snapshot.ActiveProxyLeaves,
            snapshot.ActiveRuleTypes,
            snapshot.RuntimeConfiguration,
            snapshot.MihomoVersion);
        var toolTip = snapshot.State == MonitorConnectionState.Connected
            ? $"Mihomo Meter · ↓{compactDownload} ↑{compactUpload}"
            : $"Mihomo Meter · {stateText}";
        var widget = snapshot.Rates is null
            ? new FloatingWidgetDisplaySnapshot(
                "Mihomo",
                stateText,
                $"Mihomo Meter，{stateText}")
            : new FloatingWidgetDisplaySnapshot(
                $"↓{compactDownload}",
                $"↑{compactUpload}",
                $"Mihomo Meter，Proxy 下载 {compactDownload}，上传 {compactUpload}");

        return new NotificationAreaRealtimeMenuSnapshot(
            snapshot.State,
            stateText,
            toolTip,
            $"Proxy：{TrafficDisplayFormatter.Rate(proxyRate)}",
            $"DIRECT：{TrafficDisplayFormatter.Rate(snapshot.Rates?.Direct)}",
            $"REJECT：{TrafficDisplayFormatter.Rate(snapshot.Rates?.Reject)}",
            $"未知：{TrafficDisplayFormatter.Rate(snapshot.Rates?.Unknown)}",
            snapshot.Coverage is null
                ? "分类覆盖率：--"
                : $"分类覆盖率：{TrafficDisplayFormatter.Percentage(snapshot.Coverage)}",
            routing.ProxySummary,
            routing.ProxyDetails,
            routing.RuleSummary,
            routing.RuleDetails,
            routing.RuntimeSummary,
            routing.RuntimeDetails,
            widget);
    }

    private static string StateTitle(MonitorConnectionState state)
    {
        return state switch
        {
            MonitorConnectionState.Disconnected => "未连接",
            MonitorConnectionState.Connecting => "正在连接",
            MonitorConnectionState.Connected => "已连接",
            MonitorConnectionState.Stale => "数据已超时",
            MonitorConnectionState.Reconnecting => "正在重连",
            MonitorConnectionState.AuthenticationFailed => "鉴权失败",
            MonitorConnectionState.Unsupported => "响应不兼容",
            _ => "未知状态",
        };
    }
}

internal sealed record RoutingStatusPresentation(
    string ProxySummary,
    string ProxyDetails,
    string RuleSummary,
    string RuleDetails,
    string RuntimeSummary,
    IReadOnlyList<string> RuntimeDetails)
{
    public RoutingStatusPresentation(
        IReadOnlyList<string> activeProxyLeaves,
        IReadOnlyList<string> activeRuleTypes,
        MihomoRuntimeConfiguration? configuration,
        string? mihomoVersion)
        : this(
            CompactSummary(activeProxyLeaves, "未检测到可确认出口", "个出口"),
            Details(activeProxyLeaves, "未检测到可确认出口"),
            CompactSummary(activeRuleTypes, "暂无活动规则", "类规则"),
            Details(activeRuleTypes, "暂无活动规则"),
            Runtime(configuration),
            BuildRuntimeDetails(configuration, mihomoVersion))
    {
    }

    private static string CompactSummary(
        IReadOnlyList<string> values,
        string emptyValue,
        string unit)
    {
        return values.Count switch
        {
            0 => emptyValue,
            1 => values[0],
            _ => $"{values[0]} 等 {values.Count}{unit}",
        };
    }

    private static string Details(IReadOnlyList<string> values, string emptyValue)
    {
        return values.Count == 0 ? emptyValue : string.Join("、", values);
    }

    private static string Runtime(MihomoRuntimeConfiguration? configuration)
    {
        if (configuration is null)
        {
            return "—";
        }

        var components = new List<string>();
        if (!string.IsNullOrWhiteSpace(configuration.Mode))
        {
            components.Add(configuration.Mode.Trim().ToLowerInvariant() switch
            {
                "rule" => "Rule",
                "global" => "Global",
                "direct" => "Direct",
                _ => configuration.Mode.Trim(),
            });
        }
        if (configuration.IsTunEnabled is bool isTunEnabled)
        {
            components.Add(isTunEnabled ? "TUN" : "TUN 关闭");
        }
        return components.Count == 0 ? "—" : string.Join(" · ", components);
    }

    private static IReadOnlyList<string> BuildRuntimeDetails(
        MihomoRuntimeConfiguration? configuration,
        string? mihomoVersion)
    {
        return Array.AsReadOnly(new[]
        {
            $"TUN Stack：{Text(configuration?.TunStack)}",
            $"自动路由：{BooleanSummary(configuration?.AutomaticallyRoutesTraffic)}",
            $"IPv6：{BooleanSummary(configuration?.IsIPv6Enabled)}",
            $"局域网访问：{BooleanSummary(configuration?.AllowsLan, "允许", "禁止")}",
            $"Mixed Port：{PortSummary(configuration?.MixedPort)}",
            $"Mihomo：{Text(mihomoVersion)}",
        });
    }

    private static string Text(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? "—" : value.Trim();
    }

    private static string BooleanSummary(
        bool? value,
        string enabled = "开启",
        string disabled = "关闭")
    {
        return value is null ? "—" : value.Value ? enabled : disabled;
    }

    private static string PortSummary(int? value)
    {
        return value is null ? "—" : value > 0 ? value.Value.ToString() : "未启用";
    }
}

internal sealed class NotificationAreaRealtimeController : IDisposable
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly TrafficMonitoringCoordinator _coordinator;
    private NotificationAreaRealtimeMenuSnapshot _snapshot =
        NotificationAreaRealtimeMenuSnapshot.Disconnected;
    private bool _disposed;

    public NotificationAreaRealtimeController(
        DispatcherQueue dispatcherQueue,
        TrafficMonitoringCoordinator coordinator)
    {
        _dispatcherQueue = dispatcherQueue;
        _coordinator = coordinator;
        _coordinator.SnapshotChanged += Coordinator_SnapshotChanged;
    }

    public event Action<NotificationAreaRealtimeMenuSnapshot>? SnapshotChanged;

    public NotificationAreaRealtimeMenuSnapshot CaptureSnapshot()
    {
        return _snapshot;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _coordinator.SnapshotChanged -= Coordinator_SnapshotChanged;
    }

    private void Coordinator_SnapshotChanged(TrafficMonitorSnapshot snapshot)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            ApplySnapshotIfCurrent(snapshot);
            return;
        }

        _ = _dispatcherQueue.TryEnqueue(() => ApplySnapshotIfCurrent(snapshot));
    }

    private void ApplySnapshotIfCurrent(TrafficMonitorSnapshot snapshot)
    {
        if (_disposed || !_coordinator.IsCurrentSession(snapshot.SessionGeneration))
        {
            return;
        }

        _snapshot = NotificationAreaRealtimeMenuSnapshot.Create(snapshot);
        SnapshotChanged?.Invoke(_snapshot);
    }
}
