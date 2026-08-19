using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.App.Interop;

internal static class FloatingWidgetNativeMethods
{
    [StructLayout(LayoutKind.Sequential)]
    internal struct Point
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct WindowClass
    {
        public uint Size;
        public uint Style;
        public WindowProcedure WindowProcedure;
        public int ClassExtraBytes;
        public int WindowExtraBytes;
        public nint InstanceHandle;
        public nint IconHandle;
        public nint CursorHandle;
        public nint BackgroundBrush;
        public string? MenuName;
        public string ClassName;
        public nint SmallIconHandle;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct PaintStruct
    {
        public nint DeviceContext;
        public int EraseBackground;
        public Rect PaintRectangle;
        public int Restore;
        public int UpdateInc;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public byte[] Reserved;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct MonitorInfo
    {
        public uint Size;
        public Rect MonitorRectangle;
        public Rect WorkRectangle;
        public uint Flags;
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    internal delegate nint WindowProcedure(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter);

    [DllImport("kernel32.dll", EntryPoint = "GetModuleHandleW", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern nint GetModuleHandle(string? moduleName);

    [DllImport("user32.dll", EntryPoint = "RegisterClassExW", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern ushort RegisterClassEx(ref WindowClass windowClass);

    [DllImport("user32.dll", EntryPoint = "UnregisterClassW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UnregisterClass(string className, nint instanceHandle);

    [DllImport("user32.dll", EntryPoint = "CreateWindowExW", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern nint CreateWindowEx(
        uint extendedStyle,
        string className,
        string windowName,
        uint style,
        int x,
        int y,
        int width,
        int height,
        nint parentWindow,
        nint menuHandle,
        nint instanceHandle,
        nint parameter);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyWindow(nint windowHandle);

    [DllImport("user32.dll", EntryPoint = "SetWindowTextW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowText(nint windowHandle, string text);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool InvalidateRect(
        nint windowHandle,
        nint rectangle,
        [MarshalAs(UnmanagedType.Bool)] bool erase);

    [DllImport("user32.dll")]
    internal static extern uint GetSysColor(int colorIndex);

    [DllImport("user32.dll", EntryPoint = "DefWindowProcW")]
    internal static extern nint DefWindowProc(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowPos(
        nint windowHandle,
        nint insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetWindowRect(nint windowHandle, out Rect rectangle);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetCursorPos(out Point point);

    [DllImport("user32.dll")]
    internal static extern nint SetCapture(nint windowHandle);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    internal static extern uint GetDpiForWindow(nint windowHandle);

    [DllImport("user32.dll")]
    internal static extern uint GetDpiForSystem();

    [DllImport("user32.dll")]
    internal static extern nint MonitorFromPoint(Point point, uint flags);

    [DllImport("user32.dll")]
    internal static extern nint MonitorFromRect(ref Rect rectangle, uint flags);

    [DllImport("user32.dll", EntryPoint = "GetMonitorInfoW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetMonitorInfo(nint monitorHandle, ref MonitorInfo monitorInfo);

    [DllImport("user32.dll", EntryPoint = "LoadCursorW", SetLastError = true)]
    internal static extern nint LoadCursor(nint instanceHandle, nint cursorName);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern nint BeginPaint(nint windowHandle, out PaintStruct paint);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool EndPaint(nint windowHandle, ref PaintStruct paint);

    [DllImport("gdi32.dll", SetLastError = true)]
    internal static extern nint CreateRoundRectRgn(
        int left,
        int top,
        int right,
        int bottom,
        int ellipseWidth,
        int ellipseHeight);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern int SetWindowRgn(nint windowHandle, nint regionHandle, bool redraw);

    [DllImport("gdi32.dll")]
    internal static extern nint CreateSolidBrush(uint color);

    [DllImport("gdi32.dll")]
    internal static extern nint CreatePen(int style, int width, uint color);

    [DllImport("gdi32.dll", EntryPoint = "CreateFontW", CharSet = CharSet.Unicode)]
    internal static extern nint CreateFont(
        int height,
        int width,
        int escapement,
        int orientation,
        int weight,
        uint italic,
        uint underline,
        uint strikeOut,
        uint charSet,
        uint outputPrecision,
        uint clipPrecision,
        uint quality,
        uint pitchAndFamily,
        string faceName);

    [DllImport("gdi32.dll")]
    internal static extern nint SelectObject(nint deviceContext, nint objectHandle);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DeleteObject(nint objectHandle);

    [DllImport("gdi32.dll")]
    internal static extern uint SetTextColor(nint deviceContext, uint color);

    [DllImport("gdi32.dll")]
    internal static extern int SetBkMode(nint deviceContext, int mode);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool RoundRect(
        nint deviceContext,
        int left,
        int top,
        int right,
        int bottom,
        int ellipseWidth,
        int ellipseHeight);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DrawIconEx(
        nint deviceContext,
        int x,
        int y,
        nint iconHandle,
        int width,
        int height,
        uint animationStep,
        nint flickerFreeBrush,
        uint flags);

    [DllImport("user32.dll", EntryPoint = "DrawTextW", CharSet = CharSet.Unicode)]
    internal static extern int DrawText(
        nint deviceContext,
        string text,
        int textLength,
        ref Rect rectangle,
        uint format);
}
