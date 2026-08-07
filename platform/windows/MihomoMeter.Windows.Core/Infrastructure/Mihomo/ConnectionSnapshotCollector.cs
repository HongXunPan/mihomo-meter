using System.Net.WebSockets;
using System.Runtime.CompilerServices;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

public interface IConnectionSnapshotCollector
{
    IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
        ControllerEndpoint endpoint,
        string secret,
        CancellationToken cancellationToken);
}

public sealed class ConnectionSnapshotCollector : IConnectionSnapshotCollector
{
    private const int ReceiveBufferSize = 16 * 1024;
    private static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(5);

    public async IAsyncEnumerable<MihomoConnectionsSnapshot> CollectAsync(
        ControllerEndpoint endpoint,
        string secret,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        using var socket = new ClientWebSocket();
        socket.Options.Proxy = null;
        if (secret.Length > 0)
        {
            socket.Options.SetRequestHeader("Authorization", $"Bearer {secret}");
        }

        await ConnectAsync(socket, endpoint, cancellationToken).ConfigureAwait(false);

        while (!cancellationToken.IsCancellationRequested)
        {
            yield return await ReceiveSnapshotAsync(socket, cancellationToken)
                .ConfigureAwait(false);
        }
    }

    private static async Task ConnectAsync(
        ClientWebSocket socket,
        ControllerEndpoint endpoint,
        CancellationToken cancellationToken)
    {
        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(ConnectTimeout);
        try
        {
            await socket.ConnectAsync(
                endpoint.WebSocketUri("/connections", "interval=500"),
                timeoutSource.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new ConnectionStreamException(ConnectionStreamError.Timeout);
        }
        catch (WebSocketException exception)
        {
            throw new ConnectionStreamException(ConnectionStreamError.Network, exception);
        }
    }

    private static async Task<MihomoConnectionsSnapshot> ReceiveSnapshotAsync(
        ClientWebSocket socket,
        CancellationToken cancellationToken)
    {
        var buffer = new byte[ReceiveBufferSize];
        using var message = new ConnectionMessageAssembler();

        try
        {
            while (true)
            {
                var result = await socket
                    .ReceiveAsync(buffer.AsMemory(), cancellationToken)
                    .ConfigureAwait(false);

                if (result.MessageType == WebSocketMessageType.Close)
                {
                    throw new ConnectionStreamException(ConnectionStreamError.Closed);
                }

                if (message.Append(
                        result.MessageType,
                        buffer.AsSpan(0, result.Count),
                        result.EndOfMessage))
                {
                    break;
                }
            }
        }
        catch (WebSocketException exception)
        {
            throw new ConnectionStreamException(ConnectionStreamError.Network, exception);
        }

        return message.Decode();
    }
}

public enum ConnectionStreamError
{
    UnsupportedResponse,
    MessageTooLarge,
    Network,
    Timeout,
    Closed,
    DataStale,
}

public sealed class ConnectionStreamException : Exception
{
    public ConnectionStreamException(
        ConnectionStreamError reason,
        Exception? innerException = null)
        : base(MessageFor(reason), innerException)
    {
        Reason = reason;
    }

    public ConnectionStreamError Reason { get; }

    private static string MessageFor(ConnectionStreamError reason)
    {
        return reason switch
        {
            ConnectionStreamError.UnsupportedResponse => "当前连接快照结构暂不受支持。",
            ConnectionStreamError.MessageTooLarge => "Mihomo 连接快照超过安全大小限制。",
            ConnectionStreamError.Timeout => "Mihomo 实时数据连接超时。",
            ConnectionStreamError.Network => "Mihomo 实时数据连接中断。",
            ConnectionStreamError.DataStale => "Mihomo 实时数据持续超时。",
            ConnectionStreamError.Closed => "Mihomo 实时数据连接已关闭。",
            _ => "Mihomo 实时数据连接失败。",
        };
    }
}
