using Microsoft.UI;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SettingsWorkspaceView : UserControl
{
    private readonly GeneralSettingsView _generalSettingsView;
    private readonly ControllerSettingsView _controllerSettingsView;
    private readonly WindowsUpdateWorkspaceView _updateView;

    internal SettingsWorkspaceView(
        MainWindowViewModel mainWindowViewModel,
        WindowsUpdateWorkspaceViewModel updateViewModel,
        StartupSettingsViewModel startupViewModel,
        SystemNotificationSettingsViewModel systemNotificationViewModel,
        WindowId windowId)
    {
        _generalSettingsView = new GeneralSettingsView(
            mainWindowViewModel,
            startupViewModel,
            systemNotificationViewModel,
            windowId);
        _controllerSettingsView = new ControllerSettingsView(mainWindowViewModel);
        _updateView = new WindowsUpdateWorkspaceView(updateViewModel);
        InitializeComponent();
        ShowConnectionSettings();
    }

    internal void ShowConnectionSettings()
    {
        SettingsNavigation.SelectedItem = ConnectionItem;
        SettingsContent.Content = _controllerSettingsView;
    }

    internal void ShowUpdates()
    {
        SettingsNavigation.SelectedItem = UpdateItem;
        SettingsContent.Content = _updateView;
    }

    private void SettingsNavigation_SelectionChanged(
        NavigationView sender,
        NavigationViewSelectionChangedEventArgs args)
    {
        SettingsContent.Content = args.SelectedItemContainer?.Tag?.ToString() switch
        {
            "general" => _generalSettingsView,
            "update" => _updateView,
            _ => _controllerSettingsView,
        };
    }
}
