namespace MihomoMeter.Windows.Core.Domain;

public enum QuotaTrendWindow
{
    Day,
    Week,
    Month,
    Year,
}

public enum QuotaForecastUnavailableReason
{
    None,
    InsufficientSamples,
    InsufficientObservationSpan,
    UnconfirmedCycle,
    StaleData,
    NoRecentConsumption,
    Expired,
    Depleted,
}

public sealed record QuotaDepletionForecast(
    DateTimeOffset? EstimatedAt,
    QuotaForecastUnavailableReason UnavailableReason)
{
    public bool IsAvailable => EstimatedAt is not null;
}

public sealed record QuotaTrendPoint(
    Guid Id,
    Guid CycleId,
    DateTimeOffset Date,
    QuotaTraffic Traffic);

public sealed record QuotaTrendSegment(
    Guid CycleId,
    IReadOnlyList<QuotaTrendPoint> Points);

public sealed record QuotaRangeUsage(
    ulong UploadBytes,
    ulong DownloadBytes)
{
    public ulong TotalBytes => checked(UploadBytes + DownloadBytes);
}

public sealed record QuotaTrend(
    QuotaTrendWindow Window,
    IReadOnlyList<QuotaTrendSegment> Segments,
    QuotaRangeUsage RangeUsage);

public sealed record SubscriptionQuotaAnalysis(
    TrackedSubscription Subscription,
    SubscriptionQuotaSnapshot? LatestSnapshot,
    QuotaCycle? CurrentCycle,
    IReadOnlyList<QuotaEvent> RecentEvents,
    ProfileQuotaQueryState? QueryState,
    IReadOnlyDictionary<QuotaTrendWindow, QuotaTrend> Trends,
    QuotaDepletionForecast Forecast);

public sealed record QuotaLedgerSnapshot(
    IReadOnlyList<SubscriptionQuotaAnalysis> Subscriptions,
    DateTimeOffset UpdatedAt)
{
    public static QuotaLedgerSnapshot Empty(DateTimeOffset now) => new(
        Array.Empty<SubscriptionQuotaAnalysis>(),
        now);
}

public static class QuotaTrendEngine
{
    public const int MinimumPointCount = 2;
    public const int MaximumPointCount = 30;
    public const double PreferredPointSpacing = 40;
    public static readonly TimeSpan MinimumObservationSpan = TimeSpan.FromHours(6);

    public static QuotaTrend Calculate(
        IReadOnlyList<SubscriptionQuotaSnapshot> snapshots,
        QuotaTrendWindow window,
        DateTimeOffset now)
    {
        var start = StartDate(window, now);
        var ordered = snapshots
            .Where(snapshot => snapshot.EffectiveAt >= start && snapshot.EffectiveAt <= now)
            .OrderBy(snapshot => snapshot.EffectiveAt)
            .ThenBy(snapshot => snapshot.ObservedAt)
            .ToArray();
        var segments = BuildSegments(ordered);
        return new QuotaTrend(window, segments, RangeUsage(segments));
    }

    public static QuotaDepletionForecast Forecast(
        IReadOnlyList<SubscriptionQuotaSnapshot> snapshots,
        QuotaCycle? currentCycle,
        DateTimeOffset now,
        TimeSpan maximumDataAge)
    {
        var latest = snapshots
            .OrderBy(snapshot => snapshot.EffectiveAt)
            .ThenBy(snapshot => snapshot.ObservedAt)
            .LastOrDefault();
        if (latest is null)
        {
            return Unavailable(QuotaForecastUnavailableReason.InsufficientSamples);
        }

        if (latest.ExpireAt is DateTimeOffset expireAt && expireAt <= now)
        {
            return Unavailable(QuotaForecastUnavailableReason.Expired);
        }

        if (latest.Traffic.RemainingBytes == 0)
        {
            return Unavailable(QuotaForecastUnavailableReason.Depleted);
        }

        if (now - latest.EffectiveAt > maximumDataAge)
        {
            return Unavailable(QuotaForecastUnavailableReason.StaleData);
        }

        if (currentCycle is null
            || currentCycle.Id != latest.CycleId
            || !currentCycle.IsUserConfirmed)
        {
            return Unavailable(QuotaForecastUnavailableReason.UnconfirmedCycle);
        }

        var start = now - TimeSpan.FromDays(7);
        var points = snapshots
            .Where(snapshot => snapshot.CycleId == currentCycle.Id
                && snapshot.EffectiveAt >= start
                && snapshot.EffectiveAt <= now)
            .OrderBy(snapshot => snapshot.EffectiveAt)
            .ThenBy(snapshot => snapshot.ObservedAt)
            .ToArray();
        if (points.Length < 2)
        {
            return Unavailable(QuotaForecastUnavailableReason.InsufficientSamples);
        }

        var first = points[0];
        var last = points[^1];
        var elapsed = last.EffectiveAt - first.EffectiveAt;
        if (elapsed < MinimumObservationSpan)
        {
            return Unavailable(QuotaForecastUnavailableReason.InsufficientObservationSpan);
        }

        if (last.Traffic.UsedBytes <= first.Traffic.UsedBytes)
        {
            return Unavailable(QuotaForecastUnavailableReason.NoRecentConsumption);
        }

        var consumed = last.Traffic.UsedBytes - first.Traffic.UsedBytes;
        var bytesPerSecond = consumed / elapsed.TotalSeconds;
        if (bytesPerSecond <= 0 || !double.IsFinite(bytesPerSecond))
        {
            return Unavailable(QuotaForecastUnavailableReason.NoRecentConsumption);
        }

        var remainingSeconds = last.Traffic.RemainingBytes / bytesPerSecond;
        if (!double.IsFinite(remainingSeconds)
            || remainingSeconds > TimeSpan.MaxValue.TotalSeconds)
        {
            return Unavailable(QuotaForecastUnavailableReason.NoRecentConsumption);
        }

        try
        {
            return new QuotaDepletionForecast(
                last.EffectiveAt + TimeSpan.FromSeconds(remainingSeconds),
                QuotaForecastUnavailableReason.None);
        }
        catch (Exception exception) when (
            exception is ArgumentOutOfRangeException or OverflowException)
        {
            return Unavailable(QuotaForecastUnavailableReason.NoRecentConsumption);
        }
    }

