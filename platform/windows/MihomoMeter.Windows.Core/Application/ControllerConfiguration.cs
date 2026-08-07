using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

public sealed class ControllerConfiguration
{
    public ControllerConfiguration(string address, string secret)
    {
        Address = address;
        Secret = secret;
    }

    public static ControllerConfiguration Empty => new(string.Empty, string.Empty);

    public string Address { get; }

    public string Secret { get; }
}

public interface IControllerConfigurationStore
{
    Task<ControllerConfiguration> LoadAsync(CancellationToken cancellationToken);

    Task SaveValidatedAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);
}

public interface IControllerAddressStore
{
    Task<string?> LoadAsync(CancellationToken cancellationToken);

    Task SaveAsync(string normalizedAddress, CancellationToken cancellationToken);
}

public interface IControllerSecretStore
{
    Task<string?> LoadAsync(CancellationToken cancellationToken);

    Task SaveAsync(string secret, CancellationToken cancellationToken);

    Task DeleteAsync(CancellationToken cancellationToken);
}

public sealed class ValidatedControllerConfigurationStore : IControllerConfigurationStore
{
    private readonly IControllerAddressStore _addressStore;
    private readonly IControllerSecretStore _secretStore;

    public ValidatedControllerConfigurationStore(
        IControllerAddressStore addressStore,
        IControllerSecretStore secretStore)
    {
        _addressStore = addressStore;
        _secretStore = secretStore;
    }

    public async Task<ControllerConfiguration> LoadAsync(CancellationToken cancellationToken)
    {
        var address = await _addressStore.LoadAsync(cancellationToken).ConfigureAwait(false);
        var secret = await _secretStore.LoadAsync(cancellationToken).ConfigureAwait(false);
        return new ControllerConfiguration(address ?? string.Empty, secret ?? string.Empty);
    }

    public async Task SaveValidatedAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken)
    {
        var previousSecret = await _secretStore
            .LoadAsync(cancellationToken)
            .ConfigureAwait(false);

        await SaveSecretAsync(secret, cancellationToken).ConfigureAwait(false);
        try
        {
            await _addressStore
                .SaveAsync(endpoint.NormalizedAddress, cancellationToken)
                .ConfigureAwait(false);
        }
        catch (Exception saveException)
        {
            try
            {
                await RestoreSecretAsync(previousSecret, CancellationToken.None).ConfigureAwait(false);
            }
            catch (Exception rollbackException)
            {
                throw new ControllerConfigurationSaveException(
                    saveException,
                    rollbackException);
            }

            if (saveException is OperationCanceledException)
            {
                throw;
            }

            throw new ControllerConfigurationSaveException(saveException);
        }
    }

    private Task SaveSecretAsync(string secret, CancellationToken cancellationToken)
    {
        return secret.Length == 0
            ? _secretStore.DeleteAsync(cancellationToken)
            : _secretStore.SaveAsync(secret, cancellationToken);
    }

    private Task RestoreSecretAsync(string? secret, CancellationToken cancellationToken)
    {
        return string.IsNullOrEmpty(secret)
            ? _secretStore.DeleteAsync(cancellationToken)
            : _secretStore.SaveAsync(secret, cancellationToken);
    }
}

public class ControllerConfigurationException : Exception
{
    protected ControllerConfigurationException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}

public sealed class ControllerConfigurationSaveException : ControllerConfigurationException
{
    public ControllerConfigurationSaveException(Exception saveException)
        : base("保存 Controller 配置失败，上一份凭据已恢复。", saveException)
    {
    }

    public ControllerConfigurationSaveException(
        Exception saveException,
        Exception rollbackException)
        : base("保存 Controller 配置失败，并且未能恢复上一份凭据。", saveException)
    {
        RollbackException = rollbackException;
    }

    public Exception? RollbackException { get; }
}
