using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

internal static class TrafficLedgerStorageValues
{
    public static TrafficBytes AddChecked(TrafficBytes stored, TrafficBytes delta)
    {
        var upload = checked(stored.Upload + delta.Upload);
        var download = checked(stored.Download + delta.Download);
        if (upload > (ulong)long.MaxValue || download > (ulong)long.MaxValue)
        {
            throw new TrafficStatisticsException("本地统计字节累计超出支持范围。");
        }

        return new TrafficBytes(upload, download);
    }

    public static long ToSqliteInteger(ulong value)
    {
        if (value > (ulong)long.MaxValue)
        {
            throw new TrafficStatisticsException("本地统计字节值超出支持范围。");
        }

        return checked((long)value);
    }

    public static TrafficBytes BytesFor(
        CategorizedTrafficBytes categories,
        TrafficCategory category)
    {
        return category switch
        {
            TrafficCategory.Proxy => categories.Proxy,
            TrafficCategory.Direct => categories.Direct,
            TrafficCategory.Reject => categories.Reject,
            TrafficCategory.Unknown => categories.Unknown,
            _ => throw new TrafficStatisticsException("本地统计分类无效。"),
        };
    }

    public static string CategoryName(TrafficCategory category)
    {
        return category switch
        {
            TrafficCategory.Proxy => "proxy",
            TrafficCategory.Direct => "direct",
            TrafficCategory.Reject => "reject",
            TrafficCategory.Unknown => "unknown",
            _ => throw new TrafficStatisticsException("本地统计分类无效。"),
        };
    }

    public static TrafficCategory ParseCategory(string value)
    {
        return value switch
        {
            "proxy" => TrafficCategory.Proxy,
            "direct" => TrafficCategory.Direct,
            "reject" => TrafficCategory.Reject,
            "unknown" => TrafficCategory.Unknown,
            _ => throw new TrafficStatisticsException("本地统计分类无效。"),
        };
    }
}