    public static IReadOnlyList<QuotaTrendPoint> Sample(
        IReadOnlyList<QuotaTrendSegment> segments,
        int targetCount)
    {
        var all = segments.SelectMany(segment => segment.Points).OrderBy(point => point.Date).ToArray();
        var requestedCount = Math.Clamp(
            targetCount,
            MinimumPointCount,
            MaximumPointCount);
        if (all.Length <= requestedCount)
        {
            return all;
        }

        var selected = new Dictionary<Guid, QuotaTrendPoint>();
        foreach (var segment in segments)
        {
            if (segment.Points.Count == 0)
            {
                continue;
            }

            selected[segment.Points[0].Id] = segment.Points[0];
            selected[segment.Points[^1].Id] = segment.Points[^1];
        }

        var desiredCount = Math.Min(Math.Max(requestedCount, selected.Count), all.Length);
        if (selected.Count >= desiredCount)
        {
            return selected.Values.OrderBy(point => point.Date).ToArray();
        }

        var firstDate = all[0].Date;
        var duration = all[^1].Date - firstDate;
        var additionalCount = desiredCount - selected.Count;
        for (var index = 1; index <= additionalCount; index += 1)
        {
            var ratio = (double)index / (additionalCount + 1);
            var targetDate = firstDate + TimeSpan.FromTicks((long)(duration.Ticks * ratio));
            var closest = all
                .Where(point => !selected.ContainsKey(point.Id))
                .OrderBy(point => Math.Abs((point.Date - targetDate).Ticks))
                .ThenBy(point => point.Date)
                .ThenBy(point => point.Id)
                .FirstOrDefault();
            if (closest is not null)
            {
                selected[closest.Id] = closest;
            }
        }

        return selected.Values.OrderBy(point => point.Date).ToArray();
    }

    public static int TargetPointCount(double plotWidth)
    {
        var estimatedCount = double.IsFinite(plotWidth)
            ? (int)Math.Floor(Math.Max(plotWidth, 0) / PreferredPointSpacing)
            : MinimumPointCount;
        return Math.Clamp(estimatedCount, MinimumPointCount, MaximumPointCount);
    }

    public static DateTimeOffset StartDate(QuotaTrendWindow window, DateTimeOffset now)
    {
        return window switch
        {
            QuotaTrendWindow.Day => now - TimeSpan.FromHours(24),
            QuotaTrendWindow.Week => now - TimeSpan.FromDays(7),
            QuotaTrendWindow.Month => now - TimeSpan.FromDays(30),
            QuotaTrendWindow.Year => now.AddMonths(-12),
            _ => throw new ArgumentOutOfRangeException(nameof(window)),
        };
    }

    private static IReadOnlyList<QuotaTrendSegment> BuildSegments(
        IReadOnlyList<SubscriptionQuotaSnapshot> snapshots)
    {
        var result = new List<QuotaTrendSegment>();
        var points = new List<QuotaTrendPoint>();
        Guid? cycleId = null;
        SubscriptionQuotaSnapshot? previous = null;
        foreach (var snapshot in snapshots)
        {
            var startsNewSegment = cycleId != snapshot.CycleId
                || (previous is not null
                    && (snapshot.Traffic.UploadBytes < previous.Traffic.UploadBytes
                        || snapshot.Traffic.DownloadBytes < previous.Traffic.DownloadBytes));
            if (startsNewSegment && points.Count > 0 && cycleId is Guid completedCycleId)
            {
                result.Add(new QuotaTrendSegment(completedCycleId, points.ToArray()));
                points.Clear();
            }

            cycleId = snapshot.CycleId;
            points.Add(new QuotaTrendPoint(
                snapshot.Id,
                snapshot.CycleId,
                snapshot.EffectiveAt,
                snapshot.Traffic));
            previous = snapshot;
        }

        if (points.Count > 0 && cycleId is Guid finalCycleId)
        {
            result.Add(new QuotaTrendSegment(finalCycleId, points.ToArray()));
        }

        return result;
    }

    private static QuotaRangeUsage RangeUsage(IReadOnlyList<QuotaTrendSegment> segments)
    {
        ulong upload = 0;
        ulong download = 0;
        foreach (var segment in segments)
        {
            for (var index = 1; index < segment.Points.Count; index += 1)
            {
                var previous = segment.Points[index - 1].Traffic;
                var current = segment.Points[index].Traffic;
                upload = checked(upload + current.UploadBytes - previous.UploadBytes);
                download = checked(download + current.DownloadBytes - previous.DownloadBytes);
            }
        }

        return new QuotaRangeUsage(upload, download);
    }

    private static QuotaDepletionForecast Unavailable(QuotaForecastUnavailableReason reason)
    {
        return new QuotaDepletionForecast(null, reason);
    }
}
