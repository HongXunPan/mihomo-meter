using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

public sealed class ConnectionMetadataJsonConverter
    : JsonConverter<ConnectionMetadata>
{
    private const int MaximumMetadataBytes = 2_048;

    public override ConnectionMetadata Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader);
        if (document.RootElement.ValueKind != JsonValueKind.Object)
        {
            return ConnectionMetadata.Unavailable;
        }

        var metadata = document.RootElement;
        var host = StringValue(metadata, "host");
        var sniffHost = StringValue(metadata, "sniffHost");
        var process = StringValue(metadata, "process");
        var processPath = StringValue(metadata, "processPath");
        return new ConnectionMetadata(
            NormalizedHostname(host) ?? NormalizedHostname(sniffHost),
            ApplicationName(process, processPath));
    }

    public override void Write(
        Utf8JsonWriter writer,
        ConnectionMetadata value,
        JsonSerializerOptions options)
    {
        throw new NotSupportedException("连接元数据只允许从 Mihomo 响应解码。");
    }

    private static string? StringValue(JsonElement metadata, string propertyName)
    {
        return metadata.TryGetProperty(propertyName, out var value)
            && value.ValueKind == JsonValueKind.String
                ? value.GetString()
                : null;
    }

    private static string? NormalizedHostname(string? value)
    {
        var hostname = Normalized(value);
        if (hostname is null)
        {
            return null;
        }

        var candidate = hostname.Trim('[', ']');
        return IPAddress.TryParse(candidate, out _) ? null : hostname;
    }

    private static string? ApplicationName(string? process, string? processPath)
    {
        if (OutermostApplicationBundleName(processPath) is string applicationName)
        {
            return applicationName;
        }

        var normalizedProcess = Normalized(process);
        if (normalizedProcess is not null)
        {
            return ContainsPathSeparator(normalizedProcess)
                ? FileName(normalizedProcess)
                : normalizedProcess;
        }

        return FileName(processPath);
    }

    private static string? OutermostApplicationBundleName(string? path)
    {
        var normalizedPath = Normalized(path);
        if (normalizedPath is null)
        {
            return null;
        }

        foreach (var component in PathComponents(normalizedPath))
        {
            if (!component.EndsWith(".app", StringComparison.OrdinalIgnoreCase)
                || component.Length <= 4)
            {
                continue;
            }

            var applicationName = Normalized(component[..^4]);
            if (applicationName is not null)
            {
                return applicationName;
            }
        }

        return null;
    }

    private static string? FileName(string? path)
    {
        var normalizedPath = Normalized(path);
        if (normalizedPath is null)
        {
            return null;
        }

        return PathComponents(normalizedPath).LastOrDefault() is { Length: > 0 } fileName
            ? Normalized(fileName)
            : null;
    }

    private static string[] PathComponents(string path)
    {
        return path.Split(
            ['/', '\\'],
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    private static bool ContainsPathSeparator(string value)
    {
        return value.Contains('/') || value.Contains('\\');
    }

    private static string? Normalized(string? value)
    {
        if (value is null)
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length > 0
            && Encoding.UTF8.GetByteCount(normalized) <= MaximumMetadataBytes
                ? normalized
                : null;
    }
}
