using System.Runtime.InteropServices;
using System.Text;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Diagnostics;

internal static class StartupConsoleReporter
{
    private const string EnabledEnvironmentVariable = "MIHOMO_METER_STARTUP_CONSOLE";
    private const uint AttachParentProcess = uint.MaxValue;
    private const int ErrorAccessDenied = 5;

    private static bool _enabled;
    private static string _currentStage = "not_started";
    private static readonly object ExportEventGate = new();
    private static readonly List<DiagnosticExportEvent> ExportEvents = [];

    public static void Initialize()
    {
        if (!string.Equals(
                Environment.GetEnvironmentVariable(EnabledEnvironmentVariable),
                "1",
                StringComparison.Ordinal))
        {
            return;
        }

        try
        {
            var attached = AttachConsole(AttachParentProcess);
            if (!attached && Marshal.GetLastWin32Error() != ErrorAccessDenied)
            {
                return;
            }

            var encoding = new UTF8Encoding(false);
            Console.OutputEncoding = encoding;
            var writer = TextWriter.Synchronized(
                new StreamWriter(Console.OpenStandardOutput(), encoding)
                {
                    AutoFlush = true,
                });
            Console.SetOut(writer);
            Console.SetError(writer);
            _enabled = true;
            Stage("diagnostics_console_ready");
        }
        catch
        {
            _enabled = false;
        }
    }

    public static void Stage(string stage)
    {
        _currentStage = stage;
        RetainForExport(DiagnosticExportEvent.ApplicationStage(
            DateTimeOffset.UtcNow,
            stage));
        if (_enabled)
        {
            Console.WriteLine($"WINDOWS_STAGE stage={stage}");
        }
    }

    public static void Failure(string source, Exception exception)
    {
        RetainForExport(DiagnosticExportEvent.ApplicationFailure(
            DateTimeOffset.UtcNow,
            source,
            _currentStage,
            exception.HResult));
        if (!_enabled)
        {
            return;
        }

        var exceptionType = exception.GetType().FullName ?? exception.GetType().Name;
        Console.Error.WriteLine(
            $"WINDOWS_FAILURE source={source} stage={_currentStage} "
            + $"type={exceptionType} hresult=0x{unchecked((uint)exception.HResult):X8}");
    }

    public static void TrafficShadow(string format, string result)
    {
        RetainForExport(DiagnosticExportEvent.SharedCoreTrafficShadow(
            DateTimeOffset.UtcNow,
            format,
            result));
        if (_enabled)
        {
            Console.WriteLine(
                $"WINDOWS_DIAGNOSTIC event=shared_core.traffic_shadow "
                + $"format={format} result={result}");
        }
    }

    public static void ProxyTypeShadow(string source, string status)
    {
        RetainForExport(DiagnosticExportEvent.SharedCoreProxyTypeShadow(
            DateTimeOffset.UtcNow,
            source,
            status));
        if (_enabled)
        {
            Console.WriteLine(
                "WINDOWS_DIAGNOSTIC event=shared_core.proxy_type_shadow "
                + $"source={source} status={status}");
        }
    }

    public static void ProxyTypeRoute(string source, string status)
    {
        RetainForExport(DiagnosticExportEvent.SharedCoreProxyTypeRoute(
            DateTimeOffset.UtcNow,
            source,
            status));
        if (_enabled)
        {
            Console.WriteLine(
                "WINDOWS_DIAGNOSTIC event=shared_core.proxy_type_route "
                + $"source={source} status={status}");
        }
    }

    public static void TrafficRoute(string format, string result, string status)
    {
        RetainForExport(DiagnosticExportEvent.SharedCoreTrafficRoute(
            DateTimeOffset.UtcNow,
            format,
            result,
            status));
        if (_enabled)
        {
            Console.WriteLine(
                $"WINDOWS_DIAGNOSTIC event=shared_core.traffic_route "
                + $"format={format} result={result} status={status}");
        }
    }

    public static IReadOnlyList<DiagnosticExportEvent> DiagnosticExportSnapshot()
    {
        lock (ExportEventGate)
        {
            return ExportEvents.ToArray();
        }
    }

    private static void RetainForExport(DiagnosticExportEvent diagnosticEvent)
    {
        lock (ExportEventGate)
        {
            ExportEvents.Add(diagnosticEvent);
            var overflow = ExportEvents.Count - DiagnosticExportReport.MaximumEventCount;
            if (overflow > 0)
            {
                ExportEvents.RemoveRange(0, overflow);
            }
        }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AttachConsole(uint processId);
}
