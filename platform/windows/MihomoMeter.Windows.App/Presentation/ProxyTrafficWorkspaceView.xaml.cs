using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ProxyTrafficWorkspaceView : UserControl
{
    private readonly TrafficStatisticsWorkspaceView _statisticsView;
    private readonly LiveConnectionWorkspaceView _liveConnectionView;

    internal ProxyTrafficWorkspaceView(
        TrafficStatisticsWorkspaceView statisticsView,
        LiveConnectionWorkspaceView liveConnectionView)
    {
        _statisticsView = statisticsView;
        _liveConnectionView = liveConnectionView;
        InitializeComponent();
        ShowStatistics();
    }

    internal void ShowStatistics()
    {
        WorkspaceModeButtons.SelectedIndex = 0;
        WorkspaceContent.Content = _statisticsView;
    }

    internal void ShowLiveConnections(LiveConnectionRoute route)
    {
        _liveConnectionView.SelectRoute(route);
        WorkspaceModeButtons.SelectedIndex = 1;
        WorkspaceContent.Content = _liveConnectionView;
    }

    private void WorkspaceModeButtons_SelectionChanged(
        object sender,
        SelectionChangedEventArgs args)
    {
        WorkspaceContent.Content = WorkspaceModeButtons.SelectedIndex == 1
            ? _liveConnectionView
            : _statisticsView;
    }
}
