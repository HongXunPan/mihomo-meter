using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ConnectionAnalyticsTrendView : UserControl
{
    private readonly ConnectionAnalyticsTrendChartView _chart;

    internal ConnectionAnalyticsTrendView(
        ConnectionAnalyticsTrendWindowViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        _chart = new ConnectionAnalyticsTrendChartView(viewModel);
        ChartHost.Content = _chart;
    }

    public ConnectionAnalyticsTrendWindowViewModel ViewModel { get; }

    internal void Detach()
    {
        _chart.Detach();
    }

    private void RefreshButton_Click(object sender, RoutedEventArgs args)
    {
        ViewModel.Refresh();
    }
}
