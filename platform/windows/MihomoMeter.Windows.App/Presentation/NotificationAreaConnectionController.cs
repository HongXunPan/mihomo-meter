using Microsoft.UI.Dispatching;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal sealed record NotificationAreaConnectionSlotSnapshot(
    string Title,
    string RateText,
    string CumulativeText);

internal sealed record NotificationAreaConnectionRouteSnapshot(
    int ActiveCount,
    IReadOnlyList<NotificationAreaConnectionSlotSnapshot?> Slots);

internal sealed record NotificationAreaConnectionsMenuSnapshot(
    NotificationAreaConnectionRouteSnapshot Proxy,
    NotificationAreaConnectionRouteSnapshot Direct);

internal sealed class NotificationAreaConnectionController : IDisposable
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly TrafficMonitoringCoordinator _monitoring;
    private TrafficMonitorSnapshot _snapshot = TrafficMonitorSnapshot.Disconnected;
    private bool _disposed;

    public NotificationAreaConnectionController(
        DispatcherQueue dispatcherQueue,
        TrafficMonitoringCoordinator monitoring)
    {
        _dispatcherQueue = dispatcherQueue;
        _monitoring = monitoring;
        _monitoring.SnapshotChanged += Monitoring_SnapshotChanged;
    }

    public NotificationAreaConnectionsMenuSnapshot CaptureSnapshot()
    {
        return new NotificationAreaConnectionsMenuSnapshot(
            CreateRouteSnapshot(_snapshot.LiveProxyConnections),
            CreateRouteSnapshot(_snapshot.LiveDirectConnections));
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _monitoring.SnapshotChanged -= Monitoring_SnapshotChanged;
    }

    private void Monitoring_SnapshotChanged(TrafficMonitorSnapshot snapshot)
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
        if (!_disposed && _monitoring.IsCurrentSession(snapshot.SessionGeneration))
        {
            _snapshot = snapshot;
        }
    }

    private static NotificationAreaConnectionRouteSnapshot CreateRouteSnapshot(
        IReadOnlyList<LiveTrafficConnection> connections)
    {
        var slots = LiveConnectionProjection.TopSlots(connections)
            .Select(connection => connection is null ? null : CreateSlot(connection))
            .ToArray();
        return new NotificationAreaConnectionRouteSnapshot(
            connections.Count(connection => connection.TotalBytesPerSecond > 0),
            Array.AsReadOnly(slots));
    }

    private static NotificationAreaConnectionSlotSnapshot CreateSlot(
        LiveTrafficConnection connection)
    {
        var hostname = LiveConnectionProjection.Hostname(connection);
        var application = LiveConnectionProjection.ApplicationName(connection);
        return new NotificationAreaConnectionSlotSnapshot(
            $"{hostname} · {application}",
            TrafficDisplayFormatter.Rate(connection.Rate),
            $"累计 {TrafficDisplayFormatter.ByteCount(connection.CumulativeBytes.Total)}");
    }
}
