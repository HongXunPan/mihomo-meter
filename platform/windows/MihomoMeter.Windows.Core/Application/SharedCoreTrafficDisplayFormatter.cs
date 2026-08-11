using System.Globalization;

namespace MihomoMeter.Windows.Core.Application;

internal static class SharedCoreTrafficDisplayFormatter
{
    public static string Format(
        SharedTrafficScale scale,
        SharedCoreTrafficFormat format)
    {
        var numberFormat = scale.DecimalPlaces switch
        {
            0 => "0",
            1 => "0.0",
            2 => "0.00",
            _ => throw new InvalidOperationException(
                $"共享核心返回了不支持的小数位数：{scale.DecimalPlaces}。"),
        };
        var number = scale.Value.ToString(numberFormat, CultureInfo.InvariantCulture);
        var unit = UnitText(scale.Unit, format);
        return format switch
        {
            SharedCoreTrafficFormat.ByteCount => $"{number} {unit}",
            SharedCoreTrafficFormat.Rate => $"{number} {unit}/s",
            SharedCoreTrafficFormat.CompactRate => $"{number}{unit}/s",
            _ => throw new InvalidOperationException($"未知共享核心流量格式：{format}。"),
        };
    }

    private static string UnitText(
        SharedTrafficUnit unit,
        SharedCoreTrafficFormat format)
    {
        if (format == SharedCoreTrafficFormat.CompactRate)
        {
            return unit switch
            {
                SharedTrafficUnit.Bytes => "B",
                SharedTrafficUnit.Kilobytes => "K",
                SharedTrafficUnit.Megabytes => "M",
                SharedTrafficUnit.Gigabytes => "G",
                SharedTrafficUnit.Terabytes => "T",
                _ => throw new InvalidOperationException(
                    $"共享核心返回未知流量单位：{unit}。"),
            };
        }

        return unit switch
        {
            SharedTrafficUnit.Bytes => "B",
            SharedTrafficUnit.Kilobytes => "KB",
            SharedTrafficUnit.Megabytes => "MB",
            SharedTrafficUnit.Gigabytes => "GB",
            SharedTrafficUnit.Terabytes => "TB",
            _ => throw new InvalidOperationException($"共享核心返回未知流量单位：{unit}。"),
        };
    }
}
