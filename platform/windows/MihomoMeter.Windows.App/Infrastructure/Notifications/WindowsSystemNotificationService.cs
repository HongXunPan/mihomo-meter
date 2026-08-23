using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Infrastructure.Notifications;

internal sealed class WindowsSystemNotificationService : IDisposable
{
    private readonly AppNotificationManager _manager = AppNotificationManager.Default;
    private bool _isRegistered;
    private bool _disposed;

    public event Action<AppActivationTarget>? Activated;

    public bool IsAvailable
    {
        get
        {
            if (!_isRegistered || _disposed)
            {
                return false;
            }

            try
            {
                return _manager.Setting == AppNotificationSetting.Enabled;
            }
            catch (Exception)
            {
                return false;
            }
        }
    }

    public void Register()
    {
        if (_isRegistered || _disposed)
        {
            return;
        }

        try
        {
            _manager.NotificationInvoked += Manager_NotificationInvoked;
            _manager.Register();
            _isRegistered = true;
        }
        catch (Exception)
        {
            _manager.NotificationInvoked -= Manager_NotificationInvoked;
            _isRegistered = false;
        }
    }

    public bool TryShow(SystemNotificationDelivery delivery)
    {
        if (!IsAvailable)
        {
            return false;
        }

        try
        {
            var notification = new AppNotificationBuilder()
                .AddArgument("target", AppActivationTargetContract.Value(delivery.Target))
                .AddText(delivery.Title)
                .AddText(delivery.Body)
                .BuildNotification();
            notification.Expiration = DateTimeOffset.Now.AddDays(3);
            _manager.Show(notification);
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public bool TryHandleActivation(AppNotificationActivatedEventArgs args)
    {
        if (!args.Arguments.TryGetValue("target", out var value)
            || !AppActivationTargetContract.TryParse(value, out var target))
        {
            return false;
        }

        Activated?.Invoke(target);
        return true;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        if (_isRegistered)
        {
            _manager.NotificationInvoked -= Manager_NotificationInvoked;
            try
            {
                _manager.Unregister();
            }
            catch (Exception)
            {
            }
            _isRegistered = false;
        }
    }

    private void Manager_NotificationInvoked(
        AppNotificationManager sender,
        AppNotificationActivatedEventArgs args)
    {
        _ = TryHandleActivation(args);
    }
}
