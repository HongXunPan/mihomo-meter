using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
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
    private Line? _selectionLine;
    private int? _selectedIndex;

    public QuotaTrendChartView()
    {
        InitializeComponent();
        Loaded += (_, _) => Render();
        ActualThemeChanged += (_, _) => Render();
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
        var view = (QuotaTrendChartView)dependencyObject;
        view._selectedIndex = null;
        view.Render();
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

        ShowPoint(IndexOfRenderedPoint(point));
    }

    private void ChartCanvas_PointerExited(object sender, PointerRoutedEventArgs args)
    {
        ShowLatestPoint();
    }

    private void ChartCanvas_KeyDown(object sender, KeyRoutedEventArgs args)
    {
        if (_renderedPoints.Count == 0)
        {
            return;
        }

        var current = _selectedIndex ?? (_renderedPoints.Count - 1);
        var next = args.Key switch
        {
            global::Windows.System.VirtualKey.Left => Math.Max(current - 1, 0),
            global::Windows.System.VirtualKey.Right => Math.Min(
                current + 1,
                _renderedPoints.Count - 1),
            global::Windows.System.VirtualKey.Home => 0,
            global::Windows.System.VirtualKey.End => _renderedPoints.Count - 1,
            _ => current,
        };
        if (next == current
            && args.Key is not (global::Windows.System.VirtualKey.Home
                or global::Windows.System.VirtualKey.End))
        {
            return;
        }

        ShowPoint(next);
        args.Handled = true;
    }

    private void Render()
    {
        ChartCanvas.Children.Clear();
        _renderedPoints = [];
        _selectionLine = null;
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

        var chartWidth = ChartCanvas.ActualWidth - LeftInset - RightInset;
        var chartHeight = ChartCanvas.ActualHeight - TopInset - BottomInset;
        var points = QuotaTrendEngine.Sample(
            model.Trend.Segments,
            QuotaTrendEngine.TargetPointCount(chartWidth));
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
        DrawAxes(start, end, minimum, maximum, chartWidth, chartHeight);

        var rendered = new List<RenderedQuotaPoint>();
        var sampledIds = points.Select(point => point.Id).ToHashSet();
        var latestPointId = points[^1].Id;
        foreach (var segment in model.Trend.Segments)
        {
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
                Stroke = ResourceBrush("TextFillColorPrimaryBrush"),
                StrokeThickness = 2,
            };
            foreach (var point in segmentRendered)
            {
                polyline.Points.Add(point.Position);
            }

            ChartCanvas.Children.Add(polyline);
            rendered.AddRange(segmentRendered);
            for (var index = 0; index < segmentRendered.Count; index += 1)
            {
                var point = segmentRendered[index];
                if (index != 0 && point.Point.Id != latestPointId)
                {
                    continue;
                }
                var marker = new Ellipse
                {
                    Width = 8,
                    Height = 8,
                    Fill = ResourceBrush("TextFillColorPrimaryBrush"),
                };
                Canvas.SetLeft(marker, point.Position.X - 4);
                Canvas.SetTop(marker, point.Position.Y - 4);
                ChartCanvas.Children.Add(marker);
                if (index == 0 && point.Point.Id != latestPointId)
                {
                    var hollowCenter = new Ellipse
                    {
                        Width = 4,
                        Height = 4,
                        Fill = ResourceBrush("ApplicationPageBackgroundThemeBrush"),
                    };
                    Canvas.SetLeft(hollowCenter, point.Position.X - 2);
                    Canvas.SetTop(hollowCenter, point.Position.Y - 2);
                    ChartCanvas.Children.Add(hollowCenter);
                }
            }
        }

        _renderedPoints = rendered.OrderBy(item => item.Position.X).ToArray();
        ShowPoint(Math.Clamp(
            _selectedIndex ?? (_renderedPoints.Count - 1),
            0,
            _renderedPoints.Count - 1));
    }

    private void ShowLatestPoint()
    {
        ShowPoint(_renderedPoints.Count - 1);
    }

    private void ShowPoint(int index)
    {
        if (index < 0 || index >= _renderedPoints.Count)
        {
            _selectedIndex = null;
            PointDetailText.Text = string.Empty;
            return;
        }

        _selectedIndex = index;
        var point = _renderedPoints[index];
        PointDetailText.Text = index == _renderedPoints.Count - 1
            ? $"最新：{FormatDate(point.Point.Date)} · "
                + $"累计 {SubscriptionQuotaFormatter.Bytes(point.Point.Traffic.UsedBytes)}"
            : PointerDetail(point);
        AutomationProperties.SetName(
            ChartCanvas,
            $"订阅累计趋势图，{PointDetailText.Text}");
        if (_selectionLine is not null)
        {
            ChartCanvas.Children.Remove(_selectionLine);
        }
        _selectionLine = new Line
        {
            X1 = point.Position.X,
            X2 = point.Position.X,
            Y1 = TopInset,
            Y2 = ChartCanvas.ActualHeight - BottomInset,
            Stroke = ResourceBrush("TextFillColorSecondaryBrush"),
            StrokeDashArray = new DoubleCollection { 3, 3 },
            StrokeThickness = 1,
            Opacity = 0.65,
        };
        ChartCanvas.Children.Add(_selectionLine);
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

    private int IndexOfRenderedPoint(RenderedQuotaPoint point)
    {
        for (var index = 0; index < _renderedPoints.Count; index += 1)
        {
            if (_renderedPoints[index] == point)
            {
                return index;
            }
        }
        return -1;
    }

    private sealed record RenderedQuotaPoint(
        QuotaTrendPoint Point,
        QuotaTrendPoint? Previous,
        Point Position);

    private static Brush ResourceBrush(string key)
    {
        return (Brush)Application.Current.Resources[key];
    }
}
