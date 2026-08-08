using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public interface IProfileDirectoryStore
{
    Task<string?> LoadAsync(CancellationToken cancellationToken);

    Task SaveAsync(string directoryPath, CancellationToken cancellationToken);

    Task ClearAsync(CancellationToken cancellationToken);
}

public interface IProfileCatalogReader
{
    ClashProfileCatalog Read(string directoryPath);
}

public interface IProfileFingerprintKeyStore
{
    Task<byte[]> LoadOrCreateAsync(CancellationToken cancellationToken);
}

public interface IProfileUrlFingerprinter
{
    Task<string> FingerprintAsync(Uri uri, CancellationToken cancellationToken);
}

public interface IProfileDirectoryObserver : IDisposable
{
    event Action? Changed;

    event Action? ObservationFailed;

    void Start(string directoryPath);

    void Stop();
}

public sealed class ProfileDirectoryException : Exception
{
    public ProfileDirectoryException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
