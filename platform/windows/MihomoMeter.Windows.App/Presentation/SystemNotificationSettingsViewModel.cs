using MihomoMeter.Windows.App.Application;

namespace MihomoMeter.Windows.App.Presentation;

internal sealed class SystemNotificationSettingsViewModel
{
    private readonly SystemNotificationCoordinator _coordinator;

    public SystemNotificationSettingsViewModel(SystemNotificationCoordinator coordinator)
    {
        _coordinator = coordinator;
    }

    public bool IsEnabled => _coordinator.IsEnabled;

    public bool DisconnectAlertsEnabled => _coordinator.DisconnectAlertsEnabled;

    public bool CanToggle => true;

    public string StatusMessage => _coordinator.StatusMessage;

    public string? ErrorMessage => _coordinator.ErrorMessage;

    public void Refresh()
    {
        _coordinator.RefreshSystemStatus();
    }

    public void SetEnabled(bool enabled)
    {
        _coordinator.SetEnabled(enabled);
    }

    public void SetDisconnectAlertsEnabled(bool enabled)
    {
        _coordinator.SetDisconnectAlertsEnabled(enabled);
    }
}
