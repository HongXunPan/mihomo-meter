using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ProfileDirectoryChoiceDialog : ContentDialog
{
    public ProfileDirectoryChoiceDialog()
    {
        InitializeComponent();
    }

    public bool ShouldOpenPicker { get; private set; }

    public string? SuggestedDirectoryPath { get; private set; }

    private void BrowseOtherButton_Click(
        ContentDialog sender,
        ContentDialogButtonClickEventArgs args)
    {
        ShouldOpenPicker = true;
        SuggestedDirectoryPath = null;
    }

    private void SuggestedDirectoryButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not Button { Tag: string pathTemplate })
        {
            return;
        }

        var expandedPath = Environment.ExpandEnvironmentVariables(pathTemplate);
        ShouldOpenPicker = true;
        SuggestedDirectoryPath = Path.IsPathFullyQualified(expandedPath)
            ? expandedPath
            : null;
        Hide();
    }
}
