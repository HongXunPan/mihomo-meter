using System.Buffers.Binary;
using System.Diagnostics;
using System.IO.Pipes;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class SingleInstanceCoordinator : IAsyncDisposable
{
    private const string InstanceMutexName =
        @"Local\com.HongXunPan.MihomoMeter.SingleInstance";
    private const string ActivationPipePrefix =
        "com.HongXunPan.MihomoMeter.Activation";
    private const byte ActivateMainWindowCommand = 1;
    private const byte ActivateStatisticsCommand = 2;
    private const byte ActivateSubscriptionQuotaCommand = 3;
    private const byte ActivateControllerSettingsCommand = 4;
    private static readonly TimeSpan ActivationTimeout = TimeSpan.FromSeconds(5);

    private readonly Mutex _instanceMutex;
    private readonly string _activationPipeName;
    private readonly CancellationTokenSource _listenerCancellation = new();
    private Task? _listenerTask;
    private bool _disposed;

    private SingleInstanceCoordinator(
        Mutex instanceMutex,
        bool isPrimary,
        string activationPipeName)
    {
        _instanceMutex = instanceMutex;
        IsPrimary = isPrimary;
        _activationPipeName = activationPipeName;
    }

    public bool IsPrimary { get; }

    public static SingleInstanceCoordinator CreateForCurrentSession()
    {
        var instanceMutex = new Mutex(false, InstanceMutexName, out var createdNew);
        using var currentProcess = Process.GetCurrentProcess();
        var sessionId = currentProcess.SessionId;
        var activationPipeName = $"{ActivationPipePrefix}.{sessionId}";
        return new SingleInstanceCoordinator(instanceMutex, createdNew, activationPipeName);
    }

    public void StartListening(
        Action<AppActivationTarget> activationRequested,
        Action<Exception> listenerFailure)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentNullException.ThrowIfNull(activationRequested);
        ArgumentNullException.ThrowIfNull(listenerFailure);
        if (!IsPrimary)
        {
            throw new InvalidOperationException("只有主实例可以监听唤起请求。");
        }

        if (_listenerTask is not null)
        {
            throw new InvalidOperationException("单实例唤起监听已经启动。");
        }

        _listenerTask = ListenAsync(
            activationRequested,
            listenerFailure,
            _listenerCancellation.Token);
    }

    public async Task RedirectActivationAsync(
        AppActivationTarget target,
        Action<uint> beforeActivation,
        CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentNullException.ThrowIfNull(beforeActivation);
        if (IsPrimary)
        {
            throw new InvalidOperationException("主实例不得重定向到自身。");
        }

        using var timeoutCancellation =
            CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCancellation.CancelAfter(ActivationTimeout);
        var timeoutToken = timeoutCancellation.Token;

        await using var client = new NamedPipeClientStream(
            ".",
            _activationPipeName,
            PipeDirection.InOut,
            PipeOptions.Asynchronous);
        await client.ConnectAsync(timeoutToken);

        var processIdBuffer = new byte[sizeof(uint)];
        await client.ReadExactlyAsync(processIdBuffer, timeoutToken);
        var primaryProcessId = BinaryPrimitives.ReadUInt32LittleEndian(processIdBuffer);
        if (primaryProcessId == 0)
        {
            throw new InvalidDataException("主实例返回了无效进程标识。");
        }

        beforeActivation(primaryProcessId);
        await client.WriteAsync(new byte[] { CommandFor(target) }, timeoutToken);
        await client.FlushAsync(timeoutToken);
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        await _listenerCancellation.CancelAsync().ConfigureAwait(false);
        if (_listenerTask is not null)
        {
            await _listenerTask.ConfigureAwait(false);
        }

        _listenerCancellation.Dispose();
        _instanceMutex.Dispose();
    }

    private async Task ListenAsync(
        Action<AppActivationTarget> activationRequested,
        Action<Exception> listenerFailure,
        CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await using var server = CreateActivationPipe();
                await server.WaitForConnectionAsync(cancellationToken);

                using var requestCancellation =
                    CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                requestCancellation.CancelAfter(ActivationTimeout);
                await HandleActivationRequestAsync(
                    server,
                    activationRequested,
                    requestCancellation.Token);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                listenerFailure(exception);
                try
                {
                    await Task.Delay(TimeSpan.FromMilliseconds(250), cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    return;
                }
            }
        }
    }

    private NamedPipeServerStream CreateActivationPipe()
    {
        return new NamedPipeServerStream(
            _activationPipeName,
            PipeDirection.InOut,
            1,
            PipeTransmissionMode.Byte,
            PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
    }

    private static async Task HandleActivationRequestAsync(
        NamedPipeServerStream server,
        Action<AppActivationTarget> activationRequested,
        CancellationToken cancellationToken)
    {
        var processIdBuffer = new byte[sizeof(uint)];
        BinaryPrimitives.WriteUInt32LittleEndian(
            processIdBuffer,
            checked((uint)Environment.ProcessId));
        await server.WriteAsync(processIdBuffer, cancellationToken);
        await server.FlushAsync(cancellationToken);

        var commandBuffer = new byte[1];
        await server.ReadExactlyAsync(commandBuffer, cancellationToken);
        activationRequested(TargetFor(commandBuffer[0]));
    }

    private static byte CommandFor(AppActivationTarget target)
    {
        return target switch
        {
            AppActivationTarget.MainWindow => ActivateMainWindowCommand,
            AppActivationTarget.Statistics => ActivateStatisticsCommand,
            AppActivationTarget.SubscriptionQuota => ActivateSubscriptionQuotaCommand,
            AppActivationTarget.ControllerSettings => ActivateControllerSettingsCommand,
            _ => throw new ArgumentOutOfRangeException(nameof(target)),
        };
    }

    private static AppActivationTarget TargetFor(byte command)
    {
        return command switch
        {
            ActivateMainWindowCommand => AppActivationTarget.MainWindow,
            ActivateStatisticsCommand => AppActivationTarget.Statistics,
            ActivateSubscriptionQuotaCommand => AppActivationTarget.SubscriptionQuota,
            ActivateControllerSettingsCommand => AppActivationTarget.ControllerSettings,
            _ => throw new InvalidDataException("收到未知的单实例唤起命令。"),
        };
    }
}
