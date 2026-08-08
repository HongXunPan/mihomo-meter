using System.Security.Cryptography;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Infrastructure.Credentials;

internal sealed class CredentialManagerProfileFingerprintKeyStore : IProfileFingerprintKeyStore
{
    internal const string TargetName = "com.HongXunPan.MihomoMeter.profile-fingerprint-key";
    private const int KeySize = 32;
    private readonly CredentialManagerBlobStore _store = new(TargetName);

    public Task<byte[]> LoadOrCreateAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var existing = _store.Load();
        if (existing is not null)
        {
            if (existing.Length != KeySize)
            {
                CryptographicOperations.ZeroMemory(existing);
                throw new CredentialManagerException("读取", message: "Profile 指纹密钥长度无效。");
            }

            return Task.FromResult(existing);
        }

        var key = RandomNumberGenerator.GetBytes(KeySize);
        try
        {
            _store.Save(key);
            return Task.FromResult(key.ToArray());
        }
        finally
        {
            CryptographicOperations.ZeroMemory(key);
        }
    }
}
