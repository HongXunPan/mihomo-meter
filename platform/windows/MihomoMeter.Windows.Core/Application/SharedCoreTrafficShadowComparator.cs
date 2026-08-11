using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.Core.Application;

internal static class SharedCoreTrafficShadowComparator
{
    public static SharedCoreTrafficShadowStatus Compare(
        ulong bytes,
        string nativeText,
        SharedCoreTrafficFormat format)
    {
        return Compare(
            bytes,
            nativeText,
            format,
            () => MihomoMeterSharedCore.AbiVersion,
            MihomoMeterSharedCore.ScaleTraffic);
    }

    internal static SharedCoreTrafficShadowStatus Compare(
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
                return SharedCoreTrafficShadowStatus.AbiMismatch;
            }

            var sharedText = SharedCoreTrafficDisplayFormatter.Format(
                scaleTraffic(bytes),
                format);
            return string.Equals(sharedText, nativeText, StringComparison.Ordinal)
                ? SharedCoreTrafficShadowStatus.Matched
                : SharedCoreTrafficShadowStatus.Mismatch;
        }
        catch (Exception exception) when (IsNativeCallFailure(exception))
        {
            return SharedCoreTrafficShadowStatus.NativeCallFailed;
        }
        catch (InvalidOperationException)
        {
            return SharedCoreTrafficShadowStatus.UnexpectedResult;
        }
        catch (Exception)
        {
            return SharedCoreTrafficShadowStatus.UnknownFailure;
        }
    }

    private static bool IsNativeCallFailure(Exception exception)
    {
        return exception is DllNotFoundException
            or EntryPointNotFoundException
            or BadImageFormatException
            or SEHException;
    }
}
