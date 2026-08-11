using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SubscriptionQuotaWorkspaceView : UserControl
{
    private readonly Window _window;
    private readonly Action<SubscriptionQuotaCardViewModel> _showTrend;
    private bool _isDialogOpen;

    internal SubscriptionQuotaWorkspaceView(
        SubscriptionQuotaWorkspaceViewModel viewModel,
        Window window,
        Action<SubscriptionQuotaCardViewModel> showTrend)
    {
        ViewModel = viewModel;
        _window = window;
        _showTrend = showTrend ?? throw new ArgumentNullException(nameof(showTrend));
        InitializeComponent();
    }

    public SubscriptionQuotaWorkspaceViewModel ViewModel { get; }

    private void ShowTrendButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is FrameworkElement { Tag: SubscriptionQuotaCardViewModel card })
        {
            _showTrend(card);
        }
    }

    private async void ManageProfilesButton_Click(object sender, RoutedEventArgs args)
    {
        var managementView = new SubscriptionProfileManagementView(
            ViewModel,
            () => PickProfileDirectoryAsync(null));
        var dialog = new ContentDialog
        {
            Title = "管理追踪 Profile",
            Content = managementView,
            CloseButtonText = "完成",
            DefaultButton = ContentDialogButton.Close,
        };
        await ShowDialogAsync(dialog);
    }

    private async Task PickProfileDirectoryAsync(string? suggestedDirectoryPath)
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(_window);
        var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(windowHandle);
        var picker = new Microsoft.Windows.Storage.Pickers.FolderPicker(windowId)
        {
            CommitButtonText = "选择此目录",
            SettingsIdentifier = "MihomoMeter.ProfileDirectory",
            Title = "选择包含 profiles.yaml 的目录",
        };
        if (suggestedDirectoryPath is not null)
        {
            picker.SuggestedFolder = suggestedDirectoryPath;
        }

        var folder = await picker.PickSingleFolderAsync();
        if (folder is not null)
        {
            await ViewModel.SetProfileDirectoryAsync(folder.Path);
        }
    }

    private async void RefreshProfileButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is Button { Tag: Guid id })
        {
            await ViewModel.RefreshProfileAsync(id);
        }
    }

    private async void RefreshAllButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.RefreshAllAsync();
    }

    private async void ConfirmCycleButton_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not Button { Tag: Guid cycleId })
        {
            return;
        }

        var dialog = CreateDialog(
            "确认新的订阅周期？",
            "确认周期",
            "确认后，预计耗尽会只使用这个周期内满足条件的真实快照。"
                + "这不会修改机场订阅。 ");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.ConfirmCycleAsync(cycleId);
        }
    }

    private async void ClearButton_Click(object sender, RoutedEventArgs args)
    {
        var dialog = CreateDialog(
            "清空订阅余额数据？",
            "清空",
            "订阅身份、快照、周期、事件和查询状态都会删除；"
                + "Controller 配置、Profile 目录路径和指纹密钥会保留。"
                + "本机 Proxy 流量统计不会受影响。");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.ClearAsync();
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
