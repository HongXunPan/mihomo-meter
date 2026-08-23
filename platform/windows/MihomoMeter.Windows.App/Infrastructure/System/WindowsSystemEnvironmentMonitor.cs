using System.ComponentModel;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Infrastructure.System;

internal sealed class WindowsSystemEnvironmentMonitor : IDisposable
{
    private const uint WindowMessagePowerBroadcast = 0x0218;
    private const uint WindowMessageSessionChange = 0x02B1;
    private const uint PowerSuspend = 0x0004;
    private const uint PowerResumeCritical = 0x0006;
    private const uint PowerResumeSuspend = 0x0007;
    private const uint PowerResumeAutomatic = 0x0012;
    private const uint SessionLock = 0x0007;
    private const uint SessionUnlock = 0x0008;
    private static readonly nuint WindowSubclassId = 0x4D4D5352;

    private readonly nint _windowHandle;
    private readonly ShellNativeMethods.SubclassProcedure _subclassProcedure;
    private bool _sessionRegistered;
    private bool _started;
    private bool _disposed;

    public WindowsSystemEnvironmentMonitor(nint windowHandle)
    {
        if (windowHandle == 0)
        {
            throw new ArgumentException("系统环境监听需要有效窗口句柄。", nameof(windowHandle));
        }

        _windowHandle = windowHandle;
        _subclassProcedure = WindowSubclassProcedure;
    }

    public event Action<SystemEnvironmentBlocker, bool>? EnvironmentChanged;

    public bool Start()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (_started)
        {
            return _sessionRegistered;
        }

        if (!ShellNativeMethods.SetWindowSubclass(
                _windowHandle,
                _subclassProcedure,
                WindowSubclassId,
                0))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        _sessionRegistered = SystemLifecycleNativeMethods.WTSRegisterSessionNotification(
            _windowHandle,
            SystemLifecycleNativeMethods.NotifyForThisSession);
        NetworkChange.NetworkAvailabilityChanged += NetworkChange_NetworkAvailabilityChanged;
        _started = true;
        Publish(
            SystemEnvironmentBlocker.NetworkUnavailable,
            !NetworkInterface.GetIsNetworkAvailable());
        return _sessionRegistered;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        if (!_started)
        {
            return;
        }

        NetworkChange.NetworkAvailabilityChanged -= NetworkChange_NetworkAvailabilityChanged;
        if (_sessionRegistered)
        {
            SystemLifecycleNativeMethods.WTSUnRegisterSessionNotification(_windowHandle);
        }
        ShellNativeMethods.RemoveWindowSubclass(
            _windowHandle,
            _subclassProcedure,
            WindowSubclassId);
        _started = false;
    }

    private nint WindowSubclassProcedure(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter,
        nuint subclassId,
        nuint referenceData)
    {
        if (!_disposed)
        {
            HandleWindowMessage(message, wordParameter);
        }
        return ShellNativeMethods.DefSubclassProc(
            windowHandle,
            message,
            wordParameter,
            longParameter);
    }

    private void HandleWindowMessage(uint message, nuint wordParameter)
    {
        var value = unchecked((uint)wordParameter);
        if (message == WindowMessagePowerBroadcast)
        {
            if (value == PowerSuspend)
            {
                Publish(SystemEnvironmentBlocker.Sleep, true);
            }
            else if (value is PowerResumeCritical or PowerResumeSuspend or PowerResumeAutomatic)
            {
                Publish(SystemEnvironmentBlocker.Sleep, false);
            }
        }
        else if (message == WindowMessageSessionChange)
        {
            if (value == SessionLock)
            {
                Publish(SystemEnvironmentBlocker.InactiveSession, true);
            }
            else if (value == SessionUnlock)
            {
                Publish(SystemEnvironmentBlocker.InactiveSession, false);
            }
        }
    }

    private void NetworkChange_NetworkAvailabilityChanged(
        object? sender,
        NetworkAvailabilityEventArgs args)
    {
        Publish(SystemEnvironmentBlocker.NetworkUnavailable, !args.IsAvailable);
    }

    private void Publish(SystemEnvironmentBlocker blocker, bool isBlocked)
    {
        if (!_disposed)
        {
            EnvironmentChanged?.Invoke(blocker, isBlocked);
        }
    }
}
