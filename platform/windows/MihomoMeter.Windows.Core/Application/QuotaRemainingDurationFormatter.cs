namespace MihomoMeter.Windows.Core.Application;

public static class QuotaRemainingDurationFormatter
{
    public static string FormatDays(int days)
    {
        var normalizedDays = Math.Max(days, 0);
        if (normalizedDays < 60)
        {
            return $"{normalizedDays} 天";
        }

        if (normalizedDays < 365)
        {
            return $"{(normalizedDays + 15) / 30} 个月";
        }

        var years = normalizedDays / 365;
        var months = (normalizedDays % 365 + 15) / 30;
        if (months >= 12)
        {
            years += 1;
            months = 0;
        }

        return months == 0
            ? $"{years} 年"
            : $"{years} 年 {months} 个月";
    }
}
