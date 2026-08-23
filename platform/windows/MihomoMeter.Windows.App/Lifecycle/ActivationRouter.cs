namespace MihomoMeter.Windows.App.Lifecycle;

using MihomoMeter.Windows.Core.Domain;

internal static class ActivationRouter
{
    private static readonly object SyncRoot = new();

    private static Action<AppActivationTarget>? _handler;
    private static AppActivationTarget? _pendingTarget;

    public static void Register(Action<AppActivationTarget> handler)
    {
        ArgumentNullException.ThrowIfNull(handler);

        AppActivationTarget? pendingTarget;
        lock (SyncRoot)
        {
            _handler = handler;
            pendingTarget = _pendingTarget;
            _pendingTarget = null;
        }

        if (pendingTarget is AppActivationTarget target)
        {
            handler(target);
        }
    }

    public static void RequestMainWindowActivation()
    {
        RequestActivation(AppActivationTarget.MainWindow);
    }

    public static void RequestActivation(AppActivationTarget target)
    {
        Action<AppActivationTarget>? handler;
        lock (SyncRoot)
        {
            handler = _handler;
            if (handler is null)
            {
                _pendingTarget = target;
                return;
            }
        }

        handler(target);
    }
}
