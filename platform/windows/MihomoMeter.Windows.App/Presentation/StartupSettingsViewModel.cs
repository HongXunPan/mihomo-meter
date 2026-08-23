using MihomoMeter.Windows.App.Infrastructure.Startup;

namespace MihomoMeter.Windows.App.Presentation;

internal sealed class StartupSettingsViewModel
{
    private readonly StartupRegistrationService _registration;
    private StartupRegistrationStatus? _status;

    public StartupSettingsViewModel(StartupRegistrationService registration)
    {
        _registration = registration;
        Refresh();
    }

    public bool IsEnabled => _status is
        StartupRegistrationStatus.EnabledForCurrentExecutable
        or StartupRegistrationStatus.EnabledForDifferentExecutable;

    public bool CanToggle => _status is not null;

    public bool CanRepairRegistration =>
        _status == StartupRegistrationStatus.EnabledForDifferentExecutable;

    public string StatusMessage => _status switch
    {
        StartupRegistrationStatus.EnabledForCurrentExecutable =>
            "当前用户登录 Windows 后将静默启动，只显示通知区域图标。",
        StartupRegistrationStatus.EnabledForDifferentExecutable =>
            "登录启动仍指向另一份 Mihomo Meter；可改为当前程序。",
        StartupRegistrationStatus.Disabled =>
            "默认关闭；开启后只在当前用户登录桌面时启动。",
        _ => "系统暂时无法读取 Mihomo Meter 登录启动状态。",
    };

    public string? ErrorMessage { get; private set; }

    public void Refresh()
    {
        ErrorMessage = null;
        ReloadStatus();
    }

    public void SetEnabled(bool isEnabled)
    {
        ErrorMessage = null;
        try
        {
            if (isEnabled)
            {
                _registration.RegisterCurrentExecutable();
            }
            else
            {
                _registration.Unregister();
            }
        }
        catch (Exception)
        {
            ErrorMessage = "无法更新登录启动，已恢复系统当前状态。";
        }
        ReloadStatus();
    }

    public void RepairRegistration()
    {
        SetEnabled(true);
    }

    private void ReloadStatus()
    {
        try
        {
            _status = _registration.ReadStatus();
        }
        catch (Exception)
        {
            _status = null;
            ErrorMessage ??= "无法读取当前用户登录启动状态。";
        }
    }
}
