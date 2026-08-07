using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed partial class NotificationAreaMenu
{
    private const uint StartStatisticsCommand = 2001;
    private const uint OverflowStatisticsCommand = 2002;
    private const uint ViewStatisticsCommandBase = 2100;
    private const uint StopStatisticsCommandBase = 2200;
    private const int MaximumTaskNameLength = 40;

    private static void AppendStatisticsMenu(
        nint rootMenuHandle,
        NotificationAreaStatisticsMenuSnapshot snapshot,
        IDictionary<uint, NotificationAreaCommand> commands)
    {
        var statisticsMenuHandle = CreateMenu();
        var attached = false;
        try
        {
            if (snapshot.Notice is string notice)
            {
                AppendMenuItem(statisticsMenuHandle, 0, notice, isEnabled: false);
                AppendSeparator(statisticsMenuHandle);
            }

            AppendMenuItem(
                statisticsMenuHandle,
                StartStatisticsCommand,
                "开始新统计",
                snapshot.CanStart);
            if (snapshot.CanStart)
            {
                commands.Add(
                    StartStatisticsCommand,
                    new NotificationAreaCommand(
                        NotificationAreaCommandKind.StartStatistics));
            }

            AppendSeparator(statisticsMenuHandle);
            for (var index = 0;
                 index < TrafficStatisticsQuickTaskProjection.SlotCount;
                 index += 1)
            {
                var task = index < snapshot.Slots.Count
                    ? snapshot.Slots[index]
                    : null;
                AppendTaskSlot(statisticsMenuHandle, index, task, commands);
            }

            if (snapshot.AdditionalCount > 0)
            {
                AppendSeparator(statisticsMenuHandle);
                AppendMenuItem(
                    statisticsMenuHandle,
                    OverflowStatisticsCommand,
                    $"查看其余 {snapshot.AdditionalCount} 个任务…");
                commands.Add(
                    OverflowStatisticsCommand,
                    new NotificationAreaCommand(
                        NotificationAreaCommandKind.OpenStatistics));
            }

            AppendPopupMenuItem(
                rootMenuHandle,
                statisticsMenuHandle,
                $"统计任务（{snapshot.ActiveCount} 个进行中）");
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(statisticsMenuHandle);
            }
        }
    }

    private static void AppendTaskSlot(
        nint statisticsMenuHandle,
        int index,
        NotificationAreaStatisticsTaskSnapshot? task,
        IDictionary<uint, NotificationAreaCommand> commands)
    {
        if (task is null)
        {
            AppendMenuItem(
                statisticsMenuHandle,
                0,
                $"槽位 {index + 1} · 暂无任务",
                isEnabled: false);
            return;
        }

        var taskMenuHandle = CreateMenu();
        var attached = false;
        try
        {
            AppendMenuItem(taskMenuHandle, 0, task.TrafficText, isEnabled: false);
            AppendMenuItem(taskMenuHandle, 0, task.TimeText, isEnabled: false);
            AppendSeparator(taskMenuHandle);

            var viewCommand = ViewStatisticsCommandBase + (uint)index;
            AppendMenuItem(taskMenuHandle, viewCommand, "查看任务");
            commands.Add(
                viewCommand,
                new NotificationAreaCommand(
                    NotificationAreaCommandKind.OpenStatistics,
                    task.Id));

            if (task.IsActive)
            {
                var stopCommand = StopStatisticsCommandBase + (uint)index;
                AppendMenuItem(
                    taskMenuHandle,
                    stopCommand,
                    "停止任务",
                    task.CanStop);
                if (task.CanStop)
                {
                    commands.Add(
                        stopCommand,
                        new NotificationAreaCommand(
                            NotificationAreaCommandKind.StopStatistics,
                            task.Id));
                }
            }

            AppendPopupMenuItem(
                statisticsMenuHandle,
                taskMenuHandle,
                $"{NormalizeTaskName(task.Name)} · {task.StatusText}");
            attached = true;
        }
        finally
        {
            if (!attached)
            {
                ShellNativeMethods.DestroyMenu(taskMenuHandle);
            }
        }
    }

    private static string NormalizeTaskName(string name)
    {
        var normalized = string.Join(
            ' ',
            name.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (normalized.Length == 0)
        {
            return "未命名统计任务";
        }

        if (normalized.Length <= MaximumTaskNameLength)
        {
            return normalized;
        }

        var prefixLength = MaximumTaskNameLength - 1;
        if (char.IsHighSurrogate(normalized[prefixLength - 1]))
        {
            prefixLength -= 1;
        }

        return $"{normalized[..prefixLength].TrimEnd()}…";
    }
}
