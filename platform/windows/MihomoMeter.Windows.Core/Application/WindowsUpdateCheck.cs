using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public enum WindowsUpdateAvailability
{
    UpToDate,
    UpdateAvailable,
    Failed,
}

public enum WindowsReleaseQueryFailureCategory
{
    Unavailable,
    RateLimited,
    Network,
    InvalidDescriptor,
}

public sealed record WindowsReleaseSnapshot(
    ReleaseVersion Version,
    Uri ReleasePageUri);

public sealed record WindowsUpdateCheckResult(
    WindowsUpdateAvailability Availability,
    ReleaseVersion CurrentVersion,
    ReleaseVersion? LatestVersion,
    Uri? ReleasePageUri,
    WindowsReleaseQueryFailureCategory? FailureCategory)
{
    public static WindowsUpdateCheckResult UpToDate(
        ReleaseVersion currentVersion,
        ReleaseVersion latestVersion)
    {
        return new WindowsUpdateCheckResult(
            WindowsUpdateAvailability.UpToDate,
            currentVersion,
            latestVersion,
            null,
            null);
    }

    public static WindowsUpdateCheckResult UpdateAvailable(
        ReleaseVersion currentVersion,
        WindowsReleaseSnapshot latest)
    {
        return new WindowsUpdateCheckResult(
            WindowsUpdateAvailability.UpdateAvailable,
            currentVersion,
            latest.Version,
            latest.ReleasePageUri,
            null);
    }

    public static WindowsUpdateCheckResult Failed(
        ReleaseVersion currentVersion,
        WindowsReleaseQueryFailureCategory category)
    {
        return new WindowsUpdateCheckResult(
            WindowsUpdateAvailability.Failed,
            currentVersion,
            null,
            null,
            category);
    }
}

public interface IWindowsReleaseQuery
{
    Task<WindowsReleaseSnapshot> GetLatestAsync(CancellationToken cancellationToken);
}

public sealed class WindowsReleaseQueryException : Exception
{
    public WindowsReleaseQueryException(
        WindowsReleaseQueryFailureCategory category,
        string message,
        Exception? innerException = null)
        : base(message, innerException)
    {
        Category = category;
    }

    public WindowsReleaseQueryFailureCategory Category { get; }
}

public sealed class WindowsUpdateChecker
{
    private readonly object _sync = new();
    private readonly IWindowsReleaseQuery _releaseQuery;
    private Task<WindowsUpdateCheckResult>? _activeCheck;

    public WindowsUpdateChecker(IWindowsReleaseQuery releaseQuery)
    {
        _releaseQuery = releaseQuery;
    }

    public Task<WindowsUpdateCheckResult> CheckAsync(
        ReleaseVersion currentVersion,
        CancellationToken cancellationToken = default)
    {
        lock (_sync)
        {
            if (_activeCheck is { IsCompleted: false })
            {
                return _activeCheck;
            }

            _activeCheck = CheckCoreAsync(currentVersion, cancellationToken);
            return _activeCheck;
        }
    }

    private async Task<WindowsUpdateCheckResult> CheckCoreAsync(
        ReleaseVersion currentVersion,
        CancellationToken cancellationToken)
    {
        try
        {
            var latest = await _releaseQuery
                .GetLatestAsync(cancellationToken)
                .ConfigureAwait(false);
            return latest.Version.CompareTo(currentVersion) > 0
                ? WindowsUpdateCheckResult.UpdateAvailable(currentVersion, latest)
                : WindowsUpdateCheckResult.UpToDate(currentVersion, latest.Version);
        }
        catch (WindowsReleaseQueryException exception)
        {
            return WindowsUpdateCheckResult.Failed(currentVersion, exception.Category);
        }
    }
}
