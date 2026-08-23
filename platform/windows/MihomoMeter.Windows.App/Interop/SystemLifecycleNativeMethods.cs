using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.App.Interop;

internal static class SystemLifecycleNativeMethods
{
    internal const uint NotifyForThisSession = 0;

    [DllImport("wtsapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool WTSRegisterSessionNotification(
        nint windowHandle,
        uint flags);

    [DllImport("wtsapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool WTSUnRegisterSessionNotification(nint windowHandle);
}
