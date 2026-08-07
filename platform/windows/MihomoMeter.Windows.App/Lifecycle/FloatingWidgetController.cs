using MihomoMeter.Windows.App.Diagnostics;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class FloatingWidgetController : IDisposable
{
    private readonly Action _activateMainWindow;
    private readonly Action<bool> _stateChanged;
    private FloatingWidgetWindow? _window;
    private FloatingWidgetPosition? _lastPosition;
    private bool _disposed;

    public FloatingWidgetController(
        Action activateMainWindow,
        Action<bool> stateChanged)
    {
        _activateMainWindow = activateMainWindow
            ?? throw new ArgumentNullException(nameof(activateMainWindow));
        _stateChanged = stateChanged ?? throw new ArgumentNullException(nameof(stateChanged));
        _stateChanged(false);
    }

    public bool IsVisible => _window is not null;

    public void Toggle()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (_window is null)
        {
            _window = new FloatingWidgetWindow(_lastPosition, _activateMainWindow);
            _stateChanged(true);
            W0ConsoleReporter.Stage("floating_widget_enabled");
            return;
        }

        Disable();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        Disable();
        _disposed = true;
    }

    private void Disable()
    {
        if (_window is null)
        {
            return;
        }

        _lastPosition = _window.Position;
        _window.Dispose();
        _window = null;
        _stateChanged(false);
        W0ConsoleReporter.Stage("floating_widget_disabled");
    }
}
