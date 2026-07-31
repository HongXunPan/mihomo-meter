import SwiftUI

struct ConnectionAnalyticsTrendView: View {
  @ObservedObject var model: ConnectionAnalyticsTrendWindowModel
  @State private var selectedLocalDay = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(.horizontal, 24)
        .padding(.vertical, 18)

      Divider()

      content
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 680, minHeight: 460)
    .onChange(of: model.state) { _, state in
      guard case .loaded(let trend) = state else {
        return
      }
      selectedLocalDay = trend.defaultSelectedLocalDay ?? ""
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(targetTitle)
          .font(.title2.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.middle)
          .help(model.target?.name ?? "")
        if let description = model.target?.inheritedFilterDescription {
          Text("交叉筛选 · \(description)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else {
          Text("最近 30 天历史归因趋势")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Button {
        model.reload()
      } label: {
        Label("刷新", systemImage: "arrow.clockwise")
      }
      .disabled(model.target == nil || model.state == .loading)
    }
  }

  @ViewBuilder
  private var content: some View {
    switch model.state {
    case .idle:
      ContentUnavailableView("尚未选择趋势对象", systemImage: "chart.bar.xaxis")
    case .loading:
      VStack(spacing: 12) {
        ProgressView()
        Text("正在刷新待写数据并查询趋势…")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      ContentUnavailableView {
        Label("趋势暂不可用", systemImage: "exclamationmark.triangle")
      } description: {
        Text(message)
      } actions: {
        Button("重试") {
          model.reload()
        }
      }
    case .loaded(let trend):
      if trend.totalBytes.total == 0 {
        VStack(spacing: 12) {
          ContentUnavailableView(
            "暂无归因数据",
            systemImage: "chart.bar.xaxis",
            description: Text("所选对象和交叉筛选在最近 30 天没有已记录流量。")
          )
          Button("刷新") {
            model.reload()
          }
        }
      } else {
        ScrollView {
          trendContent(trend)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private func trendContent(_ trend: ConnectionAnalyticsTrend) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 12) {
        summaryMetric("30 天合计", value: TrafficStatisticsFormatter.bytes(trend.totalBytes.total))
        summaryMetric(
          "活跃日均",
          value: TrafficStatisticsFormatter.bytes(trend.activeDailyAverageBytes)
        )
        summaryMetric(
          "峰值日",
          value: trend.peakPoint.map {
            "\($0.localDay) · \(TrafficStatisticsFormatter.bytes($0.bytes.total))"
          } ?? "—"
        )
        summaryMetric("有流量天数", value: "\(trend.activeDayCount) 天")
      }

      ConnectionAnalyticsTrendChart(
        points: trend.points,
        selectedLocalDay: $selectedLocalDay
      )

      Label(
        "今日数据尚未完成；无记录日期不代表没有 Proxy 流量，历史归因关闭期间不会记录。",
        systemImage: "info.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private func summaryMetric(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.callout.weight(.semibold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
  }

  private var targetTitle: String {
    guard let target = model.target else {
      return "归因趋势"
    }
    return "\(target.dimension.title)趋势 · \(target.name)"
  }
}
