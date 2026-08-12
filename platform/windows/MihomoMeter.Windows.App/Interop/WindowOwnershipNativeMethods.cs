using System.ComponentModel;
using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.App.Interop;

internal static class WindowOwnershipNativeMethods
{
    private const int OwnerWindowIndex = -8;

    public static void SetOwner(nint windowHandle, nint ownerWindowHandle)
    {
        if (windowHandle == nint.Zero)
        {
            throw new ArgumentException("窗口句柄不能为空。", nameof(windowHandle));
        }
        if (ownerWindowHandle == nint.Zero)
        {
            throw new ArgumentException("Owner 窗口句柄不能为空。", nameof(ownerWindowHandle));
        }

        Marshal.SetLastPInvokeError(0);
        var previousOwner = SetWindowLongPtr(
            windowHandle,
            OwnerWindowIndex,
            ownerWindowHandle);
        var errorCode = Marshal.GetLastPInvokeError();
        if (previousOwner == nint.Zero && errorCode != 0)
        {
            throw new Win32Exception(errorCode, "无法设置窗口 Owner。");
        }
    }

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    private static extern nint SetWindowLongPtr(
        nint windowHandle,
        int index,
        nint newValue);
}
