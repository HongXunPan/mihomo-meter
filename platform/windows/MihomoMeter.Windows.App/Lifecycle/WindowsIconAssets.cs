using System.Runtime.InteropServices;
using Microsoft.UI.Windowing;
using MihomoMeter.Windows.App.Interop;

namespace MihomoMeter.Windows.App.Lifecycle;

internal static class WindowsIconAssets
{
    private const string ApplicationIconFileName = "MihomoMeter.ico";
    private const string FloatingWidgetIconOnLightFileName =
        "MihomoMeter.StatusOnLight.ico";
    private const string FloatingWidgetIconOnDarkFileName =
        "MihomoMeter.StatusOnDark.ico";

    public static void ApplyApplicationIcon(AppWindow appWindow)
    {
        ArgumentNullException.ThrowIfNull(appWindow);
        appWindow.SetIcon(ResolveAssetPath(ApplicationIconFileName));
    }

    public static nint CreateApplicationIcon(int width, int height)
    {
        return CreateIcon(ApplicationIconFileName, width, height);
    }

    public static nint CreateFloatingWidgetIcon(bool darkBackground, int size)
    {
        return CreateIcon(
            darkBackground
                ? FloatingWidgetIconOnDarkFileName
                : FloatingWidgetIconOnLightFileName,
            size,
            size);
    }

    private static nint CreateIcon(string fileName, int width, int height)
    {
        var result = ShellNativeMethods.LoadIconWithScaleDown(
            0,
            ResolveAssetPath(fileName),
            width,
            height,
            out var iconHandle);
        Marshal.ThrowExceptionForHR(result);
        return iconHandle != 0
            ? iconHandle
            : throw new InvalidOperationException($"无法加载 Windows 图标资源：{fileName}");
    }

    private static string ResolveAssetPath(string fileName)
    {
        var path = Path.GetFullPath(
            Path.Combine(AppContext.BaseDirectory, "Assets", fileName));
        return File.Exists(path)
            ? path
            : throw new FileNotFoundException("找不到 Windows 图标资源。", path);
    }
}
