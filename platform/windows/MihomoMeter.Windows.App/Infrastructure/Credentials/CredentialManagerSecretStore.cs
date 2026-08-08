using System.Security.Cryptography;
using System.Text;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Infrastructure.Credentials;

internal sealed class CredentialManagerSecretStore : IControllerSecretStore
{
    internal const string TargetName = "com.HongXunPan.MihomoMeter.controller";
    private static readonly UTF8Encoding SecretEncoding = new(false, true);
    private readonly CredentialManagerBlobStore _store = new(TargetName);

    public Task<string?> LoadAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var data = _store.Load();
        if (data is null)
        {
            return Task.FromResult<string?>(null);
        }

        try
        {
            return Task.FromResult<string?>(SecretEncoding.GetString(data));
        }
        catch (DecoderFallbackException exception)
        {
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

        var data = SecretEncoding.GetBytes(secret);
        try
        {
            _store.Save(data);
            return Task.CompletedTask;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(data);
        }
    }

    public Task DeleteAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _store.Delete();
        return Task.CompletedTask;
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
