using System.ComponentModel;
using Microsoft.UI.Xaml;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed record QuotaWindowOption(QuotaTrendWindow Window, string Title);

internal static class QuotaTrendWindowOptions
{
    public static IReadOnlyList<QuotaWindowOption> All { get; } =
    [
        new(QuotaTrendWindow.Day, "24 小时"),
        new(QuotaTrendWindow.Week, "7 天"),
        new(QuotaTrendWindow.Month, "30 天"),
        new(QuotaTrendWindow.Year, "12 月"),
    ];
}

public sealed record QuotaEventSummaryViewModel(
    string Symbol,
    string Text,
    string TimingText);

public sealed class SubscriptionQuotaCardViewModel : INotifyPropertyChanged
{
    private string _name;
    private string _identityText;
    private string _remainingText;
    private string _usedText;
    private string _totalText;
    private string _percentageText;
    private double _remainingRatio;
    private string _updatedText;
    private string _expirationText;
    private string _forecastText;
    private string _statusText;
    private bool _canRefresh;
    private Visibility _refreshVisibility;
    private Visibility _confirmVisibility;
    private QuotaTrendChartModel _chartModel;
    private IReadOnlyList<QuotaEventSummaryViewModel> _recentEvents;
    private Visibility _recentEventsVisibility;
    private IReadOnlyDictionary<QuotaTrendWindow, QuotaTrendChartModel> _trendModels;
    private QuotaWindowOption _selectedDetailWindow;

    internal SubscriptionQuotaCardViewModel(
        Guid id,
        string name,
        string identityText,
        string remainingText,
        string usedText,
        string totalText,
        string percentageText,
        double remainingRatio,
        string updatedText,
        string expirationText,
        string forecastText,
        string statusText,
        bool canRefresh,
        Visibility refreshVisibility,
        Visibility confirmVisibility,
        Guid? cycleId,
        QuotaTrendChartModel chartModel,
        IReadOnlyList<QuotaEventSummaryViewModel> recentEvents,
        IReadOnlyDictionary<QuotaTrendWindow, QuotaTrendChartModel> trendModels,
        QuotaWindowOption selectedWindow)
    {
        Id = id;
        _name = name;
        _identityText = identityText;
        _remainingText = remainingText;
        _usedText = usedText;
        _totalText = totalText;
        _percentageText = percentageText;
        _remainingRatio = remainingRatio;
        _updatedText = updatedText;
        _expirationText = expirationText;
        _forecastText = forecastText;
        _statusText = statusText;
        _canRefresh = canRefresh;
        _refreshVisibility = refreshVisibility;
        _confirmVisibility = confirmVisibility;
        CycleId = cycleId;
        _chartModel = chartModel;
        _recentEvents = recentEvents;
        _recentEventsVisibility = recentEvents.Count > 0
            ? Visibility.Visible
            : Visibility.Collapsed;
        _trendModels = trendModels;
        _selectedDetailWindow = selectedWindow;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public Guid Id { get; }

    public string Name => _name;

    public string IdentityText => _identityText;

    public string RemainingText => _remainingText;

    public string UsedText => _usedText;

    public string TotalText => _totalText;

    public string PercentageText => _percentageText;

    public double RemainingRatio => _remainingRatio;

    public string UpdatedText => _updatedText;

    public string ExpirationText => _expirationText;

    public string ForecastText => _forecastText;

    public string StatusText => _statusText;

    public bool CanRefresh => _canRefresh;

    public Visibility RefreshVisibility => _refreshVisibility;

    public Visibility ConfirmVisibility => _confirmVisibility;

    public Guid? CycleId { get; private set; }

    public QuotaTrendChartModel ChartModel => _chartModel;

    public IReadOnlyList<QuotaEventSummaryViewModel> RecentEvents => _recentEvents;

    public Visibility RecentEventsVisibility => _recentEventsVisibility;

    public IReadOnlyList<QuotaWindowOption> WindowOptions => QuotaTrendWindowOptions.All;

    public QuotaWindowOption SelectedDetailWindow
    {
        get => _selectedDetailWindow;
        set
        {
            if (value is null || Equals(_selectedDetailWindow, value))
            {
                return;
            }

            _selectedDetailWindow = value;
            PropertyChanged?.Invoke(
                this,
                new PropertyChangedEventArgs(nameof(SelectedDetailWindow)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(DetailChartModel)));
        }
    }

    public QuotaTrendChartModel DetailChartModel =>
        _trendModels[_selectedDetailWindow.Window];

    internal void Apply(SubscriptionQuotaCardViewModel snapshot)
    {
        if (Id != snapshot.Id)
        {
            throw new InvalidOperationException("不能使用其他订阅更新当前配额卡片。");
        }

        Set(ref _name, snapshot.Name, nameof(Name));
        Set(ref _identityText, snapshot.IdentityText, nameof(IdentityText));
        Set(ref _remainingText, snapshot.RemainingText, nameof(RemainingText));
        Set(ref _usedText, snapshot.UsedText, nameof(UsedText));
        Set(ref _totalText, snapshot.TotalText, nameof(TotalText));
        Set(ref _percentageText, snapshot.PercentageText, nameof(PercentageText));
        Set(ref _remainingRatio, snapshot.RemainingRatio, nameof(RemainingRatio));
        Set(ref _updatedText, snapshot.UpdatedText, nameof(UpdatedText));
        Set(ref _expirationText, snapshot.ExpirationText, nameof(ExpirationText));
        Set(ref _forecastText, snapshot.ForecastText, nameof(ForecastText));
        Set(ref _statusText, snapshot.StatusText, nameof(StatusText));
        Set(ref _canRefresh, snapshot.CanRefresh, nameof(CanRefresh));
        Set(ref _refreshVisibility, snapshot.RefreshVisibility, nameof(RefreshVisibility));
        Set(ref _confirmVisibility, snapshot.ConfirmVisibility, nameof(ConfirmVisibility));
        CycleId = snapshot.CycleId;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CycleId)));
        Set(ref _chartModel, snapshot.ChartModel, nameof(ChartModel));
        _recentEvents = snapshot.RecentEvents;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(RecentEvents)));
        Set(
            ref _recentEventsVisibility,
            snapshot.RecentEventsVisibility,
            nameof(RecentEventsVisibility));
        _trendModels = snapshot._trendModels;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(DetailChartModel)));
    }

    private void Set<T>(ref T field, T value, string propertyName)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}

