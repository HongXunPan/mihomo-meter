using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Infrastructure.Profile;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ProfileQuotaIdentityTests
{
    private string _testDirectory = string.Empty;

    [TestInitialize]
    public void SetUp()
    {
        _testDirectory = Path.Combine(
            AppContext.BaseDirectory,
            "ProfileQuotaData",
            Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testDirectory);
    }

    [TestCleanup]
    public void TearDown()
    {
        if (Directory.Exists(_testDirectory))
        {
            Directory.Delete(_testDirectory, true);
        }
    }

    [TestMethod]
    public void ReadsRemoteProfilesAndIgnoresUnknownFields()
    {
        WriteProfiles(
            """
            current: remote-a
            items:
              - uid: remote-a
                type: remote
                name: 主订阅
                url: https://EXAMPLE.com/sub?token=secret
                extra:
                  upload: 100
              - uid: local-a
                type: local
                name: 本地配置
              - uid: incomplete
                type: remote
                name: 不完整订阅
              - uid: unsupported-scheme
                type: remote
                name: 非网络地址
                url: file:///C:/subscription.yaml
            """);

        var catalog = new YamlClashProfileCatalogReader().Read(_testDirectory);

        Assert.AreEqual("remote-a", catalog.CurrentUid);
        Assert.AreEqual(1, catalog.Profiles.Count);
        Assert.AreEqual("主订阅", catalog.CurrentProfile?.Name);
        Assert.AreEqual("example.com", catalog.CurrentProfile?.SubscriptionUri.Host);
        Assert.AreEqual(2, catalog.IgnoredRemoteProfileCount);
    }

    [TestMethod]
    public void KeepsHttpVisibleButMarksItUnsupported()
    {
        WriteProfiles(
            """
            items:
              - uid: legacy
                type: remote
                name: 旧订阅
                url: http://legacy.example/sub
            """);

        var profile = new YamlClashProfileCatalogReader()
            .Read(_testDirectory)
            .Profiles
            .Single();

        Assert.IsFalse(profile.SupportsActiveQuery);
    }

    [TestMethod]
    public void RejectsDuplicateUidAndMalformedYaml()
    {
        WriteProfiles(
            """
            items:
              - uid: duplicate
                type: remote
                name: 一
                url: https://one.example/sub
              - uid: duplicate
                type: remote
                name: 二
                url: https://two.example/sub
            """);

        Assert.ThrowsException<ProfileDirectoryException>(() =>
            new YamlClashProfileCatalogReader().Read(_testDirectory));

        WriteProfiles("items: [not-closed");
        Assert.ThrowsException<ProfileDirectoryException>(() =>
            new YamlClashProfileCatalogReader().Read(_testDirectory));
    }

    [TestMethod]
    public void PathPolicyRejectsReparsePointAndOversizedFile()
    {
        Assert.IsTrue(ProfilePathPolicy.IsReparsePoint(FileAttributes.ReparsePoint));
        Assert.IsFalse(ProfilePathPolicy.IsReparsePoint(FileAttributes.Normal));
        Assert.IsTrue(ProfilePathPolicy.ExceedsMaximumSize(
            YamlClashProfileCatalogReader.MaximumFileSize + 1,
            YamlClashProfileCatalogReader.MaximumFileSize));
        Assert.IsFalse(ProfilePathPolicy.ExceedsMaximumSize(
            YamlClashProfileCatalogReader.MaximumFileSize,
            YamlClashProfileCatalogReader.MaximumFileSize));
    }

    [TestMethod]
    public async Task HmacFingerprintIsStableNormalizedAndDoesNotExposeUrl()
    {
        var fingerprinter = new HmacProfileUrlFingerprinter(
            new FixedKeyStore(Enumerable.Range(1, 32).Select(value => (byte)value).ToArray()));

        var first = await fingerprinter.FingerprintAsync(
            new Uri("https://EXAMPLE.com:443/sub?token=top-secret#fragment"),
            CancellationToken.None);
        var second = await fingerprinter.FingerprintAsync(
            new Uri("https://example.com/sub?token=top-secret"),
            CancellationToken.None);

        Assert.AreEqual(first, second);
        Assert.AreEqual(64, first.Length);
        Assert.IsFalse(first.Contains("top-secret", StringComparison.Ordinal));
        Assert.IsTrue(first.All(character => char.IsAsciiHexDigitLower(character)));
    }

    [TestMethod]
    public async Task HmacFingerprintDependsOnApplicationLocalKey()
    {
        var uri = new Uri("https://example.com/sub?token=secret");
        var first = await new HmacProfileUrlFingerprinter(
                new FixedKeyStore(Enumerable.Repeat((byte)1, 32).ToArray()))
            .FingerprintAsync(uri, CancellationToken.None);
        var second = await new HmacProfileUrlFingerprinter(
                new FixedKeyStore(Enumerable.Repeat((byte)2, 32).ToArray()))
            .FingerprintAsync(uri, CancellationToken.None);

        Assert.AreNotEqual(first, second);
    }

    private void WriteProfiles(string contents)
    {
        File.WriteAllText(Path.Combine(_testDirectory, "profiles.yaml"), contents);
    }

    private sealed class FixedKeyStore : IProfileFingerprintKeyStore
    {
        private readonly byte[] _key;

        public FixedKeyStore(byte[] key)
        {
            _key = key;
        }

        public Task<byte[]> LoadOrCreateAsync(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            return Task.FromResult(_key.ToArray());
        }
    }
}
