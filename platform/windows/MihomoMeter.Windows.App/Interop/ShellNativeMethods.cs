using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.App.Interop;

internal static class ShellNativeMethods
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct NotifyIconData
    {
        public uint Size;
        public nint WindowHandle;
        public uint IconId;
        public uint Flags;
        public uint CallbackMessage;
        public nint IconHandle;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string ToolTip;

        public uint State;
        public uint StateMask;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string Info;

        public uint TimeoutOrVersion;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string InfoTitle;

        public uint InfoFlags;
        public Guid ItemGuid;
        public nint BalloonIconHandle;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct Point
    {
        public int X;
        public int Y;
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    internal delegate nint SubclassProcedure(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter,
        nuint subclassId,
        nuint referenceData);

    [DllImport("shell32.dll", EntryPoint = "Shell_NotifyIconW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ShellNotifyIcon(uint message, ref NotifyIconData data);

    [DllImport(
        "comctl32.dll",
        EntryPoint = "LoadIconWithScaleDown",
        CharSet = CharSet.Unicode,
        ExactSpelling = true)]
    internal static extern int LoadIconWithScaleDown(
        nint instanceHandle,
        string iconPath,
        int width,
        int height,
        out nint iconHandle);

    [DllImport("user32.dll")]
    internal static extern int GetSystemMetrics(int index);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyIcon(nint iconHandle);

    [DllImport("user32.dll", EntryPoint = "RegisterWindowMessageW", CharSet = CharSet.Unicode, SetLastError = true)]
    internal static extern uint RegisterWindowMessage(string messageName);

    [DllImport("comctl32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowSubclass(
        nint windowHandle,
        SubclassProcedure subclassProcedure,
        nuint subclassId,
        nuint referenceData);

    [DllImport("comctl32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool RemoveWindowSubclass(
        nint windowHandle,
        SubclassProcedure subclassProcedure,
        nuint subclassId);

    [DllImport("comctl32.dll")]
    internal static extern nint DefSubclassProc(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern nint CreatePopupMenu();

    [DllImport("user32.dll", EntryPoint = "AppendMenuW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool AppendMenu(
        nint menuHandle,
        uint flags,
        nuint itemId,
        string? itemText);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern uint TrackPopupMenuEx(
        nint menuHandle,
        uint flags,
        int x,
        int y,
        nint windowHandle,
        nint parameters);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyMenu(nint menuHandle);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetCursorPos(out Point point);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetForegroundWindow(nint windowHandle);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ShowWindow(nint windowHandle, int command);

    [DllImport("user32.dll", EntryPoint = "PostMessageW", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool PostMessage(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool AllowSetForegroundWindow(uint processId);
}
