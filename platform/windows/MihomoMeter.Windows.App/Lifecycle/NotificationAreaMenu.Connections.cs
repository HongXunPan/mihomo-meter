using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed partial class NotificationAreaMenu
{
    private const uint OpenProxyConnectionsCommand = 3001;
    private const uint OpenDirectConnectionsCommand = 3002;

    private static void AppendConnectionsMenu(
        nint rootMenuHandle,
        NotificationAreaConnectionsMenuSnapshot snapshot,
        IDictionary<uint, NotificationAreaCommand> commands)
    {
        AppendConnectionRouteMenu(
            rootMenuHandle,
            "活动 Proxy Top 5",
            snapshot.Proxy,
            LiveConnectionRoute.Proxy,
            OpenProxyConnectionsCommand,
            commands);
        AppendConnectionRouteMenu(
            rootMenuHandle,
            "活动直连 Top 5",
            snapshot.Direct,
            LiveConnectionRoute.Direct,
            OpenDirectConnectionsCommand,
            commands);
    }

    private static void AppendConnectionRouteMenu(
        nint rootMenuHandle,
        string title,
        NotificationAreaConnectionRouteSnapshot snapshot,
        LiveConnectionRoute route,
        uint openCommand,
        IDictionary<uint, NotificationAreaCommand> commands)
    {
        var routeMenuHandle = CreateMenu();
        var attached = false;
        try
        {
            for (var index = 0; index < LiveConnectionProjection.TopSlotCount; index += 1)
            {
                var slot = index < snapshot.Slots.Count ? snapshot.Slots[index] : null;
                AppendConnectionSlot(routeMenuHandle, index, slot);
            }

            AppendSeparator(routeMenuHandle);
            AppendMenuItem(routeMenuHandle, openCommand, "查看实时连接…");
            commands.Add(
                openCommand,
                new NotificationAreaCommand(
                    NotificationAreaCommandKind.OpenLiveConnections,
                    Route: route));
            AppendPopupMenuItem(
                rootMenuHandle,
                routeMenuHandle,
                $"{title}（{snapshot.ActiveCount} 条活跃）");
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(routeMenuHandle);
            }
        }
    }

    private static void AppendConnectionSlot(
        nint routeMenuHandle,
        int index,
        NotificationAreaConnectionSlotSnapshot? slot)
    {
        if (slot is null)
        {
            AppendMenuItem(
                routeMenuHandle,
                0,
                $"槽位 {index + 1} · 暂无传输",
                isEnabled: false);
            return;
        }

        var slotMenuHandle = CreateMenu();
        var attached = false;
        try
        {
            AppendMenuItem(slotMenuHandle, 0, slot.RateText, isEnabled: false);
            AppendMenuItem(slotMenuHandle, 0, slot.CumulativeText, isEnabled: false);
            AppendPopupMenuItem(
                routeMenuHandle,
                slotMenuHandle,
                $"{index + 1}. {slot.Title}");
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(slotMenuHandle);
            }
        }
    }
}
