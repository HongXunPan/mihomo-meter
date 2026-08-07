using System.Runtime.CompilerServices;

namespace MihomoMeter.Windows.Tests;

internal static class WindowsSqliteTestProvider
{
    [ModuleInitializer]
    internal static void Initialize()
    {
        SQLitePCL.Batteries_V2.Init();
    }
}
