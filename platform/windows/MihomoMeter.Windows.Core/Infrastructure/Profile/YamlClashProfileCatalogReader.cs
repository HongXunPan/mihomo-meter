using System.Text;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Profile;

public sealed class YamlClashProfileCatalogReader : IProfileCatalogReader
{
    internal const long MaximumFileSize = 2 * 1_024 * 1_024;
    private const string ProfilesFileName = "profiles.yaml";

    public ClashProfileCatalog Read(string directoryPath)
    {
        try
        {
            var directory = new DirectoryInfo(directoryPath);
            if (!directory.Exists || ProfilePathPolicy.IsReparsePoint(directory.Attributes))
            {
                throw new ProfileDirectoryException("所选 Profile 目录无效。");
            }

            var file = new FileInfo(Path.Combine(directory.FullName, ProfilesFileName));
            if (!file.Exists || ProfilePathPolicy.IsReparsePoint(file.Attributes))
            {
                throw new ProfileDirectoryException("所选目录中没有可读取的 profiles.yaml。");
            }

            if (ProfilePathPolicy.ExceedsMaximumSize(file.Length, MaximumFileSize))
            {
                throw new ProfileDirectoryException("profiles.yaml 超出安全读取上限。");
            }

            using var stream = new FileStream(
                file.FullName,
                FileMode.Open,
                FileAccess.Read,
                FileShare.ReadWrite | FileShare.Delete);
            if (ProfilePathPolicy.ExceedsMaximumSize(stream.Length, MaximumFileSize))
            {
                throw new ProfileDirectoryException("profiles.yaml 超出安全读取上限。");
            }

            using var reader = new StreamReader(
                stream,
                new System.Text.UTF8Encoding(false, true),
                detectEncodingFromByteOrderMarks: true);
            var deserializer = new DeserializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .IgnoreUnmatchedProperties()
                .Build();
            var document = deserializer.Deserialize<ClashProfilesDocument>(reader)
                ?? throw new ProfileDirectoryException("profiles.yaml 格式无效。");
            return Catalog(document);
        }
        catch (ProfileDirectoryException)
        {
            throw;
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or DecoderFallbackException
                or YamlDotNet.Core.YamlException)
        {
            throw new ProfileDirectoryException("profiles.yaml 格式无效或无法读取。", exception);
        }
    }

    private static ClashProfileCatalog Catalog(ClashProfilesDocument document)
    {
        var profiles = new List<ClashProfile>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var ignored = 0;
        foreach (var item in document.Items ?? [])
        {
            if (!string.Equals(item.Type, "remote", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (string.IsNullOrWhiteSpace(item.Uid)
                || string.IsNullOrWhiteSpace(item.Name)
                || !Uri.TryCreate(item.Url, UriKind.Absolute, out var uri))
            {
                ignored += 1;
                continue;
            }

            ClashProfile profile;
            try
            {
                profile = new ClashProfile(item.Uid, item.Name, uri);
            }
            catch (QuotaDomainException)
            {
                ignored += 1;
                continue;
            }

            if (!seen.Add(profile.Uid))
            {
                throw new ProfileDirectoryException("profiles.yaml 包含重复 UID。");
            }

            profiles.Add(profile);
        }

        var current = string.IsNullOrWhiteSpace(document.Current)
            ? null
            : document.Current.Trim();
        return new ClashProfileCatalog(current, profiles.AsReadOnly(), ignored);
    }

}

internal sealed class ClashProfilesDocument
{
    public ClashProfilesDocument()
    {
    }

    public string? Current { get; set; }

    public List<ClashProfileItem>? Items { get; set; }
}

internal sealed class ClashProfileItem
{
    public ClashProfileItem()
    {
    }

    public string? Uid { get; set; }

    public string? Type { get; set; }

    public string? Name { get; set; }

    public string? Url { get; set; }
}

internal static class ProfilePathPolicy
{
    public static bool IsReparsePoint(FileAttributes attributes)
    {
        return attributes.HasFlag(FileAttributes.ReparsePoint);
    }

    public static bool ExceedsMaximumSize(long size, long maximumSize)
    {
        return size < 0 || maximumSize < 0 || size > maximumSize;
    }
}
