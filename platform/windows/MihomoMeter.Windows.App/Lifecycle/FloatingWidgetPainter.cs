using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;

namespace MihomoMeter.Windows.App.Lifecycle;

internal static class FloatingWidgetPainter
{
    private const int TransparentBackground = 1;
    private const int SolidPen = 0;
    private const uint DrawTextRight = 0x0002;
    private const uint DrawTextVerticalCenter = 0x0004;
    private const uint DrawTextSingleLine = 0x0020;
    private const uint DrawTextNoPrefix = 0x0800;
    private const uint DrawIconNormal = 0x0003;
    private const int SystemColorWindow = 5;
    private const int SystemColorWindowFrame = 6;
    private const int SystemColorWindowText = 8;
    private const int LogicalPadding = 6;
    private const int LogicalIconSize = 28;
    private const int LogicalIconTextSpacing = 4;
    private const int LogicalFontSize = 10;

    public static void ApplyRoundRegion(
        nint windowHandle,
        FloatingWidgetSize size)
    {
        var region = FloatingWidgetNativeMethods.CreateRoundRectRgn(
            0,
            0,
            size.Width + 1,
            size.Height + 1,
            size.Height,
            size.Height);
        if (region == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        if (FloatingWidgetNativeMethods.SetWindowRgn(windowHandle, region, true) == 0)
        {
            FloatingWidgetNativeMethods.DeleteObject(region);
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    public static void Paint(
        nint windowHandle,
        FloatingWidgetSize size,
        nint iconOnLightHandle,
        nint iconOnDarkHandle,
        FloatingWidgetDisplaySnapshot snapshot)
    {
        var deviceContext = FloatingWidgetNativeMethods.BeginPaint(windowHandle, out var paint);
        if (deviceContext == 0)
        {
            return;
        }

        try
        {
            var backgroundColor = FloatingWidgetNativeMethods.GetSysColor(SystemColorWindow);
            var foregroundColor = FloatingWidgetNativeMethods.GetSysColor(SystemColorWindowText);
            PaintBackground(deviceContext, size, backgroundColor);
            PaintIcon(
                deviceContext,
                windowHandle,
                size,
                IsDarkColor(backgroundColor) ? iconOnDarkHandle : iconOnLightHandle);
            PaintRates(
                deviceContext,
                windowHandle,
                size,
                foregroundColor,
                snapshot);
        }
        finally
        {
            FloatingWidgetNativeMethods.EndPaint(windowHandle, ref paint);
        }
    }

    private static void PaintBackground(
        nint deviceContext,
        FloatingWidgetSize size,
        uint backgroundColor)
    {
        var brush = FloatingWidgetNativeMethods.CreateSolidBrush(backgroundColor);
        var pen = FloatingWidgetNativeMethods.CreatePen(
            SolidPen,
            1,
            FloatingWidgetNativeMethods.GetSysColor(SystemColorWindowFrame));
        if (brush == 0 || pen == 0)
        {
            var error = Marshal.GetLastWin32Error();
            DeleteObject(brush);
            DeleteObject(pen);
            throw new Win32Exception(error);
        }

        var oldBrush = FloatingWidgetNativeMethods.SelectObject(deviceContext, brush);
        var oldPen = FloatingWidgetNativeMethods.SelectObject(deviceContext, pen);
        FloatingWidgetNativeMethods.RoundRect(
            deviceContext,
            0,
            0,
            size.Width,
            size.Height,
            size.Height,
            size.Height);
        FloatingWidgetNativeMethods.SelectObject(deviceContext, oldPen);
        FloatingWidgetNativeMethods.SelectObject(deviceContext, oldBrush);
        FloatingWidgetNativeMethods.DeleteObject(pen);
        FloatingWidgetNativeMethods.DeleteObject(brush);
    }

    private static void PaintIcon(
        nint deviceContext,
        nint windowHandle,
        FloatingWidgetSize size,
        nint iconHandle)
    {
        var dpi = FloatingWidgetNativeMethods.GetDpiForWindow(windowHandle);
        var padding = FloatingWidgetPlacement.Scale(LogicalPadding, dpi);
        var iconSize = FloatingWidgetPlacement.Scale(LogicalIconSize, dpi);
        var top = Math.Max(0, (size.Height - iconSize) / 2);
        if (!FloatingWidgetNativeMethods.DrawIconEx(
                deviceContext,
                padding,
                top,
                iconHandle,
                iconSize,
                iconSize,
                0,
                0,
                DrawIconNormal))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private static void PaintRates(
        nint deviceContext,
        nint windowHandle,
        FloatingWidgetSize size,
        uint foregroundColor,
        FloatingWidgetDisplaySnapshot snapshot)
    {
        var dpi = FloatingWidgetNativeMethods.GetDpiForWindow(windowHandle);
        var font = FloatingWidgetNativeMethods.CreateFont(
            -FloatingWidgetPlacement.Scale(LogicalFontSize, dpi),
            0,
            0,
            0,
            600,
            0,
            0,
            0,
            1,
            0,
            0,
            5,
            0,
            "Segoe UI");
        if (font == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        var padding = FloatingWidgetPlacement.Scale(LogicalPadding, dpi);
        var textLeft = padding
            + FloatingWidgetPlacement.Scale(
                LogicalIconSize + LogicalIconTextSpacing,
                dpi);
        var oldFont = FloatingWidgetNativeMethods.SelectObject(deviceContext, font);
        FloatingWidgetNativeMethods.SetBkMode(deviceContext, TransparentBackground);
        FloatingWidgetNativeMethods.SetTextColor(deviceContext, foregroundColor);
        var firstLine = new FloatingWidgetNativeMethods.Rect
        {
            Left = textLeft,
            Top = padding / 2,
            Right = size.Width - padding,
            Bottom = size.Height / 2,
        };
        FloatingWidgetNativeMethods.DrawText(
            deviceContext,
            snapshot.FirstLine,
            snapshot.FirstLine.Length,
            ref firstLine,
            DrawTextRight | DrawTextVerticalCenter | DrawTextSingleLine | DrawTextNoPrefix);
        var secondLine = new FloatingWidgetNativeMethods.Rect
        {
            Left = textLeft,
            Top = size.Height / 2,
            Right = size.Width - padding,
            Bottom = size.Height - padding / 2,
        };
        FloatingWidgetNativeMethods.DrawText(
            deviceContext,
            snapshot.SecondLine,
            snapshot.SecondLine.Length,
            ref secondLine,
            DrawTextRight | DrawTextVerticalCenter | DrawTextSingleLine | DrawTextNoPrefix);
        FloatingWidgetNativeMethods.SelectObject(deviceContext, oldFont);
        FloatingWidgetNativeMethods.DeleteObject(font);
    }

    private static bool IsDarkColor(uint color)
    {
        var red = color & 0xFF;
        var green = (color >> 8) & 0xFF;
        var blue = (color >> 16) & 0xFF;
        return red * 299 + green * 587 + blue * 114 < 128_000;
    }

    private static void DeleteObject(nint objectHandle)
    {
        if (objectHandle != 0)
        {
            FloatingWidgetNativeMethods.DeleteObject(objectHandle);
        }
    }
}
