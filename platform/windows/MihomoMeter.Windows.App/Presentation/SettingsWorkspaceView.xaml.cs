using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SettingsWorkspaceView : UserControl
{
    private readonly ControllerSettingsView _controllerSettingsView;
    private readonly WindowsUpdateWorkspaceView _updateView;

    internal SettingsWorkspaceView(
        MainWindowViewModel mainWindowViewModel,
        WindowsUpdateWorkspaceViewModel updateViewModel)
    {
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
        SettingsContent.Content = args.SelectedItemContainer?.Tag?.ToString() == "update"
            ? _updateView
            : _controllerSettingsView;
    }
}
