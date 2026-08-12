using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.Core.Application;

public enum SharedCoreTrafficRouteSource
{
    SharedPrimary,
    NativeFallback,
}

public enum SharedCoreTrafficRouteStatus
{
    Matched,
    Succeeded,
    AbiMismatch,
    NativeCallFailed,
    UnexpectedResult,
    Mismatch,
    UnknownFailure,
}

public readonly record struct SharedCoreTrafficRouteResult(
    string Text,
    SharedCoreTrafficRouteSource Source,
    SharedCoreTrafficShadowStatus Status);

public readonly record struct SharedCoreTrafficLazyRouteResult(
    string Text,
    SharedCoreTrafficRouteSource Source,
    SharedCoreTrafficRouteStatus Status);

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

    public static SharedCoreTrafficLazyRouteResult RouteLazy(
        ulong bytes,
        Func<string> nativeFallback,
        SharedCoreTrafficFormat format)
    {
        return RouteLazy(
            bytes,
            nativeFallback,
            format,
            () => MihomoMeterSharedCore.AbiVersion,
            MihomoMeterSharedCore.ScaleTraffic);
    }

    internal static SharedCoreTrafficLazyRouteResult RouteLazy(
        ulong bytes,
        Func<string> nativeFallback,
        SharedCoreTrafficFormat format,
        Func<uint> abiVersion,
        Func<ulong, SharedTrafficScale> scaleTraffic)
    {
        SharedCoreTrafficRouteStatus fallbackStatus;
        try
        {
            if (abiVersion() != 1)
            {
                fallbackStatus = SharedCoreTrafficRouteStatus.AbiMismatch;
            }
            else
            {
                var sharedText = SharedCoreTrafficDisplayFormatter.Format(
                    scaleTraffic(bytes),
                    format);
                return new SharedCoreTrafficLazyRouteResult(
                    sharedText,
                    SharedCoreTrafficRouteSource.SharedPrimary,
                    SharedCoreTrafficRouteStatus.Succeeded);
            }
        }
        catch (Exception exception) when (IsNativeCallFailure(exception))
        {
            fallbackStatus = SharedCoreTrafficRouteStatus.NativeCallFailed;
        }
        catch (InvalidOperationException)
        {
            fallbackStatus = SharedCoreTrafficRouteStatus.UnexpectedResult;
        }
        catch (Exception)
        {
            fallbackStatus = SharedCoreTrafficRouteStatus.UnknownFailure;
        }

        return LazyFallback(nativeFallback, fallbackStatus);
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

    private static SharedCoreTrafficLazyRouteResult LazyFallback(
        Func<string> nativeFallback,
        SharedCoreTrafficRouteStatus status)
    {
        return new SharedCoreTrafficLazyRouteResult(
            nativeFallback(),
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
