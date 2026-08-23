using System.Text.Json;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Infrastructure.Recovery;

internal sealed class JsonCrashRecoveryRestartStateStore
{
    private const int CurrentVersion = 1;
    private const int MaximumFileSize = 4096;
    private readonly string _statePath;

    public JsonCrashRecoveryRestartStateStore(string? statePath = null)
    {
        _statePath = statePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HongXunPan",
            "MihomoMeter",
            "recovery-restart.json");
    }

    public CrashRecoveryRestartState Load()
    {
        if (!File.Exists(_statePath))
        {
            return CrashRecoveryRestartState.Empty;
        }

        try
        {
            var data = File.ReadAllBytes(_statePath);
            if (data.Length > MaximumFileSize)
            {
                throw new CrashRecoveryRestartStateStorageException();
            }

            var stored = JsonSerializer.Deserialize<StoredState>(data);
            if (stored is null
                || stored.Version != CurrentVersion
                || !HasValidPendingRegistration(stored))
            {
                throw new CrashRecoveryRestartStateStorageException();
            }

            return new CrashRecoveryRestartState(
                stored.PendingToken,
                stored.PendingRegisteredAtUtc,
                stored.LastRecoveryStartedAtUtc);
        }
        catch (CrashRecoveryRestartStateStorageException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException or JsonException)
        {
            throw new CrashRecoveryRestartStateStorageException(exception);
        }
    }

    public void Save(CrashRecoveryRestartState state)
    {
        ArgumentNullException.ThrowIfNull(state);
        var directory = Path.GetDirectoryName(_statePath)
            ?? throw new CrashRecoveryRestartStateStorageException();
        var pendingPath = Path.Combine(directory, "recovery-restart.pending.json");
        var stored = new StoredState(
            CurrentVersion,
            state.PendingToken,
            state.PendingRegisteredAtUtc,
            state.LastRecoveryStartedAtUtc);

        try
        {
            Directory.CreateDirectory(directory);
            var data = JsonSerializer.SerializeToUtf8Bytes(stored);
            File.WriteAllBytes(pendingPath, data);
            File.Move(pendingPath, _statePath, true);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            throw new CrashRecoveryRestartStateStorageException(exception);
        }
        finally
        {
            TryDeletePendingFile(pendingPath);
        }
    }

    private static bool HasValidPendingRegistration(StoredState stored)
    {
        if (stored.PendingToken is null && stored.PendingRegisteredAtUtc is null)
        {
            return true;
        }

        return stored.PendingToken is not null
            && stored.PendingRegisteredAtUtc is not null
            && Guid.TryParseExact(stored.PendingToken, "N", out _);
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

    private sealed record StoredState(
        int Version,
        string? PendingToken,
        DateTimeOffset? PendingRegisteredAtUtc,
        DateTimeOffset? LastRecoveryStartedAtUtc);
}

internal sealed class CrashRecoveryRestartStateStorageException : Exception
{
    public CrashRecoveryRestartStateStorageException(Exception? innerException = null)
        : base("读取或保存恢复重启状态失败。", innerException)
    {
    }
}
