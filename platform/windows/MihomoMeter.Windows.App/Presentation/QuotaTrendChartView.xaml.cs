using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using MihomoMeter.Windows.Core.Domain;
using Windows.Foundation;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class QuotaTrendChartView : UserControl
{
    private const double LeftInset = 66;
    private const double RightInset = 12;
    private const double TopInset = 12;
    private const double BottomInset = 30;
    private IReadOnlyList<RenderedQuotaPoint> _renderedPoints = [];

    public QuotaTrendChartView()
    {
        InitializeComponent();
        Loaded += (_, _) => Render();
    }

    public static DependencyProperty ModelProperty { get; } = DependencyProperty.Register(
        nameof(Model),
        typeof(QuotaTrendChartModel),
        typeof(QuotaTrendChartView),
        new PropertyMetadata(null, ModelChanged));

    public QuotaTrendChartModel? Model
    {
        get => (QuotaTrendChartModel?)GetValue(ModelProperty);
        set => SetValue(ModelProperty, value);
    }

    private static void ModelChanged(
        DependencyObject dependencyObject,
        DependencyPropertyChangedEventArgs args)
    {
        ((QuotaTrendChartView)dependencyObject).Render();
    }

    private void ChartCanvas_SizeChanged(object sender, SizeChangedEventArgs args)
    {
        Render();
    }

    private void ChartCanvas_PointerMoved(object sender, PointerRoutedEventArgs args)
    {
        if (_renderedPoints.Count == 0)
        {
            return;
        }

        var position = args.GetCurrentPoint(ChartCanvas).Position;
        var point = _renderedPoints.MinBy(item => Math.Abs(item.Position.X - position.X));
        if (point is null)
        {
            return;
        }

        PointDetailText.Text = PointerDetail(point);
    }

    private void ChartCanvas_PointerExited(object sender, PointerRoutedEventArgs args)
    {
        ShowLatestPoint();
    }

    private void Render()
    {
        ChartCanvas.Children.Clear();
        _renderedPoints = [];
        var model = Model;
        RangeUsageText.Text = model?.RangeUsageText ?? string.Empty;
        EmptyText.Text = model?.EmptyText ?? string.Empty;
        if (model is null
            || ChartCanvas.ActualWidth <= LeftInset + RightInset
            || ChartCanvas.ActualHeight <= TopInset + BottomInset)
        {
            EmptyText.Visibility = Visibility.Visible;
            PointDetailText.Text = string.Empty;
            return;
        }

        var points = QuotaTrendEngine.Sample(model.Trend.Segments, 120);
        if (points.Count == 0)
        {
            EmptyText.Visibility = Visibility.Visible;
            PointDetailText.Text = string.Empty;
            return;
        }

        EmptyText.Visibility = Visibility.Collapsed;
        var start = points[0].Date;
        var end = points[^1].Date;
        var maximum = points.Max(point => point.Traffic.UsedBytes);
        var minimum = points.Min(point => point.Traffic.UsedBytes);
        var spread = maximum > minimum ? maximum - minimum : Math.Max(maximum, 1UL);
        var chartWidth = ChartCanvas.ActualWidth - LeftInset - RightInset;
        var chartHeight = ChartCanvas.ActualHeight - TopInset - BottomInset;
        DrawAxes(start, end, minimum, maximum, chartWidth, chartHeight);

        var rendered = new List<RenderedQuotaPoint>();
        foreach (var segment in model.Trend.Segments)
        {
            var sampledIds = points.Select(point => point.Id).ToHashSet();
            var segmentPoints = segment.Points
                .Where(point => sampledIds.Contains(point.Id))
                .OrderBy(point => point.Date)
                .ToArray();
            if (segmentPoints.Length == 0)
            {
                continue;
            }

            var segmentRendered = new List<RenderedQuotaPoint>();
            QuotaTrendPoint? previous = null;
            foreach (var point in segmentPoints)
            {
                var xRatio = end == start
                    ? 0.5
                    : Math.Clamp(
                        (point.Date - start).TotalSeconds / (end - start).TotalSeconds,
                        0,
                        1);
                var yRatio = maximum == minimum
                    ? 0.5
                    : (double)(point.Traffic.UsedBytes - minimum) / spread;
                var position = new Point(
                    LeftInset + (chartWidth * xRatio),
                    TopInset + (chartHeight * (1 - yRatio)));
                segmentRendered.Add(new RenderedQuotaPoint(point, previous, position));
                previous = point;
            }

            DrawStackedArea(segmentRendered, minimum, maximum, spread, chartHeight);
            var polyline = new Polyline
            {
                Stroke = new SolidColorBrush(Colors.DodgerBlue),
                StrokeThickness = 2,
            };
            foreach (var point in segmentRendered)
            {
                polyline.Points.Add(point.Position);
            }

            ChartCanvas.Children.Add(polyline);
            rendered.AddRange(segmentRendered);
            foreach (var point in segmentRendered)
            {
                var marker = new Ellipse
                {
                    Width = 6,
                    Height = 6,
                    Fill = new SolidColorBrush(Colors.DodgerBlue),
                };
                Canvas.SetLeft(marker, point.Position.X - 3);
                Canvas.SetTop(marker, point.Position.Y - 3);
                ChartCanvas.Children.Add(marker);
            }
        }

        _renderedPoints = rendered.OrderBy(item => item.Position.X).ToArray();
        ShowLatestPoint();
    }

    private void ShowLatestPoint()
    {
        var latest = _renderedPoints.LastOrDefault();
        PointDetailText.Text = latest is null
            ? string.Empty
            : $"最新：{FormatDate(latest.Point.Date)} · "
                + $"累计 {SubscriptionQuotaFormatter.Bytes(latest.Point.Traffic.UsedBytes)}";
    }

    private static string PointerDetail(RenderedQuotaPoint point)
    {
        if (point.Previous is not QuotaTrendPoint previous)
        {
            return $"{FormatDate(point.Point.Date)} · "
                + $"累计 {SubscriptionQuotaFormatter.Bytes(point.Point.Traffic.UsedBytes)}"
                + " · 无可比较增量";
        }

        var upload = point.Point.Traffic.UploadBytes - previous.Traffic.UploadBytes;
        var download = point.Point.Traffic.DownloadBytes - previous.Traffic.DownloadBytes;
        return $"{FormatDate(previous.Date)} → {FormatDate(point.Point.Date)} · "
            + $"新增 {SubscriptionQuotaFormatter.Bytes(upload + download)}"
            + $"（下载 {SubscriptionQuotaFormatter.Bytes(download)}"
            + $" / 上传 {SubscriptionQuotaFormatter.Bytes(upload)}）"
            + $" · 间隔 {FormatInterval(point.Point.Date - previous.Date)}";
    }

    private static string FormatInterval(TimeSpan interval)
    {
        if (interval < TimeSpan.FromMinutes(1))
        {
            return $"{Math.Max((int)interval.TotalSeconds, 0)} 秒";
        }

        if (interval < TimeSpan.FromHours(1))
        {
            return $"{(int)interval.TotalMinutes} 分钟";
        }

        if (interval < TimeSpan.FromDays(1))
        {
            return $"{interval.TotalHours:F1} 小时";
        }

        return $"{interval.TotalDays:F1} 天";
    }

    private static string FormatDate(DateTimeOffset date)
    {
        return date.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
    }

    private sealed record RenderedQuotaPoint(
        QuotaTrendPoint Point,
        QuotaTrendPoint? Previous,
        Point Position);
}
