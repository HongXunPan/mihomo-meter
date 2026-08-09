using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class WindowsUpdateWorkspaceView : UserControl
{
    internal WindowsUpdateWorkspaceView(WindowsUpdateWorkspaceViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public WindowsUpdateWorkspaceViewModel ViewModel { get; }

    private async void CheckButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.CheckAsync();
    }

    private async void OpenReleaseButton_Click(object sender, RoutedEventArgs args)
    {
        var releasePageUri = ViewModel.ReleasePageUri;
        if (releasePageUri is null
            || !await global::Windows.System.Launcher.LaunchUriAsync(releasePageUri))
        {
            ViewModel.ReportOpenFailure();
        }
    }
}
