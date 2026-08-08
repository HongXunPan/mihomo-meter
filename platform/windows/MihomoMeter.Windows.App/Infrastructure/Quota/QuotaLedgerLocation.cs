namespace MihomoMeter.Windows.App.Infrastructure.Quota;

internal static class QuotaLedgerLocation
{
    public static string DefaultDatabasePath()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "quota.sqlite3");
    }
}
