using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.App.Diagnostics;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class GeneralSettingsView : UserControl
{
    private readonly MainWindowViewModel _mainWindowViewModel;
    private readonly StartupSettingsViewModel _viewModel;
    private readonly SystemNotificationSettingsViewModel _systemNotificationViewModel;
    private readonly DiagnosticExportService _diagnosticExportService = new();
    private readonly WindowId _windowId;
    private bool _isApplyingState;
    private bool _isDiagnosticDialogOpen;

    internal GeneralSettingsView(
        MainWindowViewModel mainWindowViewModel,
        StartupSettingsViewModel viewModel,
        SystemNotificationSettingsViewModel systemNotificationViewModel,
        WindowId windowId)
    {
        _mainWindowViewModel = mainWindowViewModel;
        _viewModel = viewModel;
        _systemNotificationViewModel = systemNotificationViewModel;
        _windowId = windowId;
        InitializeComponent();
        ApplyViewModelState();
    }

    private void GeneralSettingsView_Loaded(object sender, RoutedEventArgs args)
    {
        _viewModel.Refresh();
        _systemNotificationViewModel.Refresh();
        ApplyViewModelState();
    }

    private void StartupToggle_Toggled(object sender, RoutedEventArgs args)
    {
        if (_isApplyingState)
        {
            return;
        }

        _viewModel.SetEnabled(StartupToggle.IsOn);
        ApplyViewModelState();
    }

    private void RepairRegistrationButton_Click(object sender, RoutedEventArgs args)
    {
        _viewModel.RepairRegistration();
        ApplyViewModelState();
    }

    private void SystemNotificationToggle_Toggled(object sender, RoutedEventArgs args)
    {
        if (_isApplyingState)
        {
            return;
        }

        _systemNotificationViewModel.SetEnabled(SystemNotificationToggle.IsOn);
        ApplyViewModelState();
    }

    private void DisconnectNotificationToggle_Toggled(
        object sender,
        RoutedEventArgs args)
    {
        if (_isApplyingState)
        {
            return;
        }

        _systemNotificationViewModel.SetDisconnectAlertsEnabled(
            DisconnectNotificationToggle.IsOn);
        ApplyViewModelState();
    }

    private async void DiagnosticExportButton_Click(object sender, RoutedEventArgs args)
    {
        if (_isDiagnosticDialogOpen)
        {
            return;
        }

        _isDiagnosticDialogOpen = true;
        try
        {
            var dialog = new ContentDialog
            {
                CloseButtonText = "取消",
                Content = "包含版本、系统架构、固定连接状态与脱敏事件；不包含 Controller 地址或 Secret、订阅/Profile 标识、数据库、文件路径、真实连接元数据、原始错误或日志原文。文件不会自动上传。",
                DefaultButton = ContentDialogButton.Primary,
                PrimaryButtonText = "选择保存位置",
                Title = "导出诊断信息？",
                XamlRoot = this.XamlRoot,
            };
            if (await dialog.ShowAsync() != ContentDialogResult.Primary)
            {
                return;
            }

            DiagnosticExportButton.IsEnabled = false;
            DiagnosticExportInfoBar.IsOpen = false;
            var result = await _diagnosticExportService.ExportAsync(
                _windowId,
                _mainWindowViewModel.ConnectionState);
            if (result == DiagnosticExportResult.Exported)
            {
                ShowDiagnosticExportResult(
                    InfoBarSeverity.Success,
                    "诊断信息已导出",
                    "文件仅保存在你选择的位置，未自动上传。");
            }
        }
        catch
        {
            ShowDiagnosticExportResult(
                InfoBarSeverity.Error,
                "无法导出诊断信息",
                "请重新选择保存位置后再试。");
        }
        finally
        {
            DiagnosticExportButton.IsEnabled = true;
            _isDiagnosticDialogOpen = false;
        }
    }

    private void ShowDiagnosticExportResult(
        InfoBarSeverity severity,
        string title,
        string message)
    {
        DiagnosticExportInfoBar.Severity = severity;
        DiagnosticExportInfoBar.Title = title;
        DiagnosticExportInfoBar.Message = message;
        DiagnosticExportInfoBar.IsOpen = true;
    }

    private void ApplyViewModelState()
    {
        _isApplyingState = true;
        StartupToggle.IsOn = _viewModel.IsEnabled;
        StartupToggle.IsEnabled = _viewModel.CanToggle;
        StartupStatusText.Text = _viewModel.StatusMessage;
        RepairRegistrationButton.Visibility = _viewModel.CanRepairRegistration
            ? Visibility.Visible
            : Visibility.Collapsed;
        StartupErrorInfoBar.Message = _viewModel.ErrorMessage ?? string.Empty;
        StartupErrorInfoBar.IsOpen = _viewModel.ErrorMessage is not null;
        SystemNotificationToggle.IsOn = _systemNotificationViewModel.IsEnabled;
        SystemNotificationToggle.IsEnabled = _systemNotificationViewModel.CanToggle;
        DisconnectNotificationToggle.IsOn =
            _systemNotificationViewModel.DisconnectAlertsEnabled;
        DisconnectNotificationToggle.IsEnabled =
            _systemNotificationViewModel.CanToggle
            && _systemNotificationViewModel.IsEnabled;
        SystemNotificationStatusText.Text = _systemNotificationViewModel.StatusMessage;
        SystemNotificationErrorInfoBar.Message =
            _systemNotificationViewModel.ErrorMessage ?? string.Empty;
        SystemNotificationErrorInfoBar.IsOpen =
            _systemNotificationViewModel.ErrorMessage is not null;
        _isApplyingState = false;
    }
}
