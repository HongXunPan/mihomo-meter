using System.ComponentModel;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using MihomoMeter.Windows.Core.Application;
using MihomoMeter.Windows.Core.Domain;

namespace MihomoMeter.Windows.App.Presentation;

public sealed partial class ConnectionAnalyticsTrendChartView : UserControl
{
    private const double LeftInset = 70;
    private const double RightInset = 10;
    private const double TopInset = 10;
    private const double BottomInset = 30;
    private readonly ConnectionAnalyticsTrendWindowViewModel _viewModel;
    private int? _selectedIndex;

    internal ConnectionAnalyticsTrendChartView(
        ConnectionAnalyticsTrendWindowViewModel viewModel)
    {
        _viewModel = viewModel;
        InitializeComponent();
        _viewModel.PropertyChanged += ViewModel_PropertyChanged;
    }

    internal void Detach()
    {
        _viewModel.PropertyChanged -= ViewModel_PropertyChanged;
    }

    private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName == nameof(ConnectionAnalyticsTrendWindowViewModel.Trend))
        {
            _selectedIndex = DefaultSelectedIndex();
            Render();
        }
    }

    private void ChartCanvas_SizeChanged(object sender, SizeChangedEventArgs args)
    {
        Render();
    }

    private void ChartCanvas_PointerMoved(object sender, PointerRoutedEventArgs args)
    {
        var points = _viewModel.Trend?.Points;
        var width = ChartCanvas.ActualWidth - LeftInset - RightInset;
        if (points is null || points.Count == 0 || width <= 0)
        {
            return;
        }

        var x = args.GetCurrentPoint(ChartCanvas).Position.X - LeftInset;
        var index = Math.Clamp(
            (int)Math.Floor(x / width * points.Count),
            0,
            points.Count - 1);
        if (_selectedIndex != index)
        {
            _selectedIndex = index;
            Render();
        }
    }

    private void ChartCanvas_PointerExited(object sender, PointerRoutedEventArgs args)
    {
        _selectedIndex = DefaultSelectedIndex();
        Render();
    }

    private void Render()
    {
        ChartCanvas.Children.Clear();
        var trend = _viewModel.Trend;
        if (trend is null || ChartCanvas.ActualWidth <= LeftInset + RightInset)
        {
            EmptyText.Visibility = Visibility.Visible;
            PointDetailText.Text = string.Empty;
            return;
        }

        var width = ChartCanvas.ActualWidth - LeftInset - RightInset;
        var height = ChartCanvas.ActualHeight - TopInset - BottomInset;
        if (width <= 0 || height <= 0)
        {
            return;
        }

        var summary = TrafficStatisticsWorkspaceProjection.DailyRange(trend.Points
            .Select(point => new TrafficDailyTotal(point.LocalDay, point.Bytes))
            .ToArray());
        DrawAxes(summary.AxisTicks, width, height, trend.Points);
        DrawBars(summary, width, height);
        EmptyText.Visibility = trend.ActiveDayCount == 0
            ? Visibility.Visible
            : Visibility.Collapsed;
        UpdatePointDetail(trend.Points);
    }

    private void DrawAxes(
        TrafficDailyAxisTicks ticks,
        double width,
        double height,
        IReadOnlyList<ConnectionAnalyticsTrendPoint> points)
    {
        var brush = new SolidColorBrush(Colors.Gray);
        var values = new[]
        {
            ticks.Maximum,
            ticks.Half,
            0UL,
        };
        for (var index = 0; index < values.Length; index += 1)
        {
            var ratio = index / 2d;
            var y = TopInset + (height * ratio);
            AddLine(LeftInset, y, LeftInset + width, y, brush, 0.35);
            AddLabel(
                0,
                y - 9,
                TrafficDisplayFormatter.ByteCount(values[index]),
                LeftInset - 8);
        }

        var labelIndices = new[] { 0, 7, 14, 21, points.Count - 1 }
            .Distinct()
            .Where(index => index >= 0 && index < points.Count);
        foreach (var index in labelIndices)
        {
            var x = LeftInset + (width * (index + 0.5) / points.Count);
            AddLine(x, TopInset + height, x, TopInset + height + 4, brush, 0.65);
            AddLabel(
                x - 24,
                TopInset + height + 7,
                points[index].LocalDay[5..],
                48);
        }
    }

    private void DrawBars(
        TrafficDailyRangeSummary summary,
        double width,
        double height)
    {
        var step = width / Math.Max(summary.Points.Count, 1);
        var barWidth = Math.Max(Math.Min(step * 0.58, 14), 3);
        for (var index = 0; index < summary.Points.Count; index += 1)
        {
            var point = summary.Points[index];
            var downloadHeight = height * point.DownloadFraction;
            var uploadHeight = height * point.UploadFraction;
            var x = LeftInset + (step * index) + ((step - barWidth) / 2);
            var bottom = TopInset + height;
            AddRectangle(
                x,
                bottom - downloadHeight,
                barWidth,
                downloadHeight,
                Colors.DodgerBlue,
                0.9);
            AddRectangle(
                x,
                bottom - downloadHeight - uploadHeight,
                barWidth,
                uploadHeight,
                Colors.Orange,
                0.9);

            if (_selectedIndex == index)
            {
                var highlight = new Rectangle
                {
                    Width = Math.Max(step - 2, barWidth + 2),
                    Height = height,
                    Fill = new SolidColorBrush(Colors.DodgerBlue),
                    Opacity = 0.08,
                    RadiusX = 3,
                    RadiusY = 3,
                };
                Canvas.SetLeft(highlight, LeftInset + (step * index) + 1);
                Canvas.SetTop(highlight, TopInset);
                ChartCanvas.Children.Add(highlight);
            }
        }
    }

    private void UpdatePointDetail(IReadOnlyList<ConnectionAnalyticsTrendPoint> points)
    {
        if (_selectedIndex is not int index || index < 0 || index >= points.Count)
        {
            PointDetailText.Text = "将鼠标移到柱图上查看每日上下行归因。";
            return;
        }
        var point = points[index];
        PointDetailText.Text = $"{point.LocalDay} · "
            + $"合计 {TrafficDisplayFormatter.ByteCount(point.Bytes.Total)} · "
            + $"↓ {TrafficDisplayFormatter.ByteCount(point.Bytes.Download)} · "
            + $"↑ {TrafficDisplayFormatter.ByteCount(point.Bytes.Upload)}";
    }

    private int? DefaultSelectedIndex()
    {
        var trend = _viewModel.Trend;
        if (trend?.DefaultSelectedLocalDay is not string localDay)
        {
            return null;
        }
        for (var index = trend.Points.Count - 1; index >= 0; index -= 1)
        {
            if (string.Equals(trend.Points[index].LocalDay, localDay, StringComparison.Ordinal))
            {
                return index;
            }
        }
        return null;
    }

    private void AddLine(
        double x1,
        double y1,
        double x2,
        double y2,
        Brush brush,
        double opacity)
    {
        ChartCanvas.Children.Add(new Line
        {
            X1 = x1,
            Y1 = y1,
            X2 = x2,
            Y2 = y2,
            Stroke = brush,
            StrokeThickness = 1,
            Opacity = opacity,
        });
    }

    private void AddLabel(double left, double top, string text, double width)
    {
        var label = new TextBlock
        {
            Width = width,
            FontSize = 11,
            Foreground = new SolidColorBrush(Colors.Gray),
            Text = text,
            TextAlignment = TextAlignment.Center,
        };
        Canvas.SetLeft(label, left);
        Canvas.SetTop(label, top);
        ChartCanvas.Children.Add(label);
    }

    private void AddRectangle(
        double left,
        double top,
        double width,
        double height,
        global::Windows.UI.Color color,
        double opacity)
    {
        if (height <= 0)
        {
            return;
        }
        var rectangle = new Rectangle
        {
            Width = width,
            Height = Math.Max(height, 1),
            Fill = new SolidColorBrush(color),
            Opacity = opacity,
        };
        Canvas.SetLeft(rectangle, left);
        Canvas.SetTop(rectangle, top);
        ChartCanvas.Children.Add(rectangle);
    }
}
