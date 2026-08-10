using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed partial class NotificationAreaMenu
{
    private static void AppendRealtimeMenus(
        nint rootMenuHandle,
        NotificationAreaRealtimeMenuSnapshot snapshot)
    {
        AppendClassificationMenu(rootMenuHandle, snapshot);
        AppendRoutingMenu(rootMenuHandle, snapshot);
    }

    private static void AppendClassificationMenu(
        nint rootMenuHandle,
        NotificationAreaRealtimeMenuSnapshot snapshot)
    {
        var submenuHandle = CreateMenu();
        var attached = false;
        try
        {
            AppendMenuItem(submenuHandle, 0, snapshot.ProxyRateText, isEnabled: false);
            AppendMenuItem(submenuHandle, 0, snapshot.DirectRateText, isEnabled: false);
            AppendMenuItem(submenuHandle, 0, snapshot.RejectRateText, isEnabled: false);
            AppendMenuItem(submenuHandle, 0, snapshot.UnknownRateText, isEnabled: false);
            AppendSeparator(submenuHandle);
            AppendMenuItem(submenuHandle, 0, snapshot.CoverageText, isEnabled: false);
            AppendPopupMenuItem(rootMenuHandle, submenuHandle, "分类状态");
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(submenuHandle);
            }
        }
    }

    private static void AppendRoutingMenu(
        nint rootMenuHandle,
        NotificationAreaRealtimeMenuSnapshot snapshot)
    {
        var submenuHandle = CreateMenu();
        var attached = false;
        try
        {
            AppendMenuItem(
                submenuHandle,
                0,
                $"实际出口：{snapshot.ProxySummary}",
                isEnabled: false);
            if (!string.Equals(snapshot.ProxySummary, snapshot.ProxyDetails, StringComparison.Ordinal))
            {
                AppendMenuItem(submenuHandle, 0, $"  {snapshot.ProxyDetails}", isEnabled: false);
            }
            AppendMenuItem(
                submenuHandle,
                0,
                $"运行方式：{snapshot.RuntimeSummary}",
                isEnabled: false);
            AppendMenuItem(
                submenuHandle,
                0,
                $"命中规则：{snapshot.RuleSummary}",
                isEnabled: false);
            if (!string.Equals(snapshot.RuleSummary, snapshot.RuleDetails, StringComparison.Ordinal))
            {
                AppendMenuItem(submenuHandle, 0, $"  {snapshot.RuleDetails}", isEnabled: false);
            }
            AppendSeparator(submenuHandle);
            AppendMenuItem(submenuHandle, 0, "运行详情", isEnabled: false);
            foreach (var detail in snapshot.RuntimeDetails)
            {
                AppendMenuItem(submenuHandle, 0, detail, isEnabled: false);
            }
            AppendPopupMenuItem(rootMenuHandle, submenuHandle, "路由状态");
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(submenuHandle);
            }
        }
    }
}
