using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed partial class NotificationAreaMenu
{
    private const uint OpenQuotaCommand = 3001;
    private const uint RefreshQuotaCommand = 3002;

    private static void AppendQuotaMenu(
        nint rootMenuHandle,
        NotificationAreaQuotaMenuSnapshot snapshot,
        IDictionary<uint, NotificationAreaCommand> commands)
    {
        var quotaMenuHandle = CreateMenu();
        var attached = false;
        try
        {
            if (snapshot.Notice is string notice)
            {
                AppendMenuItem(quotaMenuHandle, 0, notice, isEnabled: false);
                AppendSeparator(quotaMenuHandle);
            }

            foreach (var item in snapshot.Items)
            {
                AppendMenuItem(quotaMenuHandle, 0, item.Name, isEnabled: false);
                AppendMenuItem(quotaMenuHandle, 0, $"  {item.Summary}", isEnabled: false);
                AppendMenuItem(quotaMenuHandle, 0, $"  {item.Detail}", isEnabled: false);
                AppendSeparator(quotaMenuHandle);
            }

            if (snapshot.AdditionalCount > 0)
            {
                AppendMenuItem(
                    quotaMenuHandle,
                    0,
                    $"另有 {snapshot.AdditionalCount} 个订阅，请在完整窗口查看。",
                    isEnabled: false);
                AppendSeparator(quotaMenuHandle);
            }

            AppendMenuItem(quotaMenuHandle, OpenQuotaCommand, "查看订阅余额…");
            commands.Add(
                OpenQuotaCommand,
                new NotificationAreaCommand(NotificationAreaCommandKind.OpenQuota));
            AppendMenuItem(
                quotaMenuHandle,
                RefreshQuotaCommand,
                "立即查询全部",
                snapshot.CanRefreshAll);
            if (snapshot.CanRefreshAll)
            {
                commands.Add(
                    RefreshQuotaCommand,
                    new NotificationAreaCommand(NotificationAreaCommandKind.RefreshQuota));
            }

            AppendPopupMenuItem(rootMenuHandle, quotaMenuHandle, snapshot.Title);
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(quotaMenuHandle);
            }
        }
    }
}
