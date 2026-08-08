using System.Security.Cryptography;
using System.Text;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Core.Infrastructure.Profile;

public sealed class HmacProfileUrlFingerprinter : IProfileUrlFingerprinter
{
    private readonly IProfileFingerprintKeyStore _keyStore;

    public HmacProfileUrlFingerprinter(IProfileFingerprintKeyStore keyStore)
    {
        _keyStore = keyStore;
    }

    public async Task<string> FingerprintAsync(
        Uri uri,
        CancellationToken cancellationToken)
    {
        var normalized = Normalize(uri);
        var key = await _keyStore
            .LoadOrCreateAsync(cancellationToken)
            .ConfigureAwait(false);
        var data = Encoding.UTF8.GetBytes(normalized);
        try
        {
            var digest = HMACSHA256.HashData(key, data);
            return Convert.ToHexString(digest).ToLowerInvariant();
        }
        finally
        {
            CryptographicOperations.ZeroMemory(key);
            CryptographicOperations.ZeroMemory(data);
        }
    }

    internal static string Normalize(Uri uri)
    {
        if (!uri.IsAbsoluteUri)
        {
            throw new ProfileDirectoryException("订阅地址无效。");
        }

        var builder = new UriBuilder(uri)
        {
            Scheme = uri.Scheme.ToLowerInvariant(),
            Host = uri.IdnHost.ToLowerInvariant(),
            Fragment = string.Empty,
        };
        if (uri.IsDefaultPort)
        {
            builder.Port = -1;
        }

        return builder.Uri.AbsoluteUri;
    }
}
