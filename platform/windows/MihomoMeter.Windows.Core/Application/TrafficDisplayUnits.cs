using System.Globalization;

namespace MihomoMeter.Windows.Core.Application;

public static class TrafficDisplayUnits
{
    private static readonly string[] Units = ["B", "KB", "MB", "GB", "TB"];

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
}
