import SwiftUI

struct RuntimeQuotaCardView: View {
  @ObservedObject var controller: RuntimeQuotaTrackingController
  let subscription: TrackedSubscription
  let quota: SubscriptionQuotaSnapshot
  let window: QuotaTrendWindow
  let onExpand: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(subscription.name)
            .font(.headline)
          Text("当前运行订阅 · 未绑定 Profile UID")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button(action: onExpand) {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
        .buttonStyle(.borderless)
        .help("放大查看累计用量走势")

        Image(systemName: "dot.radiowaves.left.and.right")
          .foregroundStyle(MihomoColorToken.brandPrimary)
      }

      Divider()

      SubscriptionQuotaMetricsView(
        quota: quota,
        trend: controller.snapshot.trends.trend(for: window),
        depletionForecast: controller.snapshot.trends.depletionForecast
      )

      QuotaEventSummaryView(analysis: controller.snapshot.analysis) {
        await controller.confirmCurrentCycle()
      }
    }
    .padding(16)
    .background(
      Color(nsColor: .controlBackgroundColor),
      in: RoundedRectangle(cornerRadius: 12)
    )
  }
}
