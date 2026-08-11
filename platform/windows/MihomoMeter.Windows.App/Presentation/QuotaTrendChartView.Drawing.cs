using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class QuotaTrendChartView
{
    private void DrawStackedArea(
        IReadOnlyList<RenderedQuotaPoint> points,
        ulong minimum,
        ulong maximum,
        ulong spread,
        double chartHeight)
    {
        if (points.Count < 2)
        {
            return;
        }

        var baseline = points[0].Point.Traffic;
        var baselineY = YPosition(baseline.UsedBytes, minimum, maximum, spread, chartHeight);
        var downloadBoundary = points.Select(point => new Point(
            point.Position.X,
            YPosition(
                baseline.UsedBytes
                    + point.Point.Traffic.DownloadBytes
                    - baseline.DownloadBytes,
                minimum,
                maximum,
                spread,
                chartHeight))).ToArray();
        var downloadArea = new Polygon
        {
            Fill = ResourceBrush("MihomoTrafficDownloadAreaBrush"),
        };
        foreach (var point in downloadBoundary)
        {
            downloadArea.Points.Add(point);
        }

        downloadArea.Points.Add(new Point(points[^1].Position.X, baselineY));
        downloadArea.Points.Add(new Point(points[0].Position.X, baselineY));
        ChartCanvas.Children.Add(downloadArea);

        var uploadArea = new Polygon
        {
            Fill = ResourceBrush("MihomoTrafficUploadAreaBrush"),
        };
        foreach (var point in points)
        {
            uploadArea.Points.Add(point.Position);
        }

        foreach (var point in downloadBoundary.Reverse())
        {
            uploadArea.Points.Add(point);
        }

        ChartCanvas.Children.Add(uploadArea);
    }

    private static double YPosition(
        ulong value,
        ulong minimum,
        ulong maximum,
        ulong spread,
        double chartHeight)
    {
        var ratio = maximum == minimum
            ? 0.5
            : (double)(value - minimum) / spread;
        return TopInset + (chartHeight * (1 - ratio));
    }

    private void DrawAxes(
        DateTimeOffset start,
        DateTimeOffset end,
        ulong minimum,
        ulong maximum,
        double chartWidth,
        double chartHeight)
    {
        var brush = ResourceBrush("TextFillColorSecondaryBrush");
        AddLine(LeftInset, TopInset, LeftInset, TopInset + chartHeight, brush);
        AddLine(
            LeftInset,
            TopInset + chartHeight,
            LeftInset + chartWidth,
            TopInset + chartHeight,
            brush);
        for (var index = 0; index < 3; index += 1)
        {
            var ratio = index / 2d;
            var y = TopInset + (chartHeight * ratio);
            var value = index switch
            {
                0 => maximum,
                2 => minimum,
                _ => minimum + ((maximum - minimum) / 2),
            };
            AddLabel(0, y - 10, SubscriptionQuotaFormatter.Bytes(value), 60);

            var date = start + TimeSpan.FromTicks((long)((end - start).Ticks * ratio));
            AddLabel(
                LeftInset + (chartWidth * ratio) - 34,
                TopInset + chartHeight + 5,
                FormatAxisDate(date),
                68);
        }
    }

    private void AddLine(
        double x1,
        double y1,
        double x2,
        double y2,
        Brush brush)
    {
        ChartCanvas.Children.Add(new Line
        {
            X1 = x1,
            Y1 = y1,
            X2 = x2,
            Y2 = y2,
            Stroke = brush,
            StrokeThickness = 1,
            Opacity = 0.55,
        });
    }

    private void AddLabel(double left, double top, string text, double width)
    {
        var label = new TextBlock
        {
            Width = width,
            FontSize = 11,
            Foreground = ResourceBrush("TextFillColorSecondaryBrush"),
            Text = text,
            TextAlignment = TextAlignment.Center,
        };
        Canvas.SetLeft(label, left);
        Canvas.SetTop(label, top);
        ChartCanvas.Children.Add(label);
    }

    private static string FormatAxisDate(DateTimeOffset date)
    {
        return date.ToLocalTime().ToString("MM-dd");
    }
}
