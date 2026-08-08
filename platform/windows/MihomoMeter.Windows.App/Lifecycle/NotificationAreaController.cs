using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class NotificationAreaController : IDisposable
{
    private const uint NotifyIconAdd = 0;
    private const uint NotifyIconModify = 1;
    private const uint NotifyIconDelete = 2;
    private const uint NotifyIconSetFocus = 3;
    private const uint NotifyIconSetVersion = 4;
    private const uint NotifyIconFlagMessage = 0x00000001;
    private const uint NotifyIconFlagIcon = 0x00000002;
    private const uint NotifyIconFlagTip = 0x00000004;
    private const uint NotifyIconFlagGuid = 0x00000020;
    private const uint NotifyIconVersion4 = 4;
    private const uint NotificationCallbackMessage = 0x8000 + 0x51;
    private const uint WindowMessageContextMenu = 0x007B;
    private const uint WindowMessageLeftButtonDoubleClick = 0x0203;
    private const uint NotifyIconSelect = 0x0400;
    private const uint NotifyIconKeySelect = 0x0401;
    private const int DefaultApplicationIcon = 32512;
    private static readonly nuint WindowSubclassId = 0x4D4D4E41;

    private static readonly Guid NotificationIconGuid = new(
        "5AE0B778-B4DB-4F88-B176-914583E55D86");

    private readonly nint _windowHandle;
    private readonly Action _showWindow;
    private readonly Action _showStatisticsWorkspace;
    private readonly Action _showQuotaWorkspace;
    private readonly Action _toggleFloatingWidget;
    private readonly Func<bool> _isFloatingWidgetVisible;
    private readonly Func<NotificationAreaStatisticsMenuSnapshot> _captureStatisticsSnapshot;
    private readonly Func<NotificationAreaQuotaMenuSnapshot> _captureQuotaSnapshot;
    private readonly Action _startStatistics;
    private readonly Action<Guid> _stopStatistics;
    private readonly Action _refreshQuota;
    private readonly Action _exitApplication;
    private readonly ShellNativeMethods.SubclassProcedure _subclassProcedure;
    private readonly NotificationAreaMenu _menu;
    private readonly uint _taskbarCreatedMessage;
    private ShellNativeMethods.NotifyIconData _iconData;
    private string _toolTip = "Mihomo Meter · 未连接";
    private bool _iconAdded;
    private bool _disposed;

    public NotificationAreaController(
        nint windowHandle,
        Action showWindow,
        Action showStatisticsWorkspace,
        Action showQuotaWorkspace,
        Action toggleFloatingWidget,
        Func<bool> isFloatingWidgetVisible,
        Func<NotificationAreaStatisticsMenuSnapshot> captureStatisticsSnapshot,
        Func<NotificationAreaQuotaMenuSnapshot> captureQuotaSnapshot,
        Action startStatistics,
        Action<Guid> stopStatistics,
        Action refreshQuota,
        Action exitApplication)
    {
        if (windowHandle == 0)
        {
            throw new ArgumentException("通知区域控制器需要有效窗口句柄。", nameof(windowHandle));
        }

        _windowHandle = windowHandle;
        _showWindow = showWindow ?? throw new ArgumentNullException(nameof(showWindow));
        _showStatisticsWorkspace = showStatisticsWorkspace
            ?? throw new ArgumentNullException(nameof(showStatisticsWorkspace));
        _showQuotaWorkspace = showQuotaWorkspace
            ?? throw new ArgumentNullException(nameof(showQuotaWorkspace));
        _toggleFloatingWidget = toggleFloatingWidget
            ?? throw new ArgumentNullException(nameof(toggleFloatingWidget));
        _isFloatingWidgetVisible = isFloatingWidgetVisible
            ?? throw new ArgumentNullException(nameof(isFloatingWidgetVisible));
        _captureStatisticsSnapshot = captureStatisticsSnapshot
            ?? throw new ArgumentNullException(nameof(captureStatisticsSnapshot));
        _captureQuotaSnapshot = captureQuotaSnapshot
            ?? throw new ArgumentNullException(nameof(captureQuotaSnapshot));
        _startStatistics = startStatistics
            ?? throw new ArgumentNullException(nameof(startStatistics));
        _stopStatistics = stopStatistics
            ?? throw new ArgumentNullException(nameof(stopStatistics));
        _refreshQuota = refreshQuota ?? throw new ArgumentNullException(nameof(refreshQuota));
        _exitApplication = exitApplication ?? throw new ArgumentNullException(nameof(exitApplication));
        _subclassProcedure = WindowSubclassProcedure;
        _menu = new NotificationAreaMenu(windowHandle);
        _taskbarCreatedMessage = ShellNativeMethods.RegisterWindowMessage("TaskbarCreated");
        if (_taskbarCreatedMessage == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        if (!ShellNativeMethods.SetWindowSubclass(
                _windowHandle,
                _subclassProcedure,
                WindowSubclassId,
                0))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        try
        {
            AddIcon();
        }
        catch
        {
            ShellNativeMethods.RemoveWindowSubclass(
                _windowHandle,
                _subclassProcedure,
                WindowSubclassId);
            throw;
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        DeleteIcon();
        ShellNativeMethods.RemoveWindowSubclass(
            _windowHandle,
            _subclassProcedure,
            WindowSubclassId);
    }

    public void UpdateToolTip(string statusText)
    {
        if (_disposed || !_iconAdded)
        {
            return;
        }

        var normalizedStatus = string.IsNullOrWhiteSpace(statusText)
            ? "Mihomo Meter"
            : statusText.Trim();
        _toolTip = normalizedStatus.Length <= 127
            ? normalizedStatus
            : normalizedStatus[..127];
        _iconData.ToolTip = _toolTip;

        var originalFlags = _iconData.Flags;
        _iconData.Flags = NotifyIconFlagTip | (originalFlags & NotifyIconFlagGuid);
        if (!ShellNativeMethods.ShellNotifyIcon(NotifyIconModify, ref _iconData))
        {
            StartupConsoleReporter.Failure(
                "notification_area_tooltip",
                new Win32Exception(Marshal.GetLastWin32Error()));
        }

        _iconData.Flags = originalFlags;
    }

    private void AddIcon()
    {
        var iconHandle = ShellNativeMethods.LoadIcon(0, (nint)DefaultApplicationIcon);
        if (iconHandle == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        _iconData = new ShellNativeMethods.NotifyIconData
        {
            Size = (uint)Marshal.SizeOf<ShellNativeMethods.NotifyIconData>(),
            WindowHandle = _windowHandle,
            IconId = 1,
            Flags = NotifyIconFlagMessage
                | NotifyIconFlagIcon
                | NotifyIconFlagTip
                | NotifyIconFlagGuid,
            CallbackMessage = NotificationCallbackMessage,
            IconHandle = iconHandle,
            ToolTip = _toolTip,
            Info = string.Empty,
            InfoTitle = string.Empty,
            ItemGuid = NotificationIconGuid,
        };

        if (!ShellNativeMethods.ShellNotifyIcon(NotifyIconAdd, ref _iconData))
        {
            _iconData.Flags &= ~NotifyIconFlagGuid;
            _iconData.ItemGuid = Guid.Empty;
            if (!ShellNativeMethods.ShellNotifyIcon(NotifyIconAdd, ref _iconData))
            {
                throw new InvalidOperationException(
                    "Shell_NotifyIcon(NIM_ADD) 无法添加通知区域图标。");
            }
        }

        _iconAdded = true;
        _iconData.TimeoutOrVersion = NotifyIconVersion4;
        if (!ShellNativeMethods.ShellNotifyIcon(NotifyIconSetVersion, ref _iconData))
        {
            DeleteIcon();
            throw new InvalidOperationException(
                "Shell_NotifyIcon(NIM_SETVERSION) 无法设置通知区域图标版本。");
        }

        StartupConsoleReporter.Stage("notification_area_icon_added");
    }

    private void DeleteIcon()
    {
        if (!_iconAdded)
        {
            return;
        }

        ShellNativeMethods.ShellNotifyIcon(NotifyIconDelete, ref _iconData);
        _iconAdded = false;
        StartupConsoleReporter.Stage("notification_area_icon_removed");
    }

    private nint WindowSubclassProcedure(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter,
        nuint subclassId,
        nuint referenceData)
    {
        try
        {
            if (message == _taskbarCreatedMessage)
            {
                _iconAdded = false;
                AddIcon();
                return 0;
            }

            if (message == NotificationCallbackMessage)
            {
                HandleNotification(wordParameter, longParameter);
                return 0;
            }
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("notification_area_message", exception);
        }

        return ShellNativeMethods.DefSubclassProc(
            windowHandle,
            message,
            wordParameter,
            longParameter);
    }

    private void HandleNotification(nuint wordParameter, nint longParameter)
    {
        var notification = unchecked((uint)longParameter.ToInt64()) & 0xFFFF;
        switch (notification)
        {
            case WindowMessageContextMenu:
                ShowContextMenu(wordParameter);
                break;
            case NotifyIconSelect:
            case NotifyIconKeySelect:
            case WindowMessageLeftButtonDoubleClick:
                _showWindow();
                break;
        }
    }

    private void ShowContextMenu(nuint wordParameter)
    {
        var command = _menu.Show(
            ResolveMenuPoint(wordParameter),
            _isFloatingWidgetVisible(),
            _captureStatisticsSnapshot(),
            _captureQuotaSnapshot());
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
