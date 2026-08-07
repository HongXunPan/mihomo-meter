using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;

namespace MihomoMeter.Windows.App.Lifecycle;

internal enum NotificationAreaCommand
{
    None,
    Open,
    ToggleFloatingWidget,
    Exit,
}

internal sealed class NotificationAreaMenu
{
    private const uint MenuFlagString = 0x0000;
    private const uint MenuFlagChecked = 0x0008;
    private const uint MenuFlagSeparator = 0x0800;
    private const uint TrackMenuRightButton = 0x0002;
    private const uint TrackMenuReturnCommand = 0x0100;
    private const uint TrackMenuNoNotify = 0x0080;
    private const uint WindowMessageNull = 0x0000;
    private const uint OpenCommand = 1001;
    private const uint ToggleFloatingWidgetCommand = 1002;
    private const uint ExitCommand = 1003;

    private readonly nint _windowHandle;

    public NotificationAreaMenu(nint windowHandle)
    {
        _windowHandle = windowHandle;
    }

    public NotificationAreaCommand Show(ShellNativeMethods.Point point, bool floatingWidgetVisible)
    {
        var menuHandle = ShellNativeMethods.CreatePopupMenu();
        if (menuHandle == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        try
        {
            AppendMenuItem(menuHandle, OpenCommand, "打开 Mihomo Meter");
            AppendMenuItem(
                menuHandle,
                ToggleFloatingWidgetCommand,
                floatingWidgetVisible ? "关闭悬浮图标" : "显示悬浮图标",
                floatingWidgetVisible);
            AppendSeparator(menuHandle);
            AppendMenuItem(menuHandle, ExitCommand, "退出 Mihomo Meter");
            ShellNativeMethods.SetForegroundWindow(_windowHandle);
            var command = ShellNativeMethods.TrackPopupMenuEx(
                menuHandle,
                TrackMenuRightButton | TrackMenuReturnCommand | TrackMenuNoNotify,
                point.X,
                point.Y,
                _windowHandle,
                0);
            ShellNativeMethods.PostMessage(_windowHandle, WindowMessageNull, 0, 0);
            return command switch
            {
                OpenCommand => NotificationAreaCommand.Open,
                ToggleFloatingWidgetCommand => NotificationAreaCommand.ToggleFloatingWidget,
                ExitCommand => NotificationAreaCommand.Exit,
                _ => NotificationAreaCommand.None,
            };
        }
        finally
        {
            ShellNativeMethods.DestroyMenu(menuHandle);
        }
    }

    private static void AppendMenuItem(
        nint menuHandle,
        uint command,
        string text,
        bool isChecked = false)
    {
        var flags = MenuFlagString | (isChecked ? MenuFlagChecked : 0);
        if (!ShellNativeMethods.AppendMenu(menuHandle, flags, command, text))
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
}
