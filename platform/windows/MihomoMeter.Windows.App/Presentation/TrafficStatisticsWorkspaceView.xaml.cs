using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class TrafficStatisticsWorkspaceView : UserControl
{
    private bool _isDialogOpen;

    internal TrafficStatisticsWorkspaceView(TrafficStatisticsWorkspaceViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        DailyChartHost.Content = new ProxyDailyTrafficChartView(viewModel);
    }

    public TrafficStatisticsWorkspaceViewModel ViewModel { get; }

    private async void StartIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        var nameBox = new TextBox
        {
            Header = "任务名称",
            Text = ViewModel.SuggestedName,
        };
        var noteBox = new TextBox
        {
            AcceptsReturn = true,
            Header = "备注（可选）",
            TextWrapping = TextWrapping.Wrap,
        };
        var validation = new TextBlock
        {
            TextWrapping = TextWrapping.Wrap,
        };
        var content = new StackPanel { Spacing = 10 };
        content.Children.Add(nameBox);
        content.Children.Add(noteBox);
        content.Children.Add(validation);
        var dialog = CreateDialog("新建统计任务", "开始", content);
        dialog.PrimaryButtonClick += (_, eventArgs) =>
        {
            if (!string.IsNullOrWhiteSpace(nameBox.Text))
            {
                return;
            }

            validation.Text = "统计任务名称不能为空。";
            eventArgs.Cancel = true;
        };

        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.StartIntervalAsync(nameBox.Text, noteBox.Text);
        }
    }

    private async void StopIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is Button { Tag: Guid id })
        {
            await ViewModel.StopIntervalAsync(id);
        }
    }

    private async void RenameIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not Button { Tag: Guid id })
        {
            return;
        }

        var interval = ViewModel.Intervals.FirstOrDefault(item => item.Id == id);
        if (interval is null)
        {
            return;
        }

        var nameBox = new TextBox
        {
            Header = "任务名称",
            Text = interval.Name,
        };
        var validation = new TextBlock
        {
            TextWrapping = TextWrapping.Wrap,
        };
        var content = new StackPanel { Spacing = 10 };
        content.Children.Add(nameBox);
        content.Children.Add(validation);
        var dialog = CreateDialog($"重命名“{interval.Name}”", "保存", content);
        dialog.PrimaryButtonClick += (_, eventArgs) =>
        {
            if (!string.IsNullOrWhiteSpace(nameBox.Text))
            {
                return;
            }

            validation.Text = "统计任务名称不能为空。";
            eventArgs.Cancel = true;
        };

        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.RenameIntervalAsync(id, nameBox.Text);
        }
    }

    private async void DeleteIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not Button { Tag: Guid id })
        {
            return;
        }

        var interval = ViewModel.Intervals.FirstOrDefault(item => item.Id == id);
        if (interval is null)
        {
            return;
        }

        var dialog = CreateDialog(
            $"删除“{interval.Name}”？",
            "删除",
            "只删除该统计任务，不会改变今日或历史 Proxy 累计。");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.DeleteIntervalAsync(id);
        }
    }

    private async void ClearButton_Click(object sender, RoutedEventArgs args)
    {
        var dialog = CreateDialog(
            "清空本地统计？",
            "清空",
            "核心流量累计、全部统计任务、最近 30 天图表和连接归因历史都会删除；"
                + "Controller 地址、Credential Manager Secret 与悬浮图标设置会保留。");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.ClearAsync();
        }
    }

    private ContentDialog CreateDialog(string title, string primaryButtonText, object content)
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
