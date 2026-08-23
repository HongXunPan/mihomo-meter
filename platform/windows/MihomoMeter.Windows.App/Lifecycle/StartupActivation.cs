using Microsoft.Windows.AppLifecycle;
using MihomoMeter.Windows.App.Infrastructure.Startup;
using MihomoMeter.Windows.Core.Domain;
using Windows.ApplicationModel.Activation;

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

    public static bool TryResolveProtocolTarget(
        AppActivationArguments? arguments,
        out AppActivationTarget target)
    {
        target = AppActivationTarget.MainWindow;
        if (arguments?.Kind != ExtendedActivationKind.Protocol
            || arguments.Data is not ProtocolActivatedEventArgs protocolArguments)
        {
            return false;
        }

        AppDeepLink.TryParse(protocolArguments.Uri, out target);
        return true;
    }
}
