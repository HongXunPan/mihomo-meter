using System.Text.Json;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Infrastructure.Configuration;

internal sealed class JsonProfileDirectoryStore : IProfileDirectoryStore
{
    private const int CurrentVersion = 1;
    private readonly string _settingsPath;

    public JsonProfileDirectoryStore(string? settingsPath = null)
    {
        _settingsPath = settingsPath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "profile-directory.json");
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
            var settings = JsonSerializer.Deserialize<ProfileDirectorySettings>(data);
            if (settings is null
                || settings.Version != CurrentVersion
                || string.IsNullOrWhiteSpace(settings.DirectoryPath))
            {
                throw new ProfileDirectoryException("Profile 目录设置无效。");
            }

            return Path.GetFullPath(settings.DirectoryPath);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (ProfileDirectoryException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or JsonException
                or ArgumentException
                or NotSupportedException)
        {
            throw new ProfileDirectoryException("读取 Profile 目录设置失败。", exception);
        }
    }

    public async Task SaveAsync(string directoryPath, CancellationToken cancellationToken)
    {
        var fullPath = Path.GetFullPath(directoryPath);
        var directory = Path.GetDirectoryName(_settingsPath)
            ?? throw new ProfileDirectoryException("无法确定 Profile 设置目录。");
        var pendingPath = Path.Combine(directory, "profile-directory.pending.json");
        try
        {
            Directory.CreateDirectory(directory);
            var data = JsonSerializer.SerializeToUtf8Bytes(
                new ProfileDirectorySettings(CurrentVersion, fullPath));
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
            throw new ProfileDirectoryException("保存 Profile 目录设置失败。", exception);
        }
        finally
        {
            TryDelete(pendingPath);
        }
    }

    public Task ClearAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        try
        {
            File.Delete(_settingsPath);
            return Task.CompletedTask;
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            throw new ProfileDirectoryException("清除 Profile 目录设置失败。", exception);
        }
    }

    private static void TryDelete(string path)
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

    private sealed record ProfileDirectorySettings(int Version, string DirectoryPath);
}
