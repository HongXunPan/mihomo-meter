using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

internal static class TrafficDisplayFormatter
{
    public static string Rate(TrafficRate? rate)
    {
        return rate is null
            ? "↑ --  ·  ↓ --"
            : $"↑ {ByteCount(rate.Value.UploadBytesPerSecond)}/s  ·  "
                + $"↓ {ByteCount(rate.Value.DownloadBytesPerSecond)}/s";
    }

    public static string ByteCount(ulong bytes)
    {
        const double kibibyte = 1_024;
        const double mebibyte = 1_024 * 1_024;
        const double gibibyte = 1_024 * 1_024 * 1_024;
        return bytes switch
        {
            >= (ulong)gibibyte => $"{bytes / gibibyte:0.0} GiB",
            >= (ulong)mebibyte => $"{bytes / mebibyte:0.0} MiB",
            >= (ulong)kibibyte => $"{bytes / kibibyte:0.0} KiB",
            _ => $"{bytes} B",
        };
    }

    public static string DateTime(DateTimeOffset value)
    {
        return value.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");
    }

    public static string Duration(DateTimeOffset startedAt, DateTimeOffset endedAt)
    {
        var duration = endedAt > startedAt ? endedAt - startedAt : TimeSpan.Zero;
        return duration.TotalDays >= 1
            ? $"{(int)duration.TotalDays}天 {duration:hh\\:mm\\:ss}"
            : duration.ToString("hh\\:mm\\:ss");
    }
}
