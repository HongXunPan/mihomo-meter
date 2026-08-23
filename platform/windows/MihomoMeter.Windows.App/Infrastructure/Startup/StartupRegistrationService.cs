using Microsoft.Win32;

namespace MihomoMeter.Windows.App.Infrastructure.Startup;

internal enum StartupRegistrationStatus
{
    Disabled,
    EnabledForCurrentExecutable,
    EnabledForDifferentExecutable,
}

internal sealed class StartupRegistrationService
{
    internal const string StartupArgument = "--startup";
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "Mihomo Meter";

    public StartupRegistrationStatus ReadStatus()
    {
        using var currentUser = RegistryKey.OpenBaseKey(
            RegistryHive.CurrentUser,
            RegistryView.Registry64);
        using var runKey = currentUser.OpenSubKey(RunKeyPath, writable: false);
        var registeredCommand = runKey?.GetValue(
            RunValueName,
            null,
            RegistryValueOptions.DoNotExpandEnvironmentNames) as string;
        if (string.IsNullOrWhiteSpace(registeredCommand))
        {
            return StartupRegistrationStatus.Disabled;
        }

        return string.Equals(
            registeredCommand,
            CurrentExecutableCommand(),
            StringComparison.OrdinalIgnoreCase)
            ? StartupRegistrationStatus.EnabledForCurrentExecutable
            : StartupRegistrationStatus.EnabledForDifferentExecutable;
    }

    public void RegisterCurrentExecutable()
    {
        using var currentUser = RegistryKey.OpenBaseKey(
            RegistryHive.CurrentUser,
            RegistryView.Registry64);
        using var runKey = currentUser.CreateSubKey(RunKeyPath, writable: true)
            ?? throw new InvalidOperationException("无法打开当前用户登录启动注册表项。");
        runKey.SetValue(
            RunValueName,
            CurrentExecutableCommand(),
            RegistryValueKind.String);
    }

    public void Unregister()
    {
        using var currentUser = RegistryKey.OpenBaseKey(
            RegistryHive.CurrentUser,
            RegistryView.Registry64);
        using var runKey = currentUser.OpenSubKey(RunKeyPath, writable: true);
        runKey?.DeleteValue(RunValueName, throwOnMissingValue: false);
    }

    private static string CurrentExecutableCommand()
    {
        var executablePath = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(executablePath))
        {
            throw new InvalidOperationException("无法读取当前 Windows 程序路径。");
        }

        return $"\"{executablePath}\" {StartupArgument}";
    }
}
