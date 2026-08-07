namespace MihomoMeter.Windows.App.Lifecycle;

internal static class ActivationRouter
{
    private static readonly object SyncRoot = new();

    private static Action? _handler;
    private static bool _activationPending;

    public static void Register(Action handler)
    {
        ArgumentNullException.ThrowIfNull(handler);

        var shouldActivate = false;
        lock (SyncRoot)
        {
            _handler = handler;
            shouldActivate = _activationPending;
            _activationPending = false;
        }

        if (shouldActivate)
        {
            handler();
        }
    }

    public static void RequestMainWindowActivation()
    {
        Action? handler;
        lock (SyncRoot)
        {
            handler = _handler;
            if (handler is null)
            {
                _activationPending = true;
                return;
            }
        }

        handler();
    }
}
