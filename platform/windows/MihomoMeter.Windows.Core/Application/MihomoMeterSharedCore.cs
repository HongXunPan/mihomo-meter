using System.Runtime.InteropServices;
using System.Text;

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

public enum SharedProxyTypeClassification : uint
{
    Unrecognized,
    Proxy,
    Direct,
    Reject,
}

public enum SharedProxyTypeAdapterFailure
{
    UnsupportedAbiVersion,
    NativeCallFailed,
    ProxyTypeInputTooLong,
    UnsupportedProxyTypeCategory,
    UnsupportedProxyTypeInput,
}

public sealed class SharedProxyTypeAdapterException : InvalidOperationException
{
    public SharedProxyTypeAdapterException(
        SharedProxyTypeAdapterFailure failure,
        string message,
        int? nativeStatus = null)
        : base(message)
    {
        Failure = failure;
        NativeStatus = nativeStatus;
    }

    public SharedProxyTypeAdapterFailure Failure { get; }

    public int? NativeStatus { get; }
}

public static class MihomoMeterSharedCore
{
    private const string LibraryName = "mihomo_meter_shared_core";
    private const uint ExpectedAbiVersion = 1;
    private const int MaximumProxyTypeInputLength = 64;
    private const int InvalidInputStatus = -2;
    private const int InputTooLongStatus = -3;

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

    public static SharedProxyTypeClassification ClassifyProxyType(string rawType)
    {
        var abiVersion = AbiVersion;
        if (abiVersion != ExpectedAbiVersion)
        {
            throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.UnsupportedAbiVersion,
                $"共享核心 ABI 版本不匹配：{abiVersion}。");
        }

        var input = Encoding.UTF8.GetBytes(rawType);
        if (input.Length > MaximumProxyTypeInputLength)
        {
            throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.ProxyTypeInputTooLong,
                "共享核心代理类型输入超过 64 字节上限。");
        }

        var status = NativeMethods.ClassifyProxyType(
            input,
            checked((uint)input.Length),
            out var result);
        if (status == InvalidInputStatus)
        {
            throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.UnsupportedProxyTypeInput,
                "共享核心代理类型输入不是受支持的 ASCII。",
                status);
        }
        if (status == InputTooLongStatus)
        {
            throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.ProxyTypeInputTooLong,
                "共享核心代理类型输入超过长度上限。",
                status);
        }
        if (status != 0)
        {
            throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.NativeCallFailed,
                $"共享核心代理类型分类失败，错误码：{status}。",
                status);
        }

        if (!Enum.IsDefined(typeof(SharedProxyTypeClassification), result.Category))
        {
            throw new SharedProxyTypeAdapterException(
                SharedProxyTypeAdapterFailure.UnsupportedProxyTypeCategory,
                $"共享核心返回未知代理分类：{result.Category}。");
        }

        return (SharedProxyTypeClassification)result.Category;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeScaledTraffic
    {
        public double Value;
        public uint Unit;
        public uint DecimalPlaces;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeProxyTypeClassification
    {
        public uint Category;
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

        [DllImport(
            LibraryName,
            EntryPoint = "mm_classify_proxy_type",
            ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl)]
        public static extern int ClassifyProxyType(
            [In, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1, ArraySubType = UnmanagedType.U1)]
            byte[] input,
            uint length,
            out NativeProxyTypeClassification result);
    }
}
