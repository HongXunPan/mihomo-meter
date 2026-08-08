using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class LiveConnectionWorkspaceView : UserControl
{
    internal LiveConnectionWorkspaceView(LiveConnectionWorkspaceViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public LiveConnectionWorkspaceViewModel ViewModel { get; }

    internal void SelectRoute(LiveConnectionRoute route)
    {
        ViewModel.SelectRoute(route);
    }
}
