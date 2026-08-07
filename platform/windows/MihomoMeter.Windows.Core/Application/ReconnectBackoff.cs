namespace MihomoMeter.Windows.Core.Application;

public sealed class ReconnectBackoff
{
    private const int MaximumDelaySeconds = 30;
    private int _nextValue = 1;

    public int NextDelaySeconds()
    {
        var current = _nextValue;
        _nextValue = Math.Min(_nextValue * 2, MaximumDelaySeconds);
        return current;
    }

    public void Reset()
    {
        _nextValue = 1;
    }
}
