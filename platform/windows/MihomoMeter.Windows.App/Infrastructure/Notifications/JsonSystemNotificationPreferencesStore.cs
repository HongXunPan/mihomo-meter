using System.Text.Json;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Infrastructure.Notifications;

internal sealed record SystemNotificationPreferences(
    bool Enabled,
    bool DisconnectAlertsEnabled,
    IReadOnlySet<string> DeliveredKeys)
{
    public static SystemNotificationPreferences Disabled { get; } = new(
        false,
        false,
        new HashSet<string>(StringComparer.Ordinal));
}

internal interface ISystemNotificationPreferencesStore
{
    Task<SystemNotificationPreferences> LoadAsync(CancellationToken cancellationToken);

    Task SaveAsync(
        SystemNotificationPreferences preferences,
        CancellationToken cancellationToken);
}

internal sealed class JsonSystemNotificationPreferencesStore
    : ISystemNotificationPreferencesStore
{
    private const int CurrentVersion = 1;
    private readonly string _settingsPath;

    public JsonSystemNotificationPreferencesStore(string? settingsPath = null)
    {
        _settingsPath = settingsPath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "notification-settings.json");
    }

    public async Task<SystemNotificationPreferences> LoadAsync(
        CancellationToken cancellationToken)
    {
        if (!File.Exists(_settingsPath))
        {
            return SystemNotificationPreferences.Disabled;
        }

        try
        {
            var data = await File
                .ReadAllBytesAsync(_settingsPath, cancellationToken)
                .ConfigureAwait(false);
            var stored = JsonSerializer.Deserialize<StoredPreferences>(data);
            if (stored is null
                || stored.Version != CurrentVersion
                || stored.DeliveredKeys is null
                || stored.DeliveredKeys.Count > 256
                || stored.DeliveredKeys.Any(key => !IsValidKey(key)))
            {
                throw new SystemNotificationPreferencesStorageException();
            }

            return new SystemNotificationPreferences(
                stored.Enabled,
                stored.DisconnectAlertsEnabled,
                new HashSet<string>(stored.DeliveredKeys, StringComparer.Ordinal));
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (SystemNotificationPreferencesStorageException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException or JsonException)
        {
            throw new SystemNotificationPreferencesStorageException(exception);
        }
    }

    public async Task SaveAsync(
        SystemNotificationPreferences preferences,
        CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(_settingsPath)
            ?? throw new SystemNotificationPreferencesStorageException();
        var pendingPath = Path.Combine(directory, "notification-settings.pending.json");
        var stored = new StoredPreferences(
            CurrentVersion,
            preferences.Enabled,
            preferences.DisconnectAlertsEnabled,
            preferences.DeliveredKeys.Order(StringComparer.Ordinal).ToArray());
        try
        {
            Directory.CreateDirectory(directory);
            var data = JsonSerializer.SerializeToUtf8Bytes(stored);
            await File
                .WriteAllBytesAsync(pendingPath, data, cancellationToken)
                .ConfigureAwait(false);
            File.Move(pendingPath, _settingsPath, true);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            throw new SystemNotificationPreferencesStorageException(exception);
        }
        finally
        {
            TryDeletePendingFile(pendingPath);
        }
    }

    private static bool IsValidKey(string key)
    {
        if (string.Equals(
            key,
            ConnectionSystemNotificationPolicy.DeduplicationKey,
            StringComparison.Ordinal))
        {
            return true;
        }

        var parts = key.Split('|');
        return parts.Length == 4
            && string.Equals(parts[0], "quota", StringComparison.Ordinal)
            && Guid.TryParseExact(parts[1], "D", out _)
            && Guid.TryParseExact(parts[2], "D", out _)
            && parts[3] is "lowRemaining" or "expiringSoon" or "depletingSoon";
    }

    private static void TryDeletePendingFile(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }

    private sealed record StoredPreferences(
        int Version,
        bool Enabled,
        bool DisconnectAlertsEnabled,
        IReadOnlyList<string> DeliveredKeys);
}

internal sealed class SystemNotificationPreferencesStorageException : Exception
{
    public SystemNotificationPreferencesStorageException(Exception? innerException = null)
        : base("读取或保存系统通知设置失败。", innerException)
    {
    }
}
