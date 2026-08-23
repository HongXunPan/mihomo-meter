using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class DiagnosticExportReportTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.FromUnixTimeSeconds(1_800_000_000);

    [TestMethod]
    public void EventFactoriesRejectValuesOutsideExactAllowlists()
    {
        var events = new[]
        {
            DiagnosticExportEvent.ApplicationStage(Now, "C:\\Users\\private\\file"),
            DiagnosticExportEvent.ApplicationFailure(
                Now,
                "subscription.example",
                "main_window_ready",
                unchecked((int)0x80004005)),
        };
        var report = DiagnosticExportReport.Create(
            Now,
            new DiagnosticExportEnvironment(
                "windows",
                "1.2.3",
                "4",
                "Windows 10",
                "x64"),
            "connected",
            events);

        var contents = Encoding.UTF8.GetString(report.Encode());

        StringAssert.Contains(contents, "\"schemaVersion\": 1");
        StringAssert.Contains(contents, "\"connectionState\": \"connected\"");
        StringAssert.Contains(contents, "\"stage\": \"unknown\"");
        StringAssert.Contains(contents, "\"source\": \"unknown\"");
        Assert.IsFalse(contents.Contains("Users", StringComparison.Ordinal));
        Assert.IsFalse(contents.Contains("subscription.example", StringComparison.Ordinal));
    }

    [TestMethod]
    public void ReportRetainsOnlyLatestEvents()
    {
        var events = Enumerable.Range(1, DiagnosticExportReport.MaximumEventCount + 2)
            .Select(index => DiagnosticExportEvent.ApplicationStage(
                Now.AddSeconds(index),
                "app_launch_completed"))
            .ToArray();

        var report = DiagnosticExportReport.Create(
            Now,
            new DiagnosticExportEnvironment("windows", "1", "1", "Windows", "x64"),
            "disconnected",
            events);

        Assert.AreEqual(DiagnosticExportReport.MaximumEventCount, report.Events.Count);
        Assert.AreEqual(Now.AddSeconds(3), report.Events[0].Timestamp);
        Assert.AreEqual(
            Now.AddSeconds(DiagnosticExportReport.MaximumEventCount + 2),
            report.Events[^1].Timestamp);
    }
}
