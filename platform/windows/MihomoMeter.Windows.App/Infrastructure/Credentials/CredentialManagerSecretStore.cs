using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Infrastructure.Credentials;

internal sealed class CredentialManagerSecretStore : IControllerSecretStore
{
    internal const string TargetName = "com.HongXunPan.MihomoMeter.controller";
    private static readonly UTF8Encoding SecretEncoding = new(false, true);
    private readonly CredentialManagerBlobStore _store = new(TargetName);
    private readonly IDiagnosticEventSink _diagnosticEventSink;

    public CredentialManagerSecretStore(IDiagnosticEventSink? diagnosticEventSink = null)
    {
        _diagnosticEventSink = diagnosticEventSink ?? NullDiagnosticEventSink.Instance;
    }

    public Task<string?> LoadAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var startedAt = Start("load");
        byte[]? data;
        try
        {
            data = _store.Load();
        }
        catch (Exception exception)
        {
            Finish("load", "failed", startedAt, exception);
            throw;
        }
        if (data is null)
        {
            Finish("load", "not_found", startedAt);
            return Task.FromResult<string?>(null);
        }

        try
        {
            var secret = SecretEncoding.GetString(data);
            Finish("load", "succeeded", startedAt);
            return Task.FromResult<string?>(secret);
        }
        catch (DecoderFallbackException exception)
        {
            Finish("load", "failed", startedAt, exception);
            throw new CredentialManagerException("解码", innerException: exception);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(data);
        }
    }

    public Task SaveAsync(string secret, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (secret.Length == 0)
        {
            return DeleteAsync(cancellationToken);
        }

        var startedAt = Start("save");
        var data = SecretEncoding.GetBytes(secret);
        try
        {
            _store.Save(data);
            Finish("save", "succeeded", startedAt);
            return Task.CompletedTask;
        }
        catch (Exception exception)
        {
            Finish("save", "failed", startedAt, exception);
            throw;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(data);
        }
    }

    public Task DeleteAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var startedAt = Start("delete");
        try
        {
            _store.Delete();
            Finish("delete", "succeeded", startedAt);
            return Task.CompletedTask;
        }
        catch (Exception exception)
        {
            Finish("delete", "failed", startedAt, exception);
            throw;
        }
    }

    private long Start(string operation)
    {
        _diagnosticEventSink.Record(DiagnosticExportEvent.CredentialOperationStarted(
            DateTimeOffset.UtcNow,
            operation));
        return Stopwatch.GetTimestamp();
    }

    private void Finish(
        string operation,
        string status,
        long startedAt,
        Exception? exception = null)
    {
        var elapsed = Stopwatch.GetElapsedTime(startedAt).TotalMilliseconds;
        var elapsedMilliseconds = (int)Math.Clamp(elapsed, 0, int.MaxValue);
        int? hresult = exception switch
        {
            CredentialManagerException credential => credential.ErrorCode ?? credential.HResult,
            null => null,
            _ => exception.HResult,
        };
        _diagnosticEventSink.Record(DiagnosticExportEvent.CredentialOperationFinished(
            DateTimeOffset.UtcNow,
            operation,
            status,
            elapsedMilliseconds,
            hresult));
    }
}

internal sealed class CredentialManagerException : ControllerConfigurationException
{
    public CredentialManagerException(
        string operation,
        int? errorCode = null,
        string? message = null,
        Exception? innerException = null)
        : base(
            message ?? $"Windows Credential Manager {operation}失败"
                + (errorCode is null ? "。" : $"（{errorCode}）。"),
            innerException)
    {
        ErrorCode = errorCode;
    }

    public int? ErrorCode { get; }
}
