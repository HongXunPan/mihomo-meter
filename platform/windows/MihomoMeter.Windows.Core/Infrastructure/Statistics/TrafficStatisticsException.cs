namespace MihomoMeter.Windows.Core.Infrastructure.Statistics;

public sealed class TrafficStatisticsException : Exception
{
    public TrafficStatisticsException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
