using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;

namespace MihomoMeter.Windows.App.Lifecycle;

internal enum NotificationAreaCommandKind
{
    None,
    Open,
    OpenStatistics,
    OpenLiveConnections,
    OpenQuota,
    OpenConnectionAnalytics,
    OpenSettings,
    CheckUpdates,
    StartStatistics,
    StopStatistics,
    RefreshQuota,
    ToggleFloatingWidget,
    Exit,
}

internal readonly record struct NotificationAreaCommand(
    NotificationAreaCommandKind Kind,
    Guid? IntervalId = null,
    MihomoMeter.Windows.Core.Application.LiveConnectionRoute? Route = null);

internal sealed partial class NotificationAreaMenu
{
    private const uint MenuFlagString = 0x0000;
    private const uint MenuFlagGrayed = 0x0001;
    private const uint MenuFlagChecked = 0x0008;
    private const uint MenuFlagPopup = 0x0010;
    private const uint MenuFlagSeparator = 0x0800;
    private const uint TrackMenuRightButton = 0x0002;
    private const uint TrackMenuReturnCommand = 0x0100;
    private const uint TrackMenuNoNotify = 0x0080;
    private const uint WindowMessageNull = 0x0000;
    private readonly nint _windowHandle;

    public NotificationAreaMenu(nint windowHandle)
    {
        _windowHandle = windowHandle;
    }

    public NotificationAreaCommand Show(
        ShellNativeMethods.Point point,
        bool floatingWidgetVisible,
        NotificationAreaStatisticsMenuSnapshot statisticsSnapshot,
        NotificationAreaQuotaMenuSnapshot quotaSnapshot,
        NotificationAreaConnectionsMenuSnapshot connectionsSnapshot,
        NotificationAreaRealtimeMenuSnapshot realtimeSnapshot)
    {
        var menuHandle = CreateMenu();
        var commands = new Dictionary<uint, NotificationAreaCommand>();
        try
        {
            AppendMenuItem(menuHandle, 0, realtimeSnapshot.StateText, isEnabled: false);
            AppendMenuItem(menuHandle, 0, realtimeSnapshot.ProxyRateText, isEnabled: false);
            AppendMenuItem(menuHandle, 0, realtimeSnapshot.CoverageText, isEnabled: false);
            AppendSeparator(menuHandle);
            AppendMenuItem(menuHandle, OpenCommand, "打开 Mihomo Meter");
            RegisterCommand(
                commands,
                OpenCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.Open));
            AppendRealtimeMenus(menuHandle, realtimeSnapshot);
            AppendConnectionsMenu(menuHandle, connectionsSnapshot, commands);
            AppendStatisticsMenu(menuHandle, statisticsSnapshot, commands);
            AppendQuotaMenu(menuHandle, quotaSnapshot, commands);
            AppendMenuItem(
                menuHandle,
                ToggleFloatingWidgetCommand,
                floatingWidgetVisible ? "关闭悬浮图标" : "显示悬浮图标",
                isChecked: floatingWidgetVisible);
            RegisterCommand(
                commands,
                ToggleFloatingWidgetCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.ToggleFloatingWidget));
            AppendSeparator(menuHandle);
            AppendMenuItem(menuHandle, OpenConnectionAnalyticsCommand, "连接分析…");
            RegisterCommand(
                commands,
                OpenConnectionAnalyticsCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.OpenConnectionAnalytics));
            AppendMenuItem(menuHandle, OpenSettingsCommand, "设置…");
            RegisterCommand(
                commands,
                OpenSettingsCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.OpenSettings));
            AppendMenuItem(menuHandle, CheckUpdatesCommand, "检查更新…");
            RegisterCommand(
                commands,
                CheckUpdatesCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.CheckUpdates));
            AppendSeparator(menuHandle);
            AppendMenuItem(menuHandle, ExitCommand, "退出 Mihomo Meter");
            RegisterCommand(
                commands,
                ExitCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.Exit));

            ShellNativeMethods.SetForegroundWindow(_windowHandle);
            var selectedCommand = ShellNativeMethods.TrackPopupMenuEx(
                menuHandle,
                TrackMenuRightButton | TrackMenuReturnCommand | TrackMenuNoNotify,
                point.X,
                point.Y,
                _windowHandle,
                0);
            ShellNativeMethods.PostMessage(_windowHandle, WindowMessageNull, 0, 0);
            return commands.TryGetValue(selectedCommand, out var command)
                ? command
                : default;
        }
        finally
        {
            ShellNativeMethods.DestroyMenu(menuHandle);
        }
    }

    private static nint CreateMenu()
    {
        var menuHandle = ShellNativeMethods.CreatePopupMenu();
        return menuHandle != 0
            ? menuHandle
            : throw new Win32Exception(Marshal.GetLastWin32Error());
    }

    private static void AppendMenuItem(
        nint menuHandle,
        uint command,
        string text,
        bool isEnabled = true,
        bool isChecked = false)
    {
        var flags = MenuFlagString
            | (isEnabled ? 0 : MenuFlagGrayed)
            | (isChecked ? MenuFlagChecked : 0);
        if (!ShellNativeMethods.AppendMenu(
                menuHandle,
                flags,
                command,
                EscapeMenuText(text)))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private static void AppendPopupMenuItem(
        nint menuHandle,
        nint submenuHandle,
        string text)
    {
        if (!ShellNativeMethods.AppendMenu(
                menuHandle,
                MenuFlagString | MenuFlagPopup,
                unchecked((nuint)submenuHandle),
                EscapeMenuText(text)))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private static void AppendSeparator(nint menuHandle)
    {
        if (!ShellNativeMethods.AppendMenu(menuHandle, MenuFlagSeparator, 0, null))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private static string EscapeMenuText(string text)
    {
        return text.Replace("&", "&&", StringComparison.Ordinal);
    }
}
