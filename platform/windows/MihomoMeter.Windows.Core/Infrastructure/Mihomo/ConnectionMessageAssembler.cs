using System.Net.WebSockets;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

internal sealed class ConnectionMessageAssembler : IDisposable
{
    private const int MaximumMessageSize = 16 * 1024 * 1024;
    private readonly MemoryStream _message = new();
    private WebSocketMessageType? _messageType;
    private bool _completed;

    public bool Append(
        WebSocketMessageType messageType,
        ReadOnlySpan<byte> data,
        bool endOfMessage)
    {
        if (_completed
            || messageType is not (WebSocketMessageType.Text or WebSocketMessageType.Binary)
            || (_messageType is not null && _messageType != messageType))
        {
            throw new ConnectionStreamException(ConnectionStreamError.UnsupportedResponse);
        }

        _messageType = messageType;
        if (data.Length > MaximumMessageSize - _message.Length)
        {
            throw new ConnectionStreamException(ConnectionStreamError.MessageTooLarge);
        }

        _message.Write(data);
        _completed = endOfMessage;
        return _completed;
    }

    public MihomoConnectionsSnapshot Decode()
    {
        if (!_completed)
        {
            throw new ConnectionStreamException(ConnectionStreamError.UnsupportedResponse);
        }

        try
        {
            return MihomoJsonDecoder.Decode<MihomoConnectionsSnapshot>(_message.ToArray());
        }
        catch (MihomoResponseException exception)
        {
            throw new ConnectionStreamException(
                ConnectionStreamError.UnsupportedResponse,
                exception);
        }
    }

    public void Dispose()
    {
        _message.Dispose();
    }
}
