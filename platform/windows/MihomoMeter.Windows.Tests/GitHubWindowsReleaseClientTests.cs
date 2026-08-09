using System.Net;
using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;
using MihomoMeter.Windows.Core.Infrastructure.Update;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class GitHubWindowsReleaseClientTests
{
    [TestMethod]
    public async Task ReadsStrictWindowsDescriptor()
    {
        using var httpClient = new HttpClient(new StubHandler(
            HttpStatusCode.OK,
            Descriptor("1.2.4")));
        var client = new GitHubWindowsReleaseClient(httpClient);

        var snapshot = await client.GetLatestAsync(CancellationToken.None);

        Assert.AreEqual(new ReleaseVersion(1, 2, 4), snapshot.Version);
        Assert.AreEqual(
            "https://github.com/HongXunPan/mihomo-meter/releases/tag/v1.2.4",
            snapshot.ReleasePageUri.AbsoluteUri);
    }

    [TestMethod]
    public async Task RejectsForeignReleasePageAndInvalidAssetHash()
    {
        var foreign = Descriptor("1.2.4").Replace(
            "https://github.com/HongXunPan/mihomo-meter/releases/tag/v1.2.4",
            "https://example.com/releases/tag/v1.2.4",
            StringComparison.Ordinal);
        var invalidHash = Descriptor("1.2.4").Replace(
            new string('a', 64),
            "ABC",
            StringComparison.Ordinal);

        await AssertInvalidAsync(foreign);
        await AssertInvalidAsync(invalidHash);
    }

    [TestMethod]
    public async Task RejectsMissingAndDuplicateDescriptorFields()
    {
        var missing = Descriptor("1.2.4").Replace(
            "  \"platform\": \"windows\",",
            string.Empty,
            StringComparison.Ordinal);
        var duplicate = Descriptor("1.2.4").Replace(
            "  \"platform\": \"windows\",",
            "  \"platform\": \"windows\",\n  \"platform\": \"windows\",",
            StringComparison.Ordinal);

        await AssertInvalidAsync(missing);
        await AssertInvalidAsync(duplicate);
    }

    [TestMethod]
    public async Task ClassifiesRateLimitAndMissingDescriptor()
    {
        await AssertFailureCategoryAsync(
            HttpStatusCode.Forbidden,
            WindowsReleaseQueryFailureCategory.RateLimited);
        await AssertFailureCategoryAsync(
            HttpStatusCode.NotFound,
            WindowsReleaseQueryFailureCategory.Unavailable);
    }

    [TestMethod]
    public async Task RejectsRedirectToForeignHost()
    {
        using var httpClient = new HttpClient(new StubHandler(
            HttpStatusCode.OK,
            Descriptor("1.2.4"),
            new Uri("https://example.com/windows-release.json")));
        var client = new GitHubWindowsReleaseClient(httpClient);

        var exception = await Assert.ThrowsExactlyAsync<WindowsReleaseQueryException>(
            () => client.GetLatestAsync(CancellationToken.None));

        Assert.AreEqual(
            WindowsReleaseQueryFailureCategory.InvalidDescriptor,
            exception.Category);
    }

    private static async Task AssertInvalidAsync(string content)
    {
        using var httpClient = new HttpClient(new StubHandler(HttpStatusCode.OK, content));
        var client = new GitHubWindowsReleaseClient(httpClient);

        var exception = await Assert.ThrowsExactlyAsync<WindowsReleaseQueryException>(
            () => client.GetLatestAsync(CancellationToken.None));
        Assert.AreEqual(
            WindowsReleaseQueryFailureCategory.InvalidDescriptor,
            exception.Category);
    }

    private static async Task AssertFailureCategoryAsync(
        HttpStatusCode statusCode,
        WindowsReleaseQueryFailureCategory category)
    {
        using var httpClient = new HttpClient(new StubHandler(statusCode, string.Empty));
        var client = new GitHubWindowsReleaseClient(httpClient);

        var exception = await Assert.ThrowsExactlyAsync<WindowsReleaseQueryException>(
            () => client.GetLatestAsync(CancellationToken.None));
        Assert.AreEqual(category, exception.Category);
    }

    private static string Descriptor(string version)
    {
        var tag = $"v{version}";
        var repository = "https://github.com/HongXunPan/mihomo-meter";
        var hashA = new string('a', 64);
        var hashB = new string('b', 64);
        return $$"""
            {
              "schemaVersion": 1,
              "platform": "windows",
              "version": "{{version}}",
              "sourceTag": "{{tag}}",
              "releasePageUrl": "{{repository}}/releases/tag/{{tag}}",
              "assets": [
                {
                  "kind": "installer",
                  "architecture": "x64",
                  "label": "Windows x64 安装版",
                  "fileName": "Mihomo-Meter-{{version}}-windows-x64-setup.exe",
                  "downloadUrl": "{{repository}}/releases/download/{{tag}}/Mihomo-Meter-{{version}}-windows-x64-setup.exe",
                  "sha256": "{{hashA}}"
                },
                {
                  "kind": "portable",
                  "architecture": "x64",
                  "label": "Windows x64 便携版",
                  "fileName": "Mihomo-Meter-{{version}}-windows-x64-portable.zip",
                  "downloadUrl": "{{repository}}/releases/download/{{tag}}/Mihomo-Meter-{{version}}-windows-x64-portable.zip",
                  "sha256": "{{hashB}}"
                }
              ]
            }
            """;
    }

    private sealed class StubHandler : HttpMessageHandler
    {
        private readonly HttpStatusCode _statusCode;
        private readonly string _content;
        private readonly Uri? _responseUri;

        public StubHandler(HttpStatusCode statusCode, string content, Uri? responseUri = null)
        {
            _statusCode = statusCode;
            _content = content;
            _responseUri = responseUri;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            if (_responseUri is not null)
            {
                request.RequestUri = _responseUri;
            }
            return Task.FromResult(new HttpResponseMessage(_statusCode)
            {
                RequestMessage = request,
                Content = new StringContent(_content, Encoding.UTF8, "application/json"),
            });
        }
    }
}
