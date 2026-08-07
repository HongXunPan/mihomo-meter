using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ControllerConfigurationStoreTests
{
    [TestMethod]
    public void ConfigurationDescriptionDoesNotExposeSecret()
    {
        var configuration = new ControllerConfiguration(
            "http://127.0.0.1:9090",
            "synthetic-secret");

        var description = configuration.ToString() ?? string.Empty;
        Assert.IsFalse(description.Contains(
            "synthetic-secret",
            StringComparison.Ordinal));
    }

    [TestMethod]
    public async Task SavesSecretAndNormalizedAddressAfterValidation()
    {
        var addressStore = new TestAddressStore();
        var secretStore = new TestSecretStore();
        var store = new ValidatedControllerConfigurationStore(addressStore, secretStore);

        await store.SaveValidatedAsync(
            new ControllerEndpoint("127.0.0.1:9090"),
            "synthetic-secret",
            CancellationToken.None);

        Assert.AreEqual("http://127.0.0.1:9090", addressStore.Address);
        Assert.AreEqual("synthetic-secret", secretStore.Secret);
    }

    [TestMethod]
    public async Task EmptySecretDeletesPreviousCredential()
    {
        var secretStore = new TestSecretStore { Secret = "previous" };
        var store = new ValidatedControllerConfigurationStore(
            new TestAddressStore(),
            secretStore);

        await store.SaveValidatedAsync(
            new ControllerEndpoint("127.0.0.1:9090"),
            string.Empty,
            CancellationToken.None);

        Assert.IsNull(secretStore.Secret);
    }

    [TestMethod]
    public async Task RestoresPreviousSecretWhenAddressSaveFails()
    {
        var addressStore = new TestAddressStore { ShouldFailSave = true };
        var secretStore = new TestSecretStore { Secret = "previous" };
        var store = new ValidatedControllerConfigurationStore(addressStore, secretStore);

        await Assert.ThrowsExactlyAsync<ControllerConfigurationSaveException>(() =>
            store.SaveValidatedAsync(
                new ControllerEndpoint("127.0.0.1:9090"),
                "replacement",
                CancellationToken.None));

        Assert.AreEqual("previous", secretStore.Secret);
    }

    [TestMethod]
    public async Task RestoresPreviousSecretWhenAddressSaveIsCancelled()
    {
        var addressStore = new TestAddressStore { ShouldCancelSave = true };
        var secretStore = new TestSecretStore { Secret = "previous" };
        var store = new ValidatedControllerConfigurationStore(addressStore, secretStore);

        try
        {
            await store.SaveValidatedAsync(
                new ControllerEndpoint("127.0.0.1:9090"),
                "replacement",
                CancellationToken.None);
            Assert.Fail("地址保存取消应向调用方保留取消语义。");
        }
        catch (OperationCanceledException)
        {
        }

        Assert.AreEqual("previous", secretStore.Secret);
    }

    private sealed class TestAddressStore : IControllerAddressStore
    {
        public string? Address { get; private set; }

        public bool ShouldFailSave { get; init; }

        public bool ShouldCancelSave { get; init; }

        public Task<string?> LoadAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(Address);
        }

        public Task SaveAsync(string normalizedAddress, CancellationToken cancellationToken)
        {
            if (ShouldCancelSave)
            {
                return Task.FromCanceled(new CancellationToken(true));
            }

            if (ShouldFailSave)
            {
                throw new InvalidOperationException("合成地址保存失败");
            }

            Address = normalizedAddress;
            return Task.CompletedTask;
        }
    }

    private sealed class TestSecretStore : IControllerSecretStore
    {
        public string? Secret { get; set; }

        public Task<string?> LoadAsync(CancellationToken cancellationToken)
        {
            return Task.FromResult(Secret);
        }

        public Task SaveAsync(string secret, CancellationToken cancellationToken)
        {
            Secret = secret;
            return Task.CompletedTask;
        }

        public Task DeleteAsync(CancellationToken cancellationToken)
        {
            Secret = null;
            return Task.CompletedTask;
        }
    }
}
