using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class RealtimeMonitoringView : UserControl
{
    internal RealtimeMonitoringView(MainWindowViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public MainWindowViewModel ViewModel { get; }

    private async void ConnectButton_Click(object sender, RoutedEventArgs args)
    {
        var secret = SecretPasswordBox.Password;
        var forceEmptySecret = ForceEmptySecretCheckBox.IsChecked == true;
        SecretPasswordBox.Password = string.Empty;
        ForceEmptySecretCheckBox.IsChecked = false;
        try
        {
            await ViewModel.ConnectAsync(secret, forceEmptySecret);
        }
        catch (Exception exception)
        {
            ViewModel.ShowError(exception.Message);
        }
    }

    private async void DisconnectButton_Click(object sender, RoutedEventArgs args)
    {
        try
        {
            await ViewModel.DisconnectAsync();
        }
        catch (Exception exception)
        {
            ViewModel.ShowError(exception.Message);
        }
    }
}
