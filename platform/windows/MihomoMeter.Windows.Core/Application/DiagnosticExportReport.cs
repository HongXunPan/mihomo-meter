using System.Text.Json;
using System.Text.Json.Serialization;

namespace MihomoMeter.Windows.Core.Application;

public sealed record DiagnosticExportEnvironment(
    string Platform,
    string Version,
    string Build,
    string OperatingSystem,
    string Architecture);

public sealed record DiagnosticExportRuntime(string ConnectionState);

public sealed record DiagnosticExportReport(
    int SchemaVersion,
    DateTimeOffset GeneratedAt,
    DiagnosticExportEnvironment Application,
    DiagnosticExportRuntime Runtime,
    IReadOnlyList<DiagnosticExportEvent> Events)
{
    public const int CurrentSchemaVersion = 1;
    public const int MaximumEventCount = 200;

    public static DiagnosticExportReport Create(
        DateTimeOffset generatedAt,
        DiagnosticExportEnvironment application,
        string connectionState,
        IReadOnlyList<DiagnosticExportEvent> events)
    {
        ArgumentNullException.ThrowIfNull(application);
        ArgumentNullException.ThrowIfNull(connectionState);
        ArgumentNullException.ThrowIfNull(events);
        return new DiagnosticExportReport(
            CurrentSchemaVersion,
            generatedAt,
            application,
            new DiagnosticExportRuntime(connectionState),
            events.TakeLast(MaximumEventCount).ToArray());
    }

    public byte[] Encode()
    {
        return JsonSerializer.SerializeToUtf8Bytes(
            this,
            new JsonSerializerOptions
            {
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = true,
            });
    }
}
