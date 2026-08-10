using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SubscriptionProfileManagementView : UserControl
{
    private readonly Func<Task> _selectDirectory;

    internal SubscriptionProfileManagementView(
        SubscriptionQuotaWorkspaceViewModel viewModel,
        Func<Task> selectDirectory)
    {
        ViewModel = viewModel;
        _selectDirectory = selectDirectory
            ?? throw new ArgumentNullException(nameof(selectDirectory));
        InitializeComponent();
    }

    public SubscriptionQuotaWorkspaceViewModel ViewModel { get; }

    private async void SelectDirectoryButton_Click(object sender, RoutedEventArgs args)
    {
        await _selectDirectory();
    }

    private async void StopDirectoryAccessButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.ClearProfileDirectoryAsync();
    }

    private async void EnableRuntimeButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.EnableRuntimeAsync();
    }

    private async void PauseRuntimeButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.PauseRuntimeAsync();
    }

    private async void ProfileTracking_Toggled(object sender, RoutedEventArgs args)
    {
        if (sender is ToggleSwitch { Tag: ProfileTrackingOptionViewModel profile } toggle
            && toggle.IsOn != profile.IsTracked)
        {
            await ViewModel.SetProfileTrackingAsync(profile, toggle.IsOn);
        }
    }

    private async void RefreshInterval_SelectionChanged(
        object sender,
        SelectionChangedEventArgs args)
    {
        if (sender is ComboBox { Tag: ProfileTrackingOptionViewModel profile }
            && profile.IsTracked)
        {
            await ViewModel.SetRefreshIntervalAsync(profile);
        }
    }
}
