namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed partial class NotificationAreaMenu
{
    private const uint OpenCommand = 1001;
    private const uint ToggleFloatingWidgetCommand = 1002;
    private const uint ExitCommand = 1003;

    private const uint StartStatisticsCommand = 2001;
    private const uint OverflowStatisticsCommand = 2002;
    private const uint ViewStatisticsCommandBase = 2100;
    private const uint StopStatisticsCommandBase = 2200;

    private const uint OpenQuotaCommand = 3001;
    private const uint RefreshQuotaCommand = 3002;

    private const uint OpenProxyConnectionsCommand = 4001;
    private const uint OpenDirectConnectionsCommand = 4002;

    private const uint OpenConnectionAnalyticsCommand = 5001;
    private const uint OpenSettingsCommand = 5002;
    private const uint CheckUpdatesCommand = 5003;

    private static void RegisterCommand(
        IDictionary<uint, NotificationAreaCommand> commands,
        uint commandId,
        NotificationAreaCommand command)
    {
        if (!commands.TryAdd(commandId, command))
        {
            throw new InvalidOperationException(
                $"通知区域菜单命令 ID 重复：{commandId}。");
        }
    }
}
