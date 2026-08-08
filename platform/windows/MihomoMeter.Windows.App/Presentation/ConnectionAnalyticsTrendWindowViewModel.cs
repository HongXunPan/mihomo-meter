using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed class ConnectionAnalyticsTrendWindowViewModel : INotifyPropertyChanged
{
    private readonly ConnectionAnalyticsCoordinator _connectionAnalytics;
    private ConnectionAnalyticsTrendTarget? _target;
    private ConnectionAnalyticsTrend? _trend;
    private CancellationTokenSource? _requestSource;
    private string? _message;
    private long _requestGeneration;
    private bool _isLoading;

    internal ConnectionAnalyticsTrendWindowViewModel(
        ConnectionAnalyticsCoordinator connectionAnalytics)
    {
        _connectionAnalytics = connectionAnalytics;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public ConnectionAnalyticsTrend? Trend => _trend;

    public string Title => _target is null
        ? "连接归因趋势"
        : $"{DimensionTitle(_target.Dimension)} · {_target.Name}";

    public string FilterDescription => _target?.InheritedFilterDescription
        ?? "未附加另一维筛选";

    public string TotalText => _trend is null
        ? "--"
        : TrafficDisplayFormatter.ByteCount(_trend.TotalBytes.Total);

    public string AverageText => _trend is null
        ? "--"
        : TrafficDisplayFormatter.ByteCount(_trend.ActiveDailyAverageBytes);

    public string PeakText => _trend?.PeakPoint is { } peak
        ? $"{peak.LocalDay} · {TrafficDisplayFormatter.ByteCount(peak.Bytes.Total)}"
        : "暂无流量";

    public string ActiveDayText => _trend is null ? "--" : $"{_trend.ActiveDayCount} 天";

    public Visibility LoadingVisibility => _isLoading
        ? Visibility.Visible
        : Visibility.Collapsed;

    public bool IsMessageOpen => !string.IsNullOrWhiteSpace(_message);

    public string Message => _message ?? string.Empty;

    public bool CanRefresh => _target is not null && !_isLoading;

    internal void Show(ConnectionAnalyticsTrendTarget target)
    {
        var keepsPreviousResult = Equals(_target, target);
        CancelRequest();
        _target = target;
        if (!keepsPreviousResult)
        {
            _trend = null;
        }
        _message = null;
        _isLoading = true;
        NotifyAll();
        var source = new CancellationTokenSource();
        _requestSource = source;
        var generation = Interlocked.Increment(ref _requestGeneration);
        _ = LoadAsync(target, generation, source.Token);
    }

    internal void Refresh()
    {
        if (_target is not null)
        {
            Show(_target);
        }
    }

    internal void Reset()
    {
        CancelRequest();
        _ = Interlocked.Increment(ref _requestGeneration);
        _target = null;
        _trend = null;
        _message = null;
        _isLoading = false;
        NotifyAll();
    }

    private async Task LoadAsync(
        ConnectionAnalyticsTrendTarget target,
        long generation,
        CancellationToken cancellationToken)
    {
        try
        {
            var trend = await _connectionAnalytics
                .TrendAsync(target.Query, cancellationToken)
                .ConfigureAwait(true);
            if (generation != Volatile.Read(ref _requestGeneration)
                || cancellationToken.IsCancellationRequested)
            {
                return;
            }
            _trend = trend;
            _message = null;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return;
        }
        catch (Exception exception)
        {
            if (generation != Volatile.Read(ref _requestGeneration))
            {
                return;
            }
            _message = exception.Message;
        }
        finally
        {
            if (generation == Volatile.Read(ref _requestGeneration))
            {
                _isLoading = false;
                NotifyAll();
            }
        }
    }

    private void CancelRequest()
    {
        var source = _requestSource;
        _requestSource = null;
        source?.Cancel();
        source?.Dispose();
    }

    private void NotifyAll()
    {
        OnPropertyChanged(nameof(Trend));
        OnPropertyChanged(nameof(Title));
        OnPropertyChanged(nameof(FilterDescription));
        OnPropertyChanged(nameof(TotalText));
        OnPropertyChanged(nameof(AverageText));
        OnPropertyChanged(nameof(PeakText));
        OnPropertyChanged(nameof(ActiveDayText));
        OnPropertyChanged(nameof(LoadingVisibility));
        OnPropertyChanged(nameof(IsMessageOpen));
        OnPropertyChanged(nameof(Message));
        OnPropertyChanged(nameof(CanRefresh));
    }

    private static string DimensionTitle(ConnectionAnalyticsRankingDimension dimension)
    {
        return dimension == ConnectionAnalyticsRankingDimension.Application
            ? "应用趋势"
            : "域名趋势";
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
