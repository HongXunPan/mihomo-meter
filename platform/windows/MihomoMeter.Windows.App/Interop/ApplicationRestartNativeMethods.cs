using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.App.Interop;

[Flags]
internal enum ApplicationRestartFlags : uint
{
    None = 0,
    NoCrash = 1,
    NoHang = 2,
    NoPatch = 4,
    NoReboot = 8,
}

internal static class ApplicationRestartNativeMethods
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    internal static extern int RegisterApplicationRestart(
        string commandLineArguments,
        ApplicationRestartFlags flags);

    [DllImport("kernel32.dll")]
    internal static extern int UnregisterApplicationRestart();
}
