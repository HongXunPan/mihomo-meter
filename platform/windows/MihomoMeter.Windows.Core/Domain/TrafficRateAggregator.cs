namespace MihomoMeter.Windows.Core.Domain;

public sealed class TrafficRateAggregator
{
    private readonly double _windowDuration;
    private readonly int _smoothingWindowCount;
    private readonly Queue<CategorizedTrafficRates> _recentRates = new();
    private double _accumulatedDuration;
    private TrafficBytes _accumulatedKernel = TrafficBytes.Zero;
    private CategorizedTrafficBytes _accumulatedBytes = CategorizedTrafficBytes.Zero;

    public TrafficRateAggregator(double windowDuration = 1, int smoothingWindowCount = 2)
    {
        if (!double.IsFinite(windowDuration) || windowDuration <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(windowDuration));
        }

        if (smoothingWindowCount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(smoothingWindowCount));
        }

        _windowDuration = windowDuration;
        _smoothingWindowCount = smoothingWindowCount;
    }

    public TrafficRateWindow? Consume(TrafficDeltaReport report, double elapsedSeconds)
    {
        if (!double.IsFinite(elapsedSeconds) || elapsedSeconds <= 0)
        {
            return null;
        }

        _accumulatedDuration += elapsedSeconds;
        _accumulatedKernel = TrafficBytes.Add(_accumulatedKernel, report.Kernel);
        _accumulatedBytes = new CategorizedTrafficBytes(
            TrafficBytes.Add(_accumulatedBytes.Proxy, report.Categories.Proxy),
            TrafficBytes.Add(_accumulatedBytes.Direct, report.Categories.Direct),
            TrafficBytes.Add(_accumulatedBytes.Reject, report.Categories.Reject),
            TrafficBytes.Add(_accumulatedBytes.Unknown, report.Categories.Unknown));

        if (_accumulatedDuration < _windowDuration)
        {
            return null;
        }

        var aggregate = new TrafficDeltaReport(_accumulatedKernel, _accumulatedBytes);
        var raw = RatesFrom(_accumulatedBytes, _accumulatedDuration);
        _recentRates.Enqueue(raw);
        while (_recentRates.Count > _smoothingWindowCount)
        {
            _recentRates.Dequeue();
        }

        var smoothed = Average(_recentRates);
        _accumulatedDuration = 0;
        _accumulatedKernel = TrafficBytes.Zero;
        _accumulatedBytes = CategorizedTrafficBytes.Zero;
        return new TrafficRateWindow(raw, smoothed, aggregate.Coverage);
    }

    public void Reset()
    {
        _accumulatedDuration = 0;
        _accumulatedKernel = TrafficBytes.Zero;
        _accumulatedBytes = CategorizedTrafficBytes.Zero;
        _recentRates.Clear();
    }

    private static CategorizedTrafficRates RatesFrom(
        CategorizedTrafficBytes bytes,
        double duration)
    {
        return new CategorizedTrafficRates(
            RateFrom(bytes.Proxy, duration),
            RateFrom(bytes.Direct, duration),
            RateFrom(bytes.Reject, duration),
            RateFrom(bytes.Unknown, duration));
    }

    private static TrafficRate RateFrom(TrafficBytes bytes, double duration)
    {
        return new TrafficRate(
            BytesPerSecond(bytes.Upload, duration),
            BytesPerSecond(bytes.Download, duration));
    }

    private static ulong BytesPerSecond(ulong bytes, double duration)
    {
        var value = bytes / duration;
        return value >= ulong.MaxValue ? ulong.MaxValue : (ulong)value;
    }

    private static CategorizedTrafficRates Average(IEnumerable<CategorizedTrafficRates> rates)
    {
        var items = rates.ToArray();
        return new CategorizedTrafficRates(
            Average(items.Select(item => item.Proxy)),
            Average(items.Select(item => item.Direct)),
            Average(items.Select(item => item.Reject)),
            Average(items.Select(item => item.Unknown)));
    }

    private static TrafficRate Average(IEnumerable<TrafficRate> rates)
    {
        var items = rates.ToArray();
        if (items.Length == 0)
        {
            return TrafficRate.Zero;
        }

        var total = items.Aggregate(
            TrafficBytes.Zero,
            (current, rate) => TrafficBytes.Add(
                current,
                new TrafficBytes(rate.UploadBytesPerSecond, rate.DownloadBytesPerSecond)));
        var count = (ulong)items.Length;
        return new TrafficRate(total.Upload / count, total.Download / count);
    }
}
