namespace MihomoMeter.Windows.Tests;

internal static class FixtureLoader
{
    public static byte[] Load(string name)
    {
        return File.ReadAllBytes(Path.Combine(
            AppContext.BaseDirectory,
            "Fixtures",
            $"{name}.json"));
    }
}
