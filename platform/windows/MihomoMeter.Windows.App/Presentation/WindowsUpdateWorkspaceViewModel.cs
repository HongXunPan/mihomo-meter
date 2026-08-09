using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed class WindowsUpdateWorkspaceViewModel : INotifyPropertyChanged
{
    private readonly WindowsUpdateChecker _checker;
    private readonly ReleaseVersion _currentVersion;
    private bool _isChecking;
    private bool _isStatusOpen;
    private string _statusTitle = string.Empty;
    private string _statusMessage = string.Empty;
    private InfoBarSeverity _statusSeverity = InfoBarSeverity.Informational;
    private Uri? _releasePageUri;

    internal WindowsUpdateWorkspaceViewModel(
        WindowsUpdateChecker checker,
        ReleaseVersion currentVersion)
    {
        _checker = checker;
        _currentVersion = currentVersion;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public string CurrentVersionText => $"当前版本：{_currentVersion}";

    public bool IsChecking => _isChecking;

    public bool CanCheck => !_isChecking;

    public string CheckButtonText => _isChecking ? "正在检查…" : "检查更新";

    public bool IsStatusOpen => _isStatusOpen;

    public string StatusTitle => _statusTitle;

    public string StatusMessage => _statusMessage;

    public InfoBarSeverity StatusSeverity => _statusSeverity;

    public Visibility OpenReleaseVisibility => _releasePageUri is null
        ? Visibility.Collapsed
        : Visibility.Visible;

    public Uri? ReleasePageUri => _releasePageUri;

    public async Task CheckAsync()
    {
        if (_isChecking)
        {
            return;
        }

        SetChecking(true);
        try
        {
            var result = await _checker.CheckAsync(_currentVersion);
            ApplyResult(result);
        }
        catch (Exception)
        {
            ShowFailure("检查更新时发生未预期错误；实时监控不受影响，请稍后重试。");
        }
        finally
        {
            SetChecking(false);
        }
    }

    public void ReportOpenFailure()
    {
        ShowFailure("系统未能打开发布页面，请从项目 GitHub Releases 手动进入。");
    }

    private void ApplyResult(WindowsUpdateCheckResult result)
    {
        _releasePageUri = result.ReleasePageUri;
        switch (result.Availability)
        {
            case WindowsUpdateAvailability.UpdateAvailable:
                _statusTitle = "发现 Windows 新版本";
                _statusMessage = $"Windows {result.LatestVersion} 已发布。下载和安装仍由你确认。";
                _statusSeverity = InfoBarSeverity.Success;
                break;
            case WindowsUpdateAvailability.UpToDate:
                _statusTitle = result.LatestVersion == _currentVersion
                    ? "已是最新版本"
                    : "当前版本较新";
                _statusMessage = result.LatestVersion == _currentVersion
                    ? $"Windows {_currentVersion} 是当前公开稳定版本。"
                    : $"公开稳定版本为 {result.LatestVersion}，不会提示降级。";
                _statusSeverity = InfoBarSeverity.Informational;
                break;
            default:
                _statusTitle = "暂时无法检查更新";
                _statusMessage = FailureMessage(result.FailureCategory);
                _statusSeverity = InfoBarSeverity.Warning;
                break;
        }

        _isStatusOpen = true;
        NotifyStatusChanged();
    }

    private void ShowFailure(string message)
    {
        _releasePageUri = null;
        _statusTitle = "暂时无法检查更新";
        _statusMessage = message;
        _statusSeverity = InfoBarSeverity.Warning;
        _isStatusOpen = true;
        NotifyStatusChanged();
    }

    private static string FailureMessage(WindowsReleaseQueryFailureCategory? category)
    {
        return category switch
        {
            WindowsReleaseQueryFailureCategory.Unavailable =>
                "尚未找到 Windows 正式版本描述，请稍后再试。",
            WindowsReleaseQueryFailureCategory.RateLimited =>
                "GitHub 暂时限制了请求频率，请稍后再试。",
            WindowsReleaseQueryFailureCategory.InvalidDescriptor =>
                "公开版本描述未通过安全校验，已拒绝打开其中的链接。",
            _ => "网络请求失败；实时监控不受影响，请稍后重试。",
        };
    }

    private void SetChecking(bool value)
    {
        _isChecking = value;
        OnPropertyChanged(nameof(IsChecking));
        OnPropertyChanged(nameof(CanCheck));
        OnPropertyChanged(nameof(CheckButtonText));
    }

    private void NotifyStatusChanged()
    {
        OnPropertyChanged(nameof(IsStatusOpen));
        OnPropertyChanged(nameof(StatusTitle));
        OnPropertyChanged(nameof(StatusMessage));
        OnPropertyChanged(nameof(StatusSeverity));
        OnPropertyChanged(nameof(OpenReleaseVisibility));
        OnPropertyChanged(nameof(ReleasePageUri));
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
