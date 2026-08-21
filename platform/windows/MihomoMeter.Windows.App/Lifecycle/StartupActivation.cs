using MihomoMeter.Windows.App.Infrastructure.Startup;

namespace MihomoMeter.Windows.App.Lifecycle;

internal static class StartupActivation
{
    public static bool IsStartupLaunch(IEnumerable<string> arguments)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        return arguments.Any(argument => string.Equals(
            argument,
            StartupRegistrationService.StartupArgument,
            StringComparison.Ordinal));
    }
}
