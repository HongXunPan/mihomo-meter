using System.Runtime.InteropServices;

namespace MihomoMeter.Windows.Core.Application;

public enum SharedTrafficUnit : uint
{
    Bytes,
    Kilobytes,
    Megabytes,
    Gigabytes,
    Terabytes,
}

public readonly record struct SharedTrafficScale(
    double Value,
    SharedTrafficUnit Unit,
    uint DecimalPlaces);

public static class MihomoMeterSharedCore
{
    private const string LibraryName = "mihomo_meter_shared_core";
    private const uint ExpectedAbiVersion = 1;

    public static uint AbiVersion => NativeMethods.CoreAbiVersion();

    public static SharedTrafficScale ScaleTraffic(ulong bytes)
    {
        var abiVersion = AbiVersion;
        if (abiVersion != ExpectedAbiVersion)
        {
            throw new InvalidOperationException($"共享核心 ABI 版本不匹配：{abiVersion}。");
        }

        var status = NativeMethods.ScaleTraffic(bytes, out var result);
        if (status != 0)
        {
            throw new InvalidOperationException($"共享核心流量缩放失败，错误码：{status}。");
        }

        if (!Enum.IsDefined(typeof(SharedTrafficUnit), result.Unit))
        {
            throw new InvalidOperationException($"共享核心返回未知流量单位：{result.Unit}。");
        }

        return new SharedTrafficScale(
            result.Value,
            (SharedTrafficUnit)result.Unit,
            result.DecimalPlaces);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeScaledTraffic
    {
        public double Value;
        public uint Unit;
        public uint DecimalPlaces;
    }

    private static class NativeMethods
    {
        [DllImport(
            LibraryName,
            EntryPoint = "mm_core_abi_version",
            ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl)]
        public static extern uint CoreAbiVersion();

        [DllImport(
            LibraryName,
            EntryPoint = "mm_scale_traffic",
            ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl)]
        public static extern int ScaleTraffic(ulong bytes, out NativeScaledTraffic result);
    }
}
