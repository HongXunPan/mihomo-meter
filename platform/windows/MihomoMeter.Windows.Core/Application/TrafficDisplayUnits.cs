using System.Globalization;

namespace MihomoMeter.Windows.Core.Application;

public static class TrafficDisplayUnits
{
    private static readonly string[] Units = ["B", "KB", "MB", "GB", "TB"];
    private static readonly string[] CompactUnits = ["B/s", "K/s", "M/s", "G/s", "T/s"];

    public static string ByteCount(ulong bytes)
    {
        if (bytes < 1_000)
        {
            return $"{bytes} B";
        }

        var value = (double)bytes;
        var unitIndex = 0;
        while (value >= 1_000 && unitIndex < Units.Length - 1)
        {
            value /= 1_000;
            unitIndex += 1;
        }

        var format = value switch
        {
            >= 100 => "0",
            >= 10 => "0.0",
            _ => "0.00",
        };
        return $"{value.ToString(format, CultureInfo.InvariantCulture)} {Units[unitIndex]}";
    }

    public static string Rate(ulong bytesPerSecond)
    {
        return $"{ByteCount(bytesPerSecond)}/s";
    }

    public static string CompactRate(ulong? bytesPerSecond)
    {
        if (bytesPerSecond is null)
        {
            return "--";
        }
        if (bytesPerSecond.Value < 1_000)
        {
            return $"{bytesPerSecond.Value}B/s";
        }

        var value = (double)bytesPerSecond.Value;
        var unitIndex = 0;
        while (value >= 1_000 && unitIndex < CompactUnits.Length - 1)
        {
            value /= 1_000;
            unitIndex += 1;
        }

        var format = value switch
        {
            >= 100 => "0",
            >= 10 => "0.0",
            _ => "0.00",
        };
        return $"{value.ToString(format, CultureInfo.InvariantCulture)}{CompactUnits[unitIndex]}";
    }
}
