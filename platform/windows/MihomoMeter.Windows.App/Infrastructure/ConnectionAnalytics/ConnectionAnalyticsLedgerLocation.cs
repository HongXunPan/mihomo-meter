namespace MihomoMeter.Windows.App.Infrastructure.ConnectionAnalytics;

internal static class ConnectionAnalyticsLedgerLocation
{
    public static string DefaultDatabasePath()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "connection-analytics.sqlite3");
    }
}
