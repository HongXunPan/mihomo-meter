using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.Core.Application;

public enum SharedCoreTrafficRouteSource
{
    SharedPrimary,
    NativeFallback,
}

public readonly record struct SharedCoreTrafficRouteResult(
    string Text,
    SharedCoreTrafficRouteSource Source,
    SharedCoreTrafficShadowStatus Status);

internal static class SharedCoreTrafficRouter
{
    public static SharedCoreTrafficRouteResult Route(
        ulong bytes,
        string nativeText,
        SharedCoreTrafficFormat format)
    {
        return Route(
            bytes,
            nativeText,
            format,
            () => MihomoMeterSharedCore.AbiVersion,
            MihomoMeterSharedCore.ScaleTraffic);
    }

    internal static SharedCoreTrafficRouteResult Route(
        ulong bytes,
        string nativeText,
        SharedCoreTrafficFormat format,
        Func<uint> abiVersion,
        Func<ulong, SharedTrafficScale> scaleTraffic)
    {
        try
        {
            if (abiVersion() != 1)
            {
                return Fallback(nativeText, SharedCoreTrafficShadowStatus.AbiMismatch);
            }

            var sharedText = SharedCoreTrafficDisplayFormatter.Format(
                scaleTraffic(bytes),
                format);
            return string.Equals(sharedText, nativeText, StringComparison.Ordinal)
                ? new SharedCoreTrafficRouteResult(
                    sharedText,
                    SharedCoreTrafficRouteSource.SharedPrimary,
                    SharedCoreTrafficShadowStatus.Matched)
                : Fallback(nativeText, SharedCoreTrafficShadowStatus.Mismatch);
        }
        catch (Exception exception) when (IsNativeCallFailure(exception))
        {
            return Fallback(nativeText, SharedCoreTrafficShadowStatus.NativeCallFailed);
        }
        catch (InvalidOperationException)
        {
            return Fallback(nativeText, SharedCoreTrafficShadowStatus.UnexpectedResult);
        }
        catch (Exception)
        {
            return Fallback(nativeText, SharedCoreTrafficShadowStatus.UnknownFailure);
        }
    }

    private static SharedCoreTrafficRouteResult Fallback(
        string nativeText,
        SharedCoreTrafficShadowStatus status)
    {
        return new SharedCoreTrafficRouteResult(
            nativeText,
            SharedCoreTrafficRouteSource.NativeFallback,
            status);
    }

    private static bool IsNativeCallFailure(Exception exception)
    {
        return exception is DllNotFoundException
            or EntryPointNotFoundException
            or BadImageFormatException
            or SEHException;
    }
}
