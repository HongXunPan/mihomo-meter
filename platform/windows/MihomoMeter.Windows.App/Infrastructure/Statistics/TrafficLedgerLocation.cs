namespace MihomoMeter.Windows.App.Infrastructure.Statistics;

internal static class TrafficLedgerLocation
{
    public static string DefaultDatabasePath()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "traffic.sqlite3");
    }
}
