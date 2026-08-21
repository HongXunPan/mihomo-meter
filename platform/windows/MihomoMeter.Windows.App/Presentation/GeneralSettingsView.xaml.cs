using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class GeneralSettingsView : UserControl
{
    private readonly StartupSettingsViewModel _viewModel;
    private bool _isApplyingState;

    internal GeneralSettingsView(StartupSettingsViewModel viewModel)
    {
        _viewModel = viewModel;
        InitializeComponent();
        ApplyViewModelState();
    }

    private void GeneralSettingsView_Loaded(object sender, RoutedEventArgs args)
    {
        _viewModel.Refresh();
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
        _isApplyingState = false;
    }
}
