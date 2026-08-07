using System.ComponentModel;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed record TrafficStatisticsFilterOption(
    TrafficStatisticsIntervalFilter Filter,
    string Title);

public sealed class TrafficIntervalRowViewModel : INotifyPropertyChanged
{
    private string _name;
    private string _noteText;
    private Visibility _noteVisibility;
    private string _statusText;
    private string _timeText;
    private string _downloadText;
    private string _uploadText;
    private string _totalText;
    private Visibility _stopVisibility;
    private bool _canOperate;
    private string _automationName;

    internal TrafficIntervalRowViewModel(
        Guid id,
        string name,
        string noteText,
        Visibility noteVisibility,
        string statusText,
        string timeText,
        string downloadText,
        string uploadText,
        string totalText,
        Visibility stopVisibility,
        bool canOperate,
        string automationName)
    {
        Id = id;
        _name = name;
        _noteText = noteText;
        _noteVisibility = noteVisibility;
        _statusText = statusText;
        _timeText = timeText;
        _downloadText = downloadText;
        _uploadText = uploadText;
        _totalText = totalText;
        _stopVisibility = stopVisibility;
        _canOperate = canOperate;
        _automationName = automationName;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public Guid Id { get; }

    public string Name => _name;

    public string NoteText => _noteText;

    public Visibility NoteVisibility => _noteVisibility;

    public string StatusText => _statusText;

    public string TimeText => _timeText;

    public string DownloadText => _downloadText;

    public string UploadText => _uploadText;

    public string TotalText => _totalText;

    public Visibility StopVisibility => _stopVisibility;

    public bool CanOperate => _canOperate;

    public string AutomationName => _automationName;

    internal void Apply(TrafficIntervalRowViewModel snapshot)
    {
        if (Id != snapshot.Id)
        {
            throw new InvalidOperationException("不能使用其他任务的展示快照更新当前任务行。");
        }

        SetField(ref _name, snapshot.Name, nameof(Name));
        SetField(ref _noteText, snapshot.NoteText, nameof(NoteText));
        SetField(ref _noteVisibility, snapshot.NoteVisibility, nameof(NoteVisibility));
        SetField(ref _statusText, snapshot.StatusText, nameof(StatusText));
        SetField(ref _timeText, snapshot.TimeText, nameof(TimeText));
        SetField(ref _downloadText, snapshot.DownloadText, nameof(DownloadText));
        SetField(ref _uploadText, snapshot.UploadText, nameof(UploadText));
        SetField(ref _totalText, snapshot.TotalText, nameof(TotalText));
        SetField(ref _stopVisibility, snapshot.StopVisibility, nameof(StopVisibility));
        SetField(ref _canOperate, snapshot.CanOperate, nameof(CanOperate));
        SetField(ref _automationName, snapshot.AutomationName, nameof(AutomationName));
    }

    private void SetField<T>(ref T field, T value, string name)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}

public sealed class TrafficDailyChartPointViewModel : INotifyPropertyChanged
{
    private double _uploadHeight;
    private double _downloadHeight;
    private string _automationName;
    private string _axisLabel;
    private Visibility _axisLabelVisibility;

    internal TrafficDailyChartPointViewModel(
        string localDay,
        double uploadHeight,
        double downloadHeight,
        string automationName,
        string axisLabel,
        Visibility axisLabelVisibility)
    {
        LocalDay = localDay;
        _uploadHeight = uploadHeight;
        _downloadHeight = downloadHeight;
        _automationName = automationName;
        _axisLabel = axisLabel;
        _axisLabelVisibility = axisLabelVisibility;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public string LocalDay { get; }

    public double UploadHeight => _uploadHeight;

    public double DownloadHeight => _downloadHeight;

    public string AutomationName => _automationName;

    public string AxisLabel => _axisLabel;

    public Visibility AxisLabelVisibility => _axisLabelVisibility;

    internal void Apply(TrafficDailyChartPointViewModel snapshot)
    {
        if (!string.Equals(LocalDay, snapshot.LocalDay, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("不能使用其他日期的展示快照更新当前图表柱。");
        }

        SetField(ref _uploadHeight, snapshot.UploadHeight, nameof(UploadHeight));
        SetField(ref _downloadHeight, snapshot.DownloadHeight, nameof(DownloadHeight));
        SetField(ref _automationName, snapshot.AutomationName, nameof(AutomationName));
        SetField(ref _axisLabel, snapshot.AxisLabel, nameof(AxisLabel));
        SetField(
            ref _axisLabelVisibility,
            snapshot.AxisLabelVisibility,
            nameof(AxisLabelVisibility));
    }

    private void SetField<T>(ref T field, T value, string name)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}

internal static class TrafficStatisticsWorkspaceModelFactory
{
    private const double ChartHeight = 119;

    public static TrafficIntervalRowViewModel IntervalRow(
        TrafficInterval interval,
        bool statisticsAvailable,
        bool canOperate,
        DateTimeOffset now)
    {
        var statusText = TrafficDisplayFormatter.IntervalStatus(
            interval,
            statisticsAvailable);
        var noteText = interval.Note ?? string.Empty;
        var download = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Download);
        var upload = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Upload);
        var total = TrafficDisplayFormatter.ByteCount(interval.ProxyUsage.Total);
        return new TrafficIntervalRowViewModel(
            interval.Id,
            interval.Name,
            noteText,
            noteText.Length == 0 ? Visibility.Collapsed : Visibility.Visible,
            statusText,
            TrafficDisplayFormatter.IntervalTime(interval, now),
            $"↓ {download}",
            $"↑ {upload}",
            $"合计 {total}",
            interval.Status == TrafficIntervalStatus.Active
                ? Visibility.Visible
                : Visibility.Collapsed,
            canOperate,
            $"{interval.Name}，{statusText}，下载 {download}，上传 {upload}，合计 {total}");
    }

    public static TrafficDailyChartPointViewModel ChartPoint(TrafficDailyChartPoint point)
    {
        var download = TrafficDisplayFormatter.ByteCount(point.Bytes.Download);
        var upload = TrafficDisplayFormatter.ByteCount(point.Bytes.Upload);
        var total = TrafficDisplayFormatter.ByteCount(point.Bytes.Total);
        return new TrafficDailyChartPointViewModel(
            point.LocalDay,
            point.UploadFraction * ChartHeight,
            point.DownloadFraction * ChartHeight,
            $"{point.LocalDay}，下载 {download}，上传 {upload}，合计 {total}",
            ShortDay(point.LocalDay),
            point.ShowsAxisLabel ? Visibility.Visible : Visibility.Collapsed);
    }

    private static string ShortDay(string localDay)
    {
        var components = localDay.Split('-');
        return components.Length == 3
            ? $"{components[1]}/{components[2]}"
            : localDay;
    }

}
