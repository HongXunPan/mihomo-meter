namespace MihomoMeter.Windows.Core.Application;

public static class QuotaRelativeTimeFormatter
{
    public static string Format(DateTimeOffset value, DateTimeOffset reference)
    {
        var difference = value - reference;
        var absoluteSeconds = Math.Abs(difference.TotalSeconds);
        if (absoluteSeconds < 60)
        {
            return difference.TotalSeconds <= 0 ? "刚刚" : "即将";
        }

        var suffix = difference.TotalSeconds < 0 ? "前" : "后";
        if (absoluteSeconds < TimeSpan.FromHours(1).TotalSeconds)
        {
            return $"{Math.Max((int)(absoluteSeconds / 60), 1)} 分钟{suffix}";
        }

        if (absoluteSeconds < TimeSpan.FromDays(1).TotalSeconds)
        {
            return $"{Math.Max((int)(absoluteSeconds / 3_600), 1)} 小时{suffix}";
        }

        return $"{Math.Max((int)(absoluteSeconds / 86_400), 1)} 天{suffix}";
    }
}
