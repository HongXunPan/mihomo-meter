using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ProxyDailyTrafficChartView : UserControl
{
    internal ProxyDailyTrafficChartView(TrafficStatisticsWorkspaceViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public TrafficStatisticsWorkspaceViewModel ViewModel { get; }
}
