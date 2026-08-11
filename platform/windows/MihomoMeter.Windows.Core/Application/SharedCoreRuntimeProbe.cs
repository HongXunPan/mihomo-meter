using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.Core.Application;

public enum SharedCoreRuntimeStatus
{
    Ready,
    AbiMismatch,
    NativeCallFailed,
    UnexpectedResult,
    UnknownFailure,
}

public static class SharedCoreRuntimeProbe
{
    public static SharedCoreRuntimeStatus Run()
    {
        return Run(
            () => MihomoMeterSharedCore.AbiVersion,
            MihomoMeterSharedCore.ScaleTraffic);
    }

    internal static SharedCoreRuntimeStatus Run(
        Func<uint> abiVersion,
        Func<ulong, SharedTrafficScale> scaleTraffic)
    {
        try
        {
            if (abiVersion() != 1)
            {
                return SharedCoreRuntimeStatus.AbiMismatch;
            }

            var result = scaleTraffic(1_500);
            return result.Value == 1.5
                && result.Unit == SharedTrafficUnit.Kilobytes
                && result.DecimalPlaces == 2
                ? SharedCoreRuntimeStatus.Ready
                : SharedCoreRuntimeStatus.UnexpectedResult;
        }
        catch (Exception exception) when (IsNativeCallFailure(exception))
        {
            return SharedCoreRuntimeStatus.NativeCallFailed;
        }
        catch (InvalidOperationException)
        {
            return SharedCoreRuntimeStatus.UnexpectedResult;
        }
        catch (Exception)
        {
            return SharedCoreRuntimeStatus.UnknownFailure;
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
