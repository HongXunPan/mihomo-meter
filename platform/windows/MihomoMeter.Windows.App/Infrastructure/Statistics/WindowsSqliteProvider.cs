namespace MihomoMeter.Windows.App.Infrastructure.Statistics;

internal static class WindowsSqliteProvider
{
    private static int _isInitialized;

    public static void Initialize()
    {
        if (Interlocked.Exchange(ref _isInitialized, 1) == 0)
        {
            SQLitePCL.Batteries_V2.Init();
        }
    }
}
