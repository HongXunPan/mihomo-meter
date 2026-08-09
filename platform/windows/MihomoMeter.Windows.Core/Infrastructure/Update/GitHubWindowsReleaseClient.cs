using System.Buffers;
using System.Net;
using System.Text.Json;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Update;

public sealed class GitHubWindowsReleaseClient : IWindowsReleaseQuery
{
    public static readonly Uri LatestDescriptorUri = new(
        "https://github.com/HongXunPan/mihomo-meter/releases/latest/download/windows-release.json");

    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(15);
    private const int MaximumDescriptorBytes = 1024 * 1024;
    private const string RepositoryUrl = "https://github.com/HongXunPan/mihomo-meter";
    private readonly HttpClient _httpClient;

    public GitHubWindowsReleaseClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<WindowsReleaseSnapshot> GetLatestAsync(
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, LatestDescriptorUri);
        request.Headers.Accept.ParseAdd("application/json");
        request.Headers.UserAgent.ParseAdd("Mihomo-Meter-Windows/1.0");

        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken);
        timeoutSource.CancelAfter(RequestTimeout);
        try
        {
            using var response = await _httpClient
                .SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    timeoutSource.Token)
                .ConfigureAwait(false);
            EnsureResponse(response);
            var content = await ReadContentAsync(response, timeoutSource.Token)
                .ConfigureAwait(false);
            return ParseDescriptor(content);
        }
        catch (WindowsReleaseQueryException)
        {
            throw;
        }
        catch (OperationCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            throw new WindowsReleaseQueryException(
                WindowsReleaseQueryFailureCategory.Network,
                "Windows 更新描述请求超时。",
                exception);
        }
        catch (HttpRequestException exception)
        {
            throw new WindowsReleaseQueryException(
                WindowsReleaseQueryFailureCategory.Network,
                "Windows 更新描述请求失败。",
                exception);
        }
        catch (IOException exception)
        {
            throw new WindowsReleaseQueryException(
                WindowsReleaseQueryFailureCategory.Network,
                "读取 Windows 更新描述失败。",
                exception);
        }
    }

    public static WindowsReleaseSnapshot ParseDescriptor(ReadOnlyMemory<byte> content)
    {
        try
        {
            using var document = JsonDocument.Parse(content);
            var root = document.RootElement;
            EnsureObjectProperties(
                root,
                "schemaVersion",
                "platform",
                "version",
                "sourceTag",
                "releasePageUrl",
                "assets");
            if (root.GetProperty("schemaVersion").GetInt32() != 1
                || root.GetProperty("platform").GetString() != "windows")
            {
                throw InvalidDescriptor();
            }

            var versionText = root.GetProperty("version").GetString();
            if (!ReleaseVersion.TryParse(versionText, out var version))
            {
                throw InvalidDescriptor();
            }

            var tag = $"v{version}";
            if (root.GetProperty("sourceTag").GetString() != tag)
            {
                throw InvalidDescriptor();
            }

            var expectedReleasePage = $"{RepositoryUrl}/releases/tag/{tag}";
            if (root.GetProperty("releasePageUrl").GetString() != expectedReleasePage)
            {
                throw InvalidDescriptor();
            }

            ValidateAssets(root.GetProperty("assets"), version, tag);
            return new WindowsReleaseSnapshot(version, new Uri(expectedReleasePage));
        }
        catch (WindowsReleaseQueryException)
        {
            throw;
        }
        catch (Exception exception) when (exception is JsonException
            or InvalidOperationException
            or FormatException
            or KeyNotFoundException)
        {
            throw InvalidDescriptor(exception);
        }
    }

    private static void EnsureResponse(HttpResponseMessage response)
    {
        if (response.StatusCode == HttpStatusCode.TooManyRequests
            || response.StatusCode == HttpStatusCode.Forbidden)
        {
            throw new WindowsReleaseQueryException(
                WindowsReleaseQueryFailureCategory.RateLimited,
                "GitHub 更新检查当前受到限流。若稍后重试仍失败，请直接访问项目 Release 页面。");
        }

        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            throw new WindowsReleaseQueryException(
                WindowsReleaseQueryFailureCategory.Unavailable,
                "尚未找到 Windows 正式版本描述。");
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new WindowsReleaseQueryException(
                WindowsReleaseQueryFailureCategory.Network,
                $"GitHub 更新检查返回 HTTP {(int)response.StatusCode}。");
        }

        var finalUri = response.RequestMessage?.RequestUri;
        if (finalUri is null
            || finalUri.Scheme != Uri.UriSchemeHttps
            || !IsAllowedDownloadHost(finalUri.Host))
        {
            throw InvalidDescriptor();
        }
        if (response.Content.Headers.ContentLength is > MaximumDescriptorBytes)
        {
            throw InvalidDescriptor();
        }
    }

    private static bool IsAllowedDownloadHost(string host)
    {
        return string.Equals(host, "github.com", StringComparison.OrdinalIgnoreCase)
            || host.EndsWith(".githubusercontent.com", StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<byte[]> ReadContentAsync(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        await using var stream = await response.Content
            .ReadAsStreamAsync(cancellationToken)
            .ConfigureAwait(false);
        using var output = new MemoryStream();
        var buffer = ArrayPool<byte>.Shared.Rent(16 * 1024);
        try
        {
            while (true)
            {
                var read = await stream
                    .ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken)
                    .ConfigureAwait(false);
                if (read == 0)
                {
                    break;
                }
                if (output.Length + read > MaximumDescriptorBytes)
                {
                    throw InvalidDescriptor();
                }
                output.Write(buffer, 0, read);
            }
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
        return output.ToArray();
    }

    private static void ValidateAssets(
        JsonElement assets,
        ReleaseVersion version,
        string tag)
    {
        if (assets.ValueKind != JsonValueKind.Array || assets.GetArrayLength() != 2)
        {
            throw InvalidDescriptor();
        }

        var expected = new[]
        {
            (
                Kind: "installer",
                Label: "Windows x64 安装版",
                FileName: $"Mihomo-Meter-{version}-windows-x64-setup.exe"),
            (
                Kind: "portable",
                Label: "Windows x64 便携版",
                FileName: $"Mihomo-Meter-{version}-windows-x64-portable.zip"),
        };
        var index = 0;
        foreach (var asset in assets.EnumerateArray())
        {
            EnsureObjectProperties(
                asset,
                "kind",
                "architecture",
                "label",
                "fileName",
                "downloadUrl",
                "sha256");
            var item = expected[index++];
            var expectedUrl = $"{RepositoryUrl}/releases/download/{tag}/{item.FileName}";
            var hash = asset.GetProperty("sha256").GetString();
            if (asset.GetProperty("kind").GetString() != item.Kind
                || asset.GetProperty("architecture").GetString() != "x64"
                || asset.GetProperty("label").GetString() != item.Label
                || asset.GetProperty("fileName").GetString() != item.FileName
                || asset.GetProperty("downloadUrl").GetString() != expectedUrl
                || hash is null
                || hash.Length != 64
                || hash.Any(character => !char.IsAsciiHexDigit(character)
                    || char.IsUpper(character)))
            {
                throw InvalidDescriptor();
            }
        }
    }

    private static void EnsureObjectProperties(JsonElement element, params string[] names)
    {
        if (element.ValueKind != JsonValueKind.Object)
        {
            throw InvalidDescriptor();
        }

        var actual = element.EnumerateObject().Select(property => property.Name).ToArray();
        if (actual.Length != names.Length
            || actual.Distinct(StringComparer.Ordinal).Count() != names.Length
            || names.Except(actual, StringComparer.Ordinal).Any())
        {
            throw InvalidDescriptor();
        }
    }

    private static WindowsReleaseQueryException InvalidDescriptor(
        Exception? innerException = null)
    {
        return new WindowsReleaseQueryException(
            WindowsReleaseQueryFailureCategory.InvalidDescriptor,
            "Windows 正式版本描述无效。",
            innerException);
    }
}
