using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Storage.Pickers;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class SubscriptionQuotaWorkspaceView : UserControl
{
    private const string CommonProfileDirectory =
        @"%APPDATA%\io.github.clash-verge-rev.clash-verge-rev";
    private readonly Window _window;
    private bool _isDialogOpen;

    internal SubscriptionQuotaWorkspaceView(
        SubscriptionQuotaWorkspaceViewModel viewModel,
        Window window)
    {
        ViewModel = viewModel;
        _window = window;
        InitializeComponent();
    }

    public SubscriptionQuotaWorkspaceViewModel ViewModel { get; }

    private async void SelectDirectoryButton_Click(object sender, RoutedEventArgs args)
    {
        var dialog = CreateDialog(
            "选择 Profile 目录",
            "打开文件夹选择器",
            CreateProfileDirectoryHint());
        if (await ShowDialogAsync(dialog) != ContentDialogResult.Primary)
        {
            return;
        }

        var picker = new FolderPicker
        {
            SuggestedStartLocation = PickerLocationId.DocumentsLibrary,
        };
        picker.FileTypeFilter.Add("*");
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(_window);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, windowHandle);
        var folder = await picker.PickSingleFolderAsync();
        if (folder is not null)
        {
            await ViewModel.SetProfileDirectoryAsync(folder.Path);
        }
    }

    private static StackPanel CreateProfileDirectoryHint()
    {
        var content = new StackPanel
        {
            Spacing = 8,
        };
        content.Children.Add(new TextBlock
        {
            Text = "请选择根部直接包含 profiles.yaml 的目录。"
                + "Windows 上的常见位置是：",
            TextWrapping = TextWrapping.Wrap,
        });
        content.Children.Add(new TextBlock
        {
            IsTextSelectionEnabled = true,
            Text = CommonProfileDirectory,
            TextWrapping = TextWrapping.Wrap,
        });
        content.Children.Add(new TextBlock
        {
            Text = "请选择上述目录本身，不要选择其中的 profiles 子目录。",
            TextWrapping = TextWrapping.Wrap,
        });
        return content;
    }

    private async void StopDirectoryAccessButton_Click(object sender, RoutedEventArgs args)
    {
        var dialog = CreateDialog(
            "停止访问 Profile 目录？",
            "停止访问",
            "目录观察会停止，已记录的配额历史会保留，相关 Profile 追踪会暂停。");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.ClearProfileDirectoryAsync();
        }
    }

    private async void EnableRuntimeButton_Click(object sender, RoutedEventArgs args)
    {
        var dialog = CreateDialog(
            "启用当前运行订阅追踪？",
            "确认启用",
            "Mihomo Meter 只会在唯一有效候选时记录累计配额；来源变化会自动暂停。"
                + "机场配额不会与本机 Proxy 流量对账。");
        if (await ShowDialogAsync(dialog) == ContentDialogResult.Primary)
        {
            await ViewModel.EnableRuntimeAsync();
        }
    }

    private async void PauseRuntimeButton_Click(object sender, RoutedEventArgs args)
    {
        await ViewModel.PauseRuntimeAsync();
    }

    private async void ProfileTracking_Toggled(object sender, RoutedEventArgs args)
    {
        if (sender is ToggleSwitch { Tag: ProfileTrackingOptionViewModel profile } toggle
            && toggle.IsOn != profile.IsTracked)
        {
            await ViewModel.SetProfileTrackingAsync(profile, toggle.IsOn);
        }
    }

    private async void RefreshInterval_SelectionChanged(
        object sender,
        SelectionChangedEventArgs args)
    {
        if (sender is ComboBox { Tag: ProfileTrackingOptionViewModel profile }
            && profile.IsTracked)
        {
            await ViewModel.SetRefreshIntervalAsync(profile);
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
