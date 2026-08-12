using System.Runtime.InteropServices;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum SharedCoreProxyTypeRouteSource
{
    SharedPrimary,
    NativeFallback,
}

public enum SharedCoreProxyTypeRouteStatus
{
    Matched,
    Unrecognized,
    AbiMismatch,
    NativeCallFailed,
    UnsupportedInput,
    InputTooLong,
    UnexpectedResult,
    Mismatch,
    UnknownFailure,
}

public readonly record struct SharedCoreProxyTypeRouteResult(
    ProxyClassification Classification,
    SharedCoreProxyTypeRouteSource Source,
    SharedCoreProxyTypeRouteStatus Status);

internal static class SharedCoreProxyTypeRouter
{
    public static SharedCoreProxyTypeRouteResult Route(
        string rawType,
        ProxyClassification nativeClassification)
    {
        return Route(rawType, nativeClassification, MihomoMeterSharedCore.ClassifyProxyType);
    }

    internal static SharedCoreProxyTypeRouteResult Route(
        string rawType,
        ProxyClassification nativeClassification,
        Func<string, SharedProxyTypeClassification> classifyProxyType)
    {
        try
        {
            var sharedClassification = classifyProxyType(rawType);
            var candidate = PlatformClassification(sharedClassification);
            if (candidate is null)
            {
                var expectedUnknown = new ProxyClassification(
                    TrafficCategory.Unknown,
                    UnknownTrafficReason.AmbiguousProxyType);
                var status = nativeClassification == expectedUnknown
                    ? SharedCoreProxyTypeRouteStatus.Unrecognized
                    : SharedCoreProxyTypeRouteStatus.Mismatch;
                return Fallback(nativeClassification, status);
            }

            return candidate == nativeClassification
                ? new SharedCoreProxyTypeRouteResult(
                    candidate,
                    SharedCoreProxyTypeRouteSource.SharedPrimary,
                    SharedCoreProxyTypeRouteStatus.Matched)
                : Fallback(nativeClassification, SharedCoreProxyTypeRouteStatus.Mismatch);
        }
        catch (SharedProxyTypeAdapterException exception)
        {
            return Fallback(nativeClassification, Status(exception.Failure));
        }
        catch (Exception exception) when (IsNativeCallFailure(exception))
        {
            return Fallback(
                nativeClassification,
                SharedCoreProxyTypeRouteStatus.NativeCallFailed);
        }
        catch (Exception)
        {
            return Fallback(nativeClassification, SharedCoreProxyTypeRouteStatus.UnknownFailure);
        }
    }

    private static ProxyClassification? PlatformClassification(
        SharedProxyTypeClassification sharedClassification)
    {
        return sharedClassification switch
        {
            SharedProxyTypeClassification.Unrecognized => null,
            SharedProxyTypeClassification.Proxy => new ProxyClassification(TrafficCategory.Proxy),
            SharedProxyTypeClassification.Direct => new ProxyClassification(TrafficCategory.Direct),
            SharedProxyTypeClassification.Reject => new ProxyClassification(TrafficCategory.Reject),
            _ => throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.UnsupportedProxyTypeCategory,
                "共享核心返回未知代理分类。"),
        };
    }

    private static SharedCoreProxyTypeRouteResult Fallback(
        ProxyClassification nativeClassification,
        SharedCoreProxyTypeRouteStatus status)
    {
        return new SharedCoreProxyTypeRouteResult(
            nativeClassification,
            SharedCoreProxyTypeRouteSource.NativeFallback,
            status);
    }

    private static SharedCoreProxyTypeRouteStatus Status(
        SharedProxyTypeAdapterFailure failure)
    {
        return failure switch
        {
            SharedProxyTypeAdapterFailure.UnsupportedAbiVersion =>
                SharedCoreProxyTypeRouteStatus.AbiMismatch,
            SharedProxyTypeAdapterFailure.NativeCallFailed =>
                SharedCoreProxyTypeRouteStatus.NativeCallFailed,
            SharedProxyTypeAdapterFailure.ProxyTypeInputTooLong =>
                SharedCoreProxyTypeRouteStatus.InputTooLong,
            SharedProxyTypeAdapterFailure.UnsupportedProxyTypeCategory =>
                SharedCoreProxyTypeRouteStatus.UnexpectedResult,
            SharedProxyTypeAdapterFailure.UnsupportedProxyTypeInput =>
                SharedCoreProxyTypeRouteStatus.UnsupportedInput,
            _ => SharedCoreProxyTypeRouteStatus.UnknownFailure,
        };
    }

    private static bool IsNativeCallFailure(Exception exception)
    {
        return exception is DllNotFoundException
            or EntryPointNotFoundException
            or BadImageFormatException
            or SEHException;
    }
}
