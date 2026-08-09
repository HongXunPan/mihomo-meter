using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ConnectionAnalyticsWorkspaceView : UserControl
{
    private readonly Action<ConnectionAnalyticsTrendTarget> _showTrend;
    private bool _isDialogOpen;

    internal ConnectionAnalyticsWorkspaceView(
        ConnectionAnalyticsWorkspaceViewModel viewModel,
        Action<ConnectionAnalyticsTrendTarget> showTrend)
    {
        ViewModel = viewModel;
        _showTrend = showTrend;
        InitializeComponent();
    }

    public ConnectionAnalyticsWorkspaceViewModel ViewModel { get; }

    private async void HistoryToggle_Toggled(object sender, RoutedEventArgs args)
    {
        if (sender is not ToggleSwitch toggle
            || toggle.IsOn == ViewModel.IsHistoryEnabled)
        {
            return;
        }

        if (toggle.IsOn)
        {
            var dialog = CreateDialog(
                "开启历史归因？",
                "开启记录",
                "开启后，只把可靠 Proxy 增量按本地日期、应用名称和完整主机名聚合到独立数据库。"
                    + "不会保存连接明细、IP、端口或进程路径。");
            if (await ShowDialogAsync(dialog) != ContentDialogResult.Primary)
            {
                toggle.IsOn = false;
                return;
            }
        }

        await ViewModel.SetHistoryEnabledAsync(toggle.IsOn);
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.RefreshAsync();
    }

    private async void ClearButton_Click(object sender, RoutedEventArgs args)
    {
        var dialog = CreateDialog(
            "清空连接归因历史？",
            "清空",
            "只删除独立归因数据库中的应用与主机名日聚合；核心流量、统计任务、配额、"
                + "Controller 配置和凭据都会保留。");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.ClearHistoryAsync();
        }
    }

    private void RankingButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is Button { Tag: ConnectionAnalyticsRankingRowViewModel row })
        {
            _showTrend(ViewModel.TrendTarget(row));
        }
    }

    private static ContentDialog CreateDialog(
        string title,
        string primaryButtonText,
        object content)
    {
        return new ContentDialog
        {
            Title = title,
            Content = content,
            PrimaryButtonText = primaryButtonText,
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary,
        };
    }

    private async Task<ContentDialogResult> ShowDialogAsync(ContentDialog dialog)
    {
        if (_isDialogOpen)
        {
            return ContentDialogResult.None;
        }

        _isDialogOpen = true;
        try
        {
            dialog.XamlRoot = Root.XamlRoot;
            return await dialog.ShowAsync();
        }
        finally
        {
            _isDialogOpen = false;
        }
    }
}
