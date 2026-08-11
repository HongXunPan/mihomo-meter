using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class FirstConnectionGuideView : UserControl
{
    private readonly Action _showControllerSettings;

    internal FirstConnectionGuideView(Action showControllerSettings)
    {
        _showControllerSettings = showControllerSettings
            ?? throw new ArgumentNullException(nameof(showControllerSettings));
        InitializeComponent();
    }

    private void OpenSettingsButton_Click(object sender, RoutedEventArgs args)
    {
        _showControllerSettings();
    }
}
