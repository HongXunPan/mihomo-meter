namespace MihomoMeter.Windows.Core.Domain;

public enum AppActivationTarget
{
    MainWindow,
    Statistics,
    SubscriptionQuota,
    ControllerSettings,
}

public static class AppActivationTargetContract
{
    public static string Value(AppActivationTarget target)
    {
        return target switch
        {
            AppActivationTarget.MainWindow => "main",
            AppActivationTarget.Statistics => "statistics",
            AppActivationTarget.SubscriptionQuota => "subscriptionQuota",
            AppActivationTarget.ControllerSettings => "controllerSettings",
            _ => throw new ArgumentOutOfRangeException(nameof(target)),
        };
    }

    public static bool TryParse(string? value, out AppActivationTarget target)
    {
        target = value switch
        {
            "main" => AppActivationTarget.MainWindow,
            "statistics" => AppActivationTarget.Statistics,
            "subscriptionQuota" => AppActivationTarget.SubscriptionQuota,
            "controllerSettings" => AppActivationTarget.ControllerSettings,
            _ => default,
        };
        return value is "main" or "statistics" or "subscriptionQuota" or "controllerSettings";
    }
}

public static class AppDeepLink
{
    public const string StatisticsUrl = "mihomo-meter://statistics";
    public const string SubscriptionQuotaUrl = "mihomo-meter://subscription-quota";
    public const string ConnectionSettingsUrl = "mihomo-meter://connection-settings";

    public static bool TryParse(Uri? uri, out AppActivationTarget target)
    {
        target = uri?.OriginalString switch
        {
            StatisticsUrl => AppActivationTarget.Statistics,
            SubscriptionQuotaUrl => AppActivationTarget.SubscriptionQuota,
            ConnectionSettingsUrl => AppActivationTarget.ControllerSettings,
            _ => AppActivationTarget.MainWindow,
        };
        return uri?.OriginalString is StatisticsUrl
            or SubscriptionQuotaUrl
            or ConnectionSettingsUrl;
    }
}