public sealed class ProfileTrackingOptionViewModel : INotifyPropertyChanged
{
    private string _name;
    private string _detail;
    private bool _isTracked;
    private bool _isSupported;
    private int _refreshIntervalMinutes;
    private QuotaRefreshIntervalOption _selectedInterval;

    internal ProfileTrackingOptionViewModel(
        string uid,
        string name,
        string detail,
        bool isTracked,
        bool isSupported,
        int refreshIntervalMinutes)
    {
        Uid = uid;
        _name = name;
        _detail = detail;
        _isTracked = isTracked;
        _isSupported = isSupported;
        _refreshIntervalMinutes = refreshIntervalMinutes;
        _selectedInterval = IntervalOptions.First(option =>
            option.Minutes == refreshIntervalMinutes);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public string Uid { get; }

    public string Name => _name;

    public string Detail => _detail;

    public bool IsTracked => _isTracked;

    public bool IsSupported => _isSupported;

    public int RefreshIntervalMinutes => _refreshIntervalMinutes;

    public IReadOnlyList<QuotaRefreshIntervalOption> IntervalOptions { get; } =
    [
        new(60, "1 小时"),
        new(180, "3 小时"),
        new(360, "6 小时"),
        new(720, "12 小时"),
        new(1_440, "24 小时"),
    ];

    public QuotaRefreshIntervalOption SelectedInterval
    {
        get => _selectedInterval;
        set
        {
            if (value is null || Equals(_selectedInterval, value))
            {
                return;
            }

            _selectedInterval = value;
            _refreshIntervalMinutes = value.Minutes;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SelectedInterval)));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(RefreshIntervalMinutes)));
        }
    }

    internal void Apply(ProfileTrackingOptionViewModel snapshot)
    {
        Set(ref _name, snapshot.Name, nameof(Name));
        Set(ref _detail, snapshot.Detail, nameof(Detail));
        Set(ref _isTracked, snapshot.IsTracked, nameof(IsTracked));
        Set(ref _isSupported, snapshot.IsSupported, nameof(IsSupported));
        Set(
            ref _refreshIntervalMinutes,
            snapshot.RefreshIntervalMinutes,
            nameof(RefreshIntervalMinutes));
        _selectedInterval = IntervalOptions.First(option =>
            option.Minutes == snapshot.RefreshIntervalMinutes);
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SelectedInterval)));
    }

    private void Set<T>(ref T field, T value, string propertyName)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}

public sealed record QuotaRefreshIntervalOption(int Minutes, string Title);

public sealed record QuotaTrendChartModel(
    QuotaTrend Trend,
    string RangeUsageText,
    string EmptyText);
