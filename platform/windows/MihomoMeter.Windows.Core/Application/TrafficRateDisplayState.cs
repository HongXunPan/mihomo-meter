using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.Core.Application;

internal sealed class TrafficRateDisplayState
{
    public CategorizedTrafficRates? Rates { get; private set; }

    public double? Coverage { get; private set; }

    public void Apply(TrafficMeasurementResult result)
    {
        if (result.CountersReset)
        {
            Clear();
            return;
        }

        if (result.RateWindow is null)
        {
            return;
        }

        Rates = result.RateWindow.Smoothed;
        Coverage = result.RateWindow.Coverage;
    }

    public void Clear()
    {
        Rates = null;
        Coverage = null;
    }
}
