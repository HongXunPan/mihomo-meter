"""定义 Windows 基础系统能力静态门禁。"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WINDOWS_ROOT = ROOT / "platform" / "windows"
APP_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.App"
CORE_ROOT = WINDOWS_ROOT / "MihomoMeter.Windows.Core"

SYSTEM_CAPABILITY_REQUIRED_REPOSITORY_FILES = (
    "docs/Windows受限恢复重启实现契约.md",
    "scripts/windows_validation_system_capability_contract.py",
)

SYSTEM_CAPABILITY_REQUIRED_APP_FILES = (
    "Diagnostics/StartupConsoleReporter.cs",
    "Diagnostics/DiagnosticExportService.cs",
    "Infrastructure/Notifications/JsonSystemNotificationPreferencesStore.cs",
    "Infrastructure/Notifications/WindowsSystemNotificationService.cs",
    "Infrastructure/System/WindowsSystemEnvironmentMonitor.cs",
    "Infrastructure/Recovery/JsonCrashRecoveryRestartStateStore.cs",
    "Interop/ApplicationRestartNativeMethods.cs",
    "Application/SystemNotificationCoordinator.cs",
    "Application/SystemRecoveryCoordinator.cs",
    "Application/CrashRecoveryRestartCoordinator.cs",
)

SYSTEM_CAPABILITY_REQUIRED_CORE_FILES = (
    "Application/DiagnosticExportEvent.cs",
    "Application/DiagnosticExportReport.cs",
    "Application/DiagnosticExportRuntimeEvents.cs",
    "Application/TrafficMonitoringCoordinator.SystemRecovery.cs",
    "Domain/SystemNotificationPolicy.cs",
    "Domain/SystemRecoveryPolicy.cs",
    "Domain/CrashRecoveryRestartPolicy.cs",
)

SYSTEM_CAPABILITY_REQUIRED_TEST_FILES = (
    "DiagnosticExportReportTests.cs",
    "SystemNotificationPolicyTests.cs",
    "SystemRecoveryPolicyTests.cs",
    "CrashRecoveryRestartPolicyTests.cs",
)

SYSTEM_CAPABILITY_REQUIRED_CODE_MARKERS = {
    APP_ROOT / "Diagnostics/DiagnosticExportService.cs": (
        "FileSavePicker",
        "DiagnosticExportReport.Create",
        "File.WriteAllBytesAsync",
    ),
    APP_ROOT / "Diagnostics/StartupConsoleReporter.cs": (
        "DiagnosticExportSnapshot",
        "DiagnosticExportEvent.ApplicationFailure",
        "DiagnosticExportReport.MaximumEventCount",
        "StartupDiagnosticEventSink",
    ),
    APP_ROOT / "Presentation/GeneralSettingsView.xaml": (
        'Content="导出诊断信息…"',
        "DiagnosticExportInfoBar",
        'Text="帮助与文档"',
        "wiki.metacubex.one/config/general/",
        "issues/new/choose",
    ),
    CORE_ROOT / "Application/DiagnosticExportReport.cs": (
        "CurrentSchemaVersion = 1",
        "MaximumEventCount = 200",
        "JsonIgnoreCondition.WhenWritingNull",
    ),
    CORE_ROOT / "Application/DiagnosticExportEvent.cs": (
        "AllowedToken",
    ),
    CORE_ROOT / "Application/DiagnosticExportRuntimeEvents.cs": (
        "CredentialOperationFinished",
        "ConnectionReconnectScheduled",
        "ProfileQuotaQueryFinished",
        "credential.operation.started",
        "connection.attempt.started",
        "profile_quota.query.started",
    ),
    APP_ROOT / "Infrastructure/System/WindowsSystemEnvironmentMonitor.cs": (
        "WTSRegisterSessionNotification",
        "WindowMessagePowerBroadcast",
        "WindowMessageSessionChange",
        "NetworkAvailabilityChanged",
    ),
    APP_ROOT / "Application/SystemRecoveryCoordinator.cs": (
        "SystemRecoveryPolicy",
        "SetSystemEnvironmentAvailableAsync",
        "StartAsync",
    ),
    CORE_ROOT / "Application/TrafficMonitoringCoordinator.SystemRecovery.cs": (
        "TrafficSessionEndReason.Recovery",
        "ResumeAfterSystemRecoveryAsync",
        "LoadAsync(cancellationToken)",
    ),
    CORE_ROOT / "Domain/SystemRecoveryPolicy.cs": (
        "SystemEnvironmentBlocker",
        "SystemRecoveryAction",
    ),
    APP_ROOT / "Infrastructure/Notifications/WindowsSystemNotificationService.cs": (
        "AppNotificationManager.Default",
        '.AddArgument("target",',
        "_manager.Register();",
        "_manager.Unregister();",
    ),
    APP_ROOT / "Infrastructure/Notifications/JsonSystemNotificationPreferencesStore.cs": (
        '"notification-settings.json"',
        "ConnectionSystemNotificationPolicy.DeduplicationKey",
        "Guid.TryParseExact",
    ),
    APP_ROOT / "Application/SystemNotificationCoordinator.cs": (
        "QuotaSystemNotificationPolicy.Deliveries",
        "ConnectionSystemNotificationPolicy.ShouldNotify",
        "requiresDisconnectPreference",
    ),
    CORE_ROOT / "Domain/SystemNotificationPolicy.cs": (
        "TimeSpan.FromMinutes(15)",
        "TimeSpan.FromDays(3)",
        "TimeSpan.FromMinutes(10)",
    ),
    CORE_ROOT / "Domain/CrashRecoveryRestartPolicy.cs": (
        'RecoveryArgumentPrefix = "--system-recovery-restart="',
        "TimeSpan.FromMinutes(10)",
        "TimeSpan.FromMinutes(30)",
        "RecoverySuppressed",
    ),
    APP_ROOT / "Infrastructure/Recovery/JsonCrashRecoveryRestartStateStore.cs": (
        '"recovery-restart.json"',
        '"recovery-restart.pending.json"',
        "File.Move(pendingPath, _statePath, true)",
    ),
    APP_ROOT / "Interop/ApplicationRestartNativeMethods.cs": (
        "RegisterApplicationRestart",
        "UnregisterApplicationRestart",
        "NoPatch = 4",
        "NoReboot = 8",
    ),
    APP_ROOT / "Application/CrashRecoveryRestartCoordinator.cs": (
        "CrashRecoveryRestartPolicy.RegistrationDelay",
        "ApplicationRestartFlags.NoPatch | ApplicationRestartFlags.NoReboot",
        "UnregisterForExplicitExit",
        "TimeProvider.System",
    ),
    APP_ROOT / "Program.cs": (
        "CrashRecoveryRestartPolicy.HasRecoveryArgument",
        "CrashRecoveryStartupDisposition.RecoverySuppressed",
        "crashRecoveryRestart.RegisterForCurrentProcess",
    ),
    APP_ROOT / "App.xaml.cs": (
        "_isStartupLaunch",
        "!hasStoredConfiguration && !_isStartupLaunch",
        "_registerCrashRecoveryRestart();",
        "_unregisterCrashRecoveryRestart();",
    ),
}
