using MihomoMeter.Windows.App.Interop;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class FloatingWidgetIconSet : IDisposable
{
    private nint _iconOnLightHandle;
    private nint _iconOnDarkHandle;
    private bool _disposed;

    private FloatingWidgetIconSet(
        nint iconOnLightHandle,
        nint iconOnDarkHandle)
    {
        _iconOnLightHandle = iconOnLightHandle;
        _iconOnDarkHandle = iconOnDarkHandle;
    }

    public nint IconOnLightHandle => _iconOnLightHandle;
    public nint IconOnDarkHandle => _iconOnDarkHandle;

    public static FloatingWidgetIconSet Create(int size)
    {
        var iconOnLightHandle = WindowsIconAssets.CreateFloatingWidgetIcon(
            darkBackground: false,
            size: size);
        try
        {
            var iconOnDarkHandle = WindowsIconAssets.CreateFloatingWidgetIcon(
                darkBackground: true,
                size: size);
            return new FloatingWidgetIconSet(iconOnLightHandle, iconOnDarkHandle);
        }
        catch
        {
            ShellNativeMethods.DestroyIcon(iconOnLightHandle);
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
        DestroyIcon(ref _iconOnLightHandle);
        DestroyIcon(ref _iconOnDarkHandle);
    }

    private static void DestroyIcon(ref nint iconHandle)
    {
        if (iconHandle == 0)
        {
            return;
        }

        ShellNativeMethods.DestroyIcon(iconHandle);
        iconHandle = 0;
    }
}
