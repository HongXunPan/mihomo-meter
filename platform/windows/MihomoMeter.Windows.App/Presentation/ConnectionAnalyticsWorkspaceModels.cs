using System.ComponentModel;
using System.Runtime.CompilerServices;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed record ConnectionAnalyticsDayOptionViewModel(
    string LocalDay,
    string Title);

public sealed record ConnectionAnalyticsFilterOptionViewModel(
    string? Value,
    string Title);

public enum ConnectionAnalyticsRankingDimension
{
    Application,
    Hostname,
}

public sealed class ConnectionAnalyticsRankingRowViewModel : INotifyPropertyChanged
{
    private string _totalText;
    private string _detailText;
    private string _automationName;

    public ConnectionAnalyticsRankingRowViewModel(
        ConnectionAnalyticsRankingDimension dimension,
        string name,
        TrafficBytes bytes)
    {
        Dimension = dimension;
        Name = name;
        _totalText = string.Empty;
        _detailText = string.Empty;
        _automationName = string.Empty;
        Apply(bytes);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public ConnectionAnalyticsRankingDimension Dimension { get; }

    public string Name { get; }

    public string TotalText => _totalText;

    public string DetailText => _detailText;

    public string AutomationName => _automationName;

    public void Apply(TrafficBytes bytes)
    {
        SetField(
            ref _totalText,
            TrafficDisplayFormatter.ByteCount(bytes.Total),
            nameof(TotalText));
        SetField(
            ref _detailText,
            $"↓ {TrafficDisplayFormatter.ByteCount(bytes.Download)}  "
                + $"↑ {TrafficDisplayFormatter.ByteCount(bytes.Upload)}",
            nameof(DetailText));
        SetField(
            ref _automationName,
            $"{Name}，合计 {_totalText}，{_detailText}",
            nameof(AutomationName));
    }

    private void SetField(ref string field, string value, [CallerMemberName] string? name = null)
    {
        if (string.Equals(field, value, StringComparison.Ordinal))
        {
            return;
        }
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}

public sealed record ConnectionAnalyticsTrendTarget(
    ConnectionAnalyticsRankingDimension Dimension,
    string Name,
    ConnectionAnalyticsTrendQuery Query,
    string? InheritedFilterDescription);
