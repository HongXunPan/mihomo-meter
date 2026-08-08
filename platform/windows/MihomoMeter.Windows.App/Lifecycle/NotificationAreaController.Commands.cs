using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed partial class NotificationAreaController
{
    private void ShowContextMenu(nuint wordParameter)
    {
        var command = _menu.Show(
            ResolveMenuPoint(wordParameter),
            _isFloatingWidgetVisible(),
            _captureStatisticsSnapshot(),
            _captureQuotaSnapshot(),
            _captureConnectionsSnapshot());
        switch (command.Kind)
        {
            case NotificationAreaCommandKind.Open:
                _showWindow();
                break;
            case NotificationAreaCommandKind.OpenStatistics:
                _showStatisticsWorkspace();
                break;
            case NotificationAreaCommandKind.OpenQuota:
                _showQuotaWorkspace();
                break;
            case NotificationAreaCommandKind.OpenLiveConnections
                when command.Route is LiveConnectionRoute route:
                _showLiveConnectionsWorkspace(route);
                break;
            case NotificationAreaCommandKind.StartStatistics:
                _startStatistics();
                break;
            case NotificationAreaCommandKind.StopStatistics
                when command.IntervalId is Guid intervalId:
                _stopStatistics(intervalId);
                break;
            case NotificationAreaCommandKind.RefreshQuota:
                _refreshQuota();
                break;
            case NotificationAreaCommandKind.ToggleFloatingWidget:
                _toggleFloatingWidget();
                break;
            case NotificationAreaCommandKind.Exit:
                _exitApplication();
                break;
        }

        ShellNativeMethods.ShellNotifyIcon(NotifyIconSetFocus, ref _iconData);
    }

    private static ShellNativeMethods.Point ResolveMenuPoint(nuint wordParameter)
    {
        var packed = unchecked((long)wordParameter);
        var point = new ShellNativeMethods.Point
        {
            X = unchecked((short)(packed & 0xFFFF)),
            Y = unchecked((short)((packed >> 16) & 0xFFFF)),
        };
        if ((point.X != -1 || point.Y != -1)
            || ShellNativeMethods.GetCursorPos(out point))
        {
            return point;
        }

        throw new Win32Exception(Marshal.GetLastWin32Error());
    }
}
