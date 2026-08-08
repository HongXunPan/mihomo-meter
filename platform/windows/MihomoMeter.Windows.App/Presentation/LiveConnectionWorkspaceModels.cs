using System.ComponentModel;
using System.Runtime.CompilerServices;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Presentation;

public sealed record LiveConnectionRouteOption(
    LiveConnectionRoute Route,
    string Title);

public sealed record LiveConnectionModeOption(
    LiveConnectionViewMode Mode,
    string Title);

public sealed class LiveConnectionRowViewModel : INotifyPropertyChanged
{
    private string _hostname;
    private string _applicationName;
    private string _rateText;
    private string _cumulativeText;
    private string _durationText;
    private string _automationName;

    internal LiveConnectionRowViewModel(
        string id,
        string hostname,
        string applicationName,
        string rateText,
        string cumulativeText,
        string durationText,
        string automationName)
    {
        Id = id;
        _hostname = hostname;
        _applicationName = applicationName;
        _rateText = rateText;
        _cumulativeText = cumulativeText;
        _durationText = durationText;
        _automationName = automationName;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    internal string Id { get; }

    public string Hostname => _hostname;

    public string ApplicationName => _applicationName;

    public string RateText => _rateText;

    public string CumulativeText => _cumulativeText;

    public string DurationText => _durationText;

    public string AutomationName => _automationName;

    internal void Apply(LiveConnectionRowViewModel snapshot)
    {
        if (!string.Equals(Id, snapshot.Id, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("不能使用其他连接的展示快照更新当前行。");
        }

        SetField(ref _hostname, snapshot.Hostname, nameof(Hostname));
        SetField(ref _applicationName, snapshot.ApplicationName, nameof(ApplicationName));
        SetField(ref _rateText, snapshot.RateText, nameof(RateText));
        SetField(ref _cumulativeText, snapshot.CumulativeText, nameof(CumulativeText));
        SetField(ref _durationText, snapshot.DurationText, nameof(DurationText));
        SetField(ref _automationName, snapshot.AutomationName, nameof(AutomationName));
    }

    private void SetField<T>(ref T field, T value, string propertyName)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}

public sealed class LiveConnectionGroupRowViewModel : INotifyPropertyChanged
{
    private string _name;
    private string _relationText;
    private string _rateText;
    private string _cumulativeText;
    private string _automationName;

    internal LiveConnectionGroupRowViewModel(
        string id,
        string name,
        string relationText,
        string rateText,
        string cumulativeText,
        string automationName)
    {
        Id = id;
        _name = name;
        _relationText = relationText;
        _rateText = rateText;
        _cumulativeText = cumulativeText;
        _automationName = automationName;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    internal string Id { get; }

    public string Name => _name;

    public string RelationText => _relationText;

    public string RateText => _rateText;

    public string CumulativeText => _cumulativeText;

    public string AutomationName => _automationName;

    internal void Apply(LiveConnectionGroupRowViewModel snapshot)
    {
        if (!string.Equals(Id, snapshot.Id, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("不能使用其他分组的展示快照更新当前行。");
        }

        SetField(ref _name, snapshot.Name, nameof(Name));
        SetField(ref _relationText, snapshot.RelationText, nameof(RelationText));
        SetField(ref _rateText, snapshot.RateText, nameof(RateText));
        SetField(ref _cumulativeText, snapshot.CumulativeText, nameof(CumulativeText));
        SetField(ref _automationName, snapshot.AutomationName, nameof(AutomationName));
    }

    private void SetField<T>(ref T field, T value, string propertyName)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
