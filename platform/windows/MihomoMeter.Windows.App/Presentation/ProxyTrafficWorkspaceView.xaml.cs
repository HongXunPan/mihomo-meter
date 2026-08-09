using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ProxyTrafficWorkspaceView : UserControl
{
    private readonly TrafficStatisticsWorkspaceView _statisticsView;
    private readonly LiveConnectionWorkspaceView _liveConnectionView;
    private readonly ConnectionAnalyticsWorkspaceView _connectionAnalyticsView;

    internal ProxyTrafficWorkspaceView(
        TrafficStatisticsWorkspaceView statisticsView,
        LiveConnectionWorkspaceView liveConnectionView,
        ConnectionAnalyticsWorkspaceView connectionAnalyticsView)
    {
        _statisticsView = statisticsView;
        _liveConnectionView = liveConnectionView;
        _connectionAnalyticsView = connectionAnalyticsView;
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
        WorkspaceContent.Content = WorkspaceModeButtons.SelectedIndex switch
        {
            1 => _liveConnectionView,
            2 => _connectionAnalyticsView,
            _ => _statisticsView,
        };
    }
}
