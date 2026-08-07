using System.Text.Json;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Infrastructure.Configuration;

internal sealed class JsonControllerAddressStore : IControllerAddressStore
{
    private const int CurrentVersion = 1;
    private readonly string _settingsPath;

    public JsonControllerAddressStore(string? settingsPath = null)
    {
        _settingsPath = settingsPath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "settings.json");
    }

    public async Task<string?> LoadAsync(CancellationToken cancellationToken)
    {
        if (!File.Exists(_settingsPath))
        {
            return null;
        }

        try
        {
            var data = await File
                .ReadAllBytesAsync(_settingsPath, cancellationToken)
                .ConfigureAwait(false);
            var settings = JsonSerializer.Deserialize<ControllerSettings>(data);
            if (settings is null
                || settings.Version != CurrentVersion
                || string.IsNullOrWhiteSpace(settings.ControllerAddress))
            {
                throw new ConfigurationStorageException();
            }

            return settings.ControllerAddress;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (ConfigurationStorageException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException or JsonException)
        {
            throw new ConfigurationStorageException(exception);
        }
    }

    public async Task SaveAsync(
        string normalizedAddress,
        CancellationToken cancellationToken)
    {
        var directory = Path.GetDirectoryName(_settingsPath)
            ?? throw new ConfigurationStorageException();
        var pendingPath = Path.Combine(directory, "settings.pending.json");
        var settings = new ControllerSettings(CurrentVersion, normalizedAddress);

        try
        {
            Directory.CreateDirectory(directory);
            var data = JsonSerializer.SerializeToUtf8Bytes(settings);
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
            throw new ConfigurationStorageException(exception);
        }
        finally
        {
            TryDeletePendingFile(pendingPath);
        }
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

    private sealed record ControllerSettings(int Version, string ControllerAddress);
}

internal sealed class ConfigurationStorageException : ControllerConfigurationException
{
    public ConfigurationStorageException(Exception? innerException = null)
        : base("读取或保存 Controller 地址失败。", innerException)
    {
    }
}
