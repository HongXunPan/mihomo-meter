using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Core.Infrastructure.Profile;

public sealed class ProfileDirectoryObserver : IProfileDirectoryObserver
{
    private static readonly TimeSpan DebounceDelay = TimeSpan.FromMilliseconds(400);
    private readonly object _lock = new();
    private FileSystemWatcher? _watcher;
    private CancellationTokenSource? _debounceSource;

    public event Action? Changed;

    public event Action? ObservationFailed;

    public void Start(string directoryPath)
    {
        Stop();
        var watcher = new FileSystemWatcher(directoryPath, "profiles.yaml")
        {
            IncludeSubdirectories = false,
            NotifyFilter = NotifyFilters.FileName
                | NotifyFilters.LastWrite
                | NotifyFilters.Size
                | NotifyFilters.CreationTime,
            EnableRaisingEvents = true,
        };
        watcher.Changed += OnChanged;
        watcher.Created += OnChanged;
        watcher.Deleted += OnChanged;
        watcher.Renamed += OnRenamed;
        watcher.Error += OnError;
        _watcher = watcher;
    }

    public void Stop()
    {
        lock (_lock)
        {
            _debounceSource?.Cancel();
            _debounceSource?.Dispose();
            _debounceSource = null;
        }

        if (_watcher is not null)
        {
            _watcher.EnableRaisingEvents = false;
            _watcher.Changed -= OnChanged;
            _watcher.Created -= OnChanged;
            _watcher.Deleted -= OnChanged;
            _watcher.Renamed -= OnRenamed;
            _watcher.Error -= OnError;
            _watcher.Dispose();
            _watcher = null;
        }
    }

    public void Dispose()
    {
        Stop();
    }

    private void OnChanged(object sender, FileSystemEventArgs args)
    {
        ScheduleChanged();
    }

    private void OnRenamed(object sender, RenamedEventArgs args)
    {
        ScheduleChanged();
    }

    private void OnError(object sender, ErrorEventArgs args)
    {
        ObservationFailed?.Invoke();
    }

    private void ScheduleChanged()
    {
        CancellationTokenSource source;
        lock (_lock)
        {
            _debounceSource?.Cancel();
            _debounceSource?.Dispose();
            source = new CancellationTokenSource();
            _debounceSource = source;
        }

        _ = NotifyAfterDelayAsync(source);
    }

    private async Task NotifyAfterDelayAsync(CancellationTokenSource source)
    {
        try
        {
            await Task.Delay(DebounceDelay, source.Token).ConfigureAwait(false);
            Changed?.Invoke();
        }
        catch (OperationCanceledException)
        {
        }
    }
}
