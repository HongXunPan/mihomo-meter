using System.Globalization;
using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.Windows.Storage.Pickers;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Diagnostics;

internal enum DiagnosticExportResult
{
    Exported,
    Cancelled,
}

internal sealed class DiagnosticExportService
{
    public async Task<DiagnosticExportResult> ExportAsync(
        WindowId windowId,
        MonitorConnectionState connectionState,
        CancellationToken cancellationToken = default)
    {
        var picker = new FileSavePicker(windowId)
        {
            CommitButtonText = "导出",
            DefaultFileExtension = ".json",
            SettingsIdentifier = "diagnostic-export",
            ShowOverwritePrompt = true,
            SuggestedFileName = SuggestedFileName(),
            Title = "导出诊断信息",
        };
        var result = await picker.PickSaveFileAsync();
        if (result is null)
        {
            return DiagnosticExportResult.Cancelled;
        }

        var report = DiagnosticExportReport.Create(
            DateTimeOffset.UtcNow,
            CurrentEnvironment(),
            ConnectionStateValue(connectionState),
            StartupConsoleReporter.DiagnosticExportSnapshot());
        await File.WriteAllBytesAsync(result.Path, report.Encode(), cancellationToken);
        return DiagnosticExportResult.Exported;
    }

    private static DiagnosticExportEnvironment CurrentEnvironment()
    {
        var version = typeof(App).Assembly.GetName().Version;
        return new DiagnosticExportEnvironment(
            "windows",
            version is null
                ? "unknown"
                : string.Create(
                    CultureInfo.InvariantCulture,
                    $"{version.Major}.{version.Minor}.{version.Build}"),
            version?.Revision.ToString(CultureInfo.InvariantCulture) ?? "unknown",
            RuntimeInformation.OSDescription,
            RuntimeInformation.ProcessArchitecture.ToString().ToLowerInvariant());
    }

    private static string ConnectionStateValue(MonitorConnectionState state)
    {
        return state switch
        {
            MonitorConnectionState.Disconnected => "disconnected",
            MonitorConnectionState.Connecting => "connecting",
            MonitorConnectionState.Connected => "connected",
            MonitorConnectionState.Stale => "stale",
            MonitorConnectionState.Reconnecting => "reconnecting",
            MonitorConnectionState.AuthenticationFailed => "authentication_failed",
            MonitorConnectionState.Unsupported => "unsupported",
            _ => "unknown",
        };
    }

    private static string SuggestedFileName()
    {
        var timestamp = DateTime.Now.ToString(
            "yyyyMMdd-HHmmss",
            CultureInfo.InvariantCulture);
        return $"Mihomo-Meter-Diagnostics-{timestamp}.json";
    }
}
