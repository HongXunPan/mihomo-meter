import SwiftUI

struct ProfileQuotaCardView: View {
  @ObservedObject var controller: ProfileQuotaTrackingController
  let item: ProfileQuotaTrackingItem
  let window: QuotaTrendWindow
  let onExpand: () -> Void

  private var status: ProfileQuotaStatusPresentation {
    ProfileQuotaStatusPresentation(item: item)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header

      Divider()

      Label(status.message, systemImage: status.symbolName)
        .font(.caption)
        .foregroundStyle(status.tone.color)
        .fixedSize(horizontal: false, vertical: true)

      if let quota = item.latestQuota {
        SubscriptionQuotaMetricsView(
          quota: quota,
          trend: item.trends.trend(for: window)
        )

        QuotaEventSummaryView(analysis: item.analysis) {
          await controller.confirmCurrentCycle(subscriptionID: item.id)
        }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "chart.line.downtrend.xyaxis")
            .font(.system(size: 26))
            .foregroundStyle(.secondary)
          Text("等待第一条有效配额快照")
            .font(.subheadline.weight(.medium))
          Text("查询成功后将在这里显示剩余流量与所选时间窗口的走势。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 235, alignment: .center)
      }
    }
    .padding(16)
    .background(
      Color(nsColor: .controlBackgroundColor),
      in: RoundedRectangle(cornerRadius: 12)
    )
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(item.subscription.name)
            .font(.headline)
            .lineLimit(1)
          if item.isCurrent {
            Text("当前")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(MihomoColorToken.statusInfo)
          }
        }
        Text(
          "\(SubscriptionQuotaFormatter.refreshInterval(item.subscription.refreshIntervalMinutes)) · \(status.title)"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
      }

      Spacer()

      Button(action: onExpand) {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
      }
      .buttonStyle(.borderless)
      .disabled(item.latestQuota == nil)
      .help("放大查看累计用量走势")

      Button {
        Task {
          await controller.refresh(subscriptionID: item.id)
        }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .disabled(!item.canRefresh)
      .help(item.canRefresh ? "立即查询这个 Profile" : status.message)
    }
  }
}
