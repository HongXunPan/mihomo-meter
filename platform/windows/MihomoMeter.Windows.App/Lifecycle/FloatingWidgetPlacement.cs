using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;

namespace MihomoMeter.Windows.App.Lifecycle;

internal readonly record struct FloatingWidgetPosition(int X, int Y);

internal static class FloatingWidgetPlacement
{
    private const uint MonitorDefaultToPrimary = 1;
    private const uint MonitorDefaultToNearest = 2;

    public static FloatingWidgetPosition ResolveInitialPosition(
        FloatingWidgetPosition? initialPosition,
        int size,
        uint dpi)
    {
        if (initialPosition is not null)
        {
            return ClampToWorkArea(initialPosition.Value, size);
        }

        var monitor = FloatingWidgetNativeMethods.MonitorFromPoint(
            new FloatingWidgetNativeMethods.Point(),
            MonitorDefaultToPrimary);
        var workArea = GetWorkArea(monitor);
        var margin = Scale(24, dpi);
        return new FloatingWidgetPosition(
            workArea.Right - size - margin,
            workArea.Bottom - size - margin);
    }

    public static FloatingWidgetPosition ClampToWorkArea(
        FloatingWidgetPosition position,
        int size)
    {
        var rectangle = new FloatingWidgetNativeMethods.Rect
        {
            Left = position.X,
            Top = position.Y,
            Right = position.X + size,
            Bottom = position.Y + size,
        };
        var monitor = FloatingWidgetNativeMethods.MonitorFromRect(
            ref rectangle,
            MonitorDefaultToNearest);
        var workArea = GetWorkArea(monitor);
        return new FloatingWidgetPosition(
            Math.Clamp(position.X, workArea.Left, Math.Max(workArea.Left, workArea.Right - size)),
            Math.Clamp(position.Y, workArea.Top, Math.Max(workArea.Top, workArea.Bottom - size)));
    }

    public static int Scale(int value, uint dpi)
    {
        return (int)Math.Round(value * Math.Max(dpi, 96u) / 96d);
    }

    private static FloatingWidgetNativeMethods.Rect GetWorkArea(nint monitor)
    {
        var monitorInfo = new FloatingWidgetNativeMethods.MonitorInfo
        {
            Size = (uint)Marshal.SizeOf<FloatingWidgetNativeMethods.MonitorInfo>(),
        };
        if (monitor == 0
            || !FloatingWidgetNativeMethods.GetMonitorInfo(monitor, ref monitorInfo))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        return monitorInfo.WorkRectangle;
    }
}
