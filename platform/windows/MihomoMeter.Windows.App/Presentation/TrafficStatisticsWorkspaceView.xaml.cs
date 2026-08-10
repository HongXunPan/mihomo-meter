using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class TrafficStatisticsWorkspaceView : UserControl
{
    private bool _isDialogOpen;
    private Guid? _editingIntervalId;

    internal TrafficStatisticsWorkspaceView(TrafficStatisticsWorkspaceViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        DailyChartHost.Content = new ProxyDailyTrafficChartView(viewModel);
        IntervalFilterButtons.SelectedIndex = 0;
    }

    public TrafficStatisticsWorkspaceViewModel ViewModel { get; }

    private void StartIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        ShowIntervalEditor(null, ViewModel.SuggestedName);
    }

    private async void StopIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is FrameworkElement { Tag: Guid id })
        {
            await ViewModel.StopIntervalAsync(id);
        }
    }

    private void RenameIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not FrameworkElement { Tag: Guid id })
        {
            return;
        }

        var interval = ViewModel.Intervals.FirstOrDefault(item => item.Id == id);
        if (interval is null)
        {
            return;
        }

        ShowIntervalEditor(id, interval.Name);
    }

    private async void DeleteIntervalButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not FrameworkElement { Tag: Guid id })
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

    private async void SaveIntervalEditorButton_Click(object sender, RoutedEventArgs args)
    {
        var name = IntervalNameBox.Text.Trim();
        if (name.Length == 0)
        {
            IntervalEditorValidation.Text = "统计任务名称不能为空。";
            return;
        }

        if (_editingIntervalId is Guid id)
        {
            await ViewModel.RenameIntervalAsync(id, name);
        }
        else
        {
            await ViewModel.StartIntervalAsync(name, null);
            ViewModel.SelectedFilter = ViewModel.FilterOptions.First(option =>
                option.Filter == TrafficStatisticsIntervalFilter.Active);
            IntervalFilterButtons.SelectedIndex = 1;
        }
        HideIntervalEditor();
    }

    private void CancelIntervalEditorButton_Click(object sender, RoutedEventArgs args)
    {
        HideIntervalEditor();
    }

    private void IntervalFilterButtons_SelectionChanged(
        object sender,
        SelectionChangedEventArgs args)
    {
        var filter = IntervalFilterButtons.SelectedIndex switch
        {
            1 => TrafficStatisticsIntervalFilter.Active,
            2 => TrafficStatisticsIntervalFilter.History,
            _ => TrafficStatisticsIntervalFilter.All,
        };
        ViewModel.SelectedFilter = ViewModel.FilterOptions.First(option =>
            option.Filter == filter);
    }

    private void ShowIntervalEditor(Guid? intervalId, string name)
    {
        _editingIntervalId = intervalId;
        IntervalEditorTitle.Text = intervalId is null ? "新建统计任务" : "重命名统计任务";
        IntervalNameBox.Text = name;
        IntervalEditorValidation.Text = string.Empty;
        IntervalEditor.Visibility = Visibility.Visible;
        IntervalNameBox.Focus(FocusState.Programmatic);
        IntervalNameBox.SelectAll();
    }

    private void HideIntervalEditor()
    {
        _editingIntervalId = null;
        IntervalEditor.Visibility = Visibility.Collapsed;
        IntervalEditorValidation.Text = string.Empty;
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
