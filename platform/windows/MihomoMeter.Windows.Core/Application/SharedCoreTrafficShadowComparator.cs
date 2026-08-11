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
        return SharedCoreTrafficRouter.Route(
            bytes,
            nativeText,
            format,
            abiVersion,
            scaleTraffic).Status;
    }
}
