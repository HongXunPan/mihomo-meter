using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;

namespace MihomoMeter.Windows.App.Lifecycle;

internal static class FloatingWidgetPainter
{
    private const int NullPen = 8;
    private const int TransparentBackground = 1;
    private const uint DrawTextCenter = 0x0001;
    private const uint DrawTextVerticalCenter = 0x0004;
    private const uint DrawTextSingleLine = 0x0020;
    private const uint DrawTextNoPrefix = 0x0800;
    private const uint BackgroundColor = 0x00FF8426;
    private const uint ForegroundColor = 0x00FFFFFF;

    public static void ApplyRoundRegion(nint windowHandle, int size)
    {
        var region = FloatingWidgetNativeMethods.CreateEllipticRgn(0, 0, size + 1, size + 1);
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

    public static void Paint(nint windowHandle, int size)
    {
        var deviceContext = FloatingWidgetNativeMethods.BeginPaint(windowHandle, out var paint);
        if (deviceContext == 0)
        {
            return;
        }

        try
        {
            PaintBackground(deviceContext, size);
            PaintGlyph(deviceContext, windowHandle, size);
        }
        finally
        {
            FloatingWidgetNativeMethods.EndPaint(windowHandle, ref paint);
        }
    }

    private static void PaintBackground(nint deviceContext, int size)
    {
        var brush = FloatingWidgetNativeMethods.CreateSolidBrush(BackgroundColor);
        if (brush == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        var oldBrush = FloatingWidgetNativeMethods.SelectObject(deviceContext, brush);
        var oldPen = FloatingWidgetNativeMethods.SelectObject(
            deviceContext,
            FloatingWidgetNativeMethods.GetStockObject(NullPen));
        FloatingWidgetNativeMethods.Ellipse(deviceContext, 0, 0, size, size);
        FloatingWidgetNativeMethods.SelectObject(deviceContext, oldPen);
        FloatingWidgetNativeMethods.SelectObject(deviceContext, oldBrush);
        FloatingWidgetNativeMethods.DeleteObject(brush);
    }

    private static void PaintGlyph(nint deviceContext, nint windowHandle, int size)
    {
        var dpi = FloatingWidgetNativeMethods.GetDpiForWindow(windowHandle);
        var font = FloatingWidgetNativeMethods.CreateFont(
            -FloatingWidgetPlacement.Scale(22, dpi),
            0,
            0,
            0,
            700,
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

        var oldFont = FloatingWidgetNativeMethods.SelectObject(deviceContext, font);
        FloatingWidgetNativeMethods.SetBkMode(deviceContext, TransparentBackground);
        FloatingWidgetNativeMethods.SetTextColor(deviceContext, ForegroundColor);
        var rectangle = new FloatingWidgetNativeMethods.Rect
        {
            Right = size,
            Bottom = size,
        };
        FloatingWidgetNativeMethods.DrawText(
            deviceContext,
            "M",
            1,
            ref rectangle,
            DrawTextCenter | DrawTextVerticalCenter | DrawTextSingleLine | DrawTextNoPrefix);
        FloatingWidgetNativeMethods.SelectObject(deviceContext, oldFont);
        FloatingWidgetNativeMethods.DeleteObject(font);
    }
}
