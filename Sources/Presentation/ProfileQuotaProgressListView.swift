import SwiftUI

struct ProfileQuotaProgressListView: View {
  @ObservedObject var controller: ProfileQuotaTrackingController

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      VStack(spacing: 8) {
        ForEach(controller.snapshot.profiles) { item in
          SubscriptionQuotaProgressRow(
            title: item.subscription.name,
            isCurrent: item.isCurrent,
            quota: item.latestQuota,
            status: ProfileQuotaStatusPresentation(item: item, relativeTo: context.date),
            forecast: item.trends.depletionForecast
          )
        }
      }
    }
  }
}

struct SubscriptionQuotaProgressRow: View {
  let title: String
  let isCurrent: Bool
  let quota: SubscriptionQuotaSnapshot?
  let status: ProfileQuotaStatusPresentation?
  let forecast: QuotaDepletionForecast?

  var body: some View {
    ZStack(alignment: .leading) {
      SubscriptionQuotaProgressTrack(
        fraction: quota == nil ? nil : remainingFraction,
        isOverQuota: quota?.traffic.isOverQuota == true,
        style: .summary
      )

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .help(title)

          if isCurrent {
            Text("当前")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(MihomoColorToken.brandPrimary)
          }

          Spacer(minLength: 8)

          Text(quotaSummary)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)

          if let status {
            Image(systemName: status.symbolName)
              .foregroundStyle(status.tone.color)
              .help(status.message)
          }
        }

        HStack(spacing: 8) {
          Text(statusSummary)
            .lineLimit(1)
            .help(statusSummaryHelp)

          Spacer(minLength: 8)

          Text(progressSummary)
            .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .frame(height: 56)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title)剩余流量比例")
    .accessibilityValue("\(progressAccessibilityValue)，\(statusSummary)")
  }

  private var quotaSummary: String {
    guard let quota else {
      return status?.title ?? "等待数据"
    }
    return
      "\(SubscriptionQuotaFormatter.bytes(quota.traffic.remainingBytes)) / "
      + SubscriptionQuotaFormatter.bytes(quota.traffic.totalBytes)
  }

  private var remainingFraction: Double {
    guard let quota else {
      return 0
    }
    return min(
      max(
        Double(quota.traffic.remainingBytes) / Double(quota.traffic.totalBytes),
        0
      ),
      1
    )
  }

  private var progressAccessibilityValue: String {
    guard quota != nil else {
      return "等待有效配额"
    }
    return remainingFraction.formatted(.percent.precision(.fractionLength(0)))
  }

  private var statusSummary: String {
    guard quota != nil else {
      return status?.title ?? "等待有效配额"
    }
    if let status, status.overridesForecast {
      return status.title
    }
    if let forecast {
      return SubscriptionQuotaFormatter.depletion(forecast)
    }
    if let status {
      return status.title
    }
    return "暂无法预测"
  }

  private var statusSummaryHelp: String {
    if let status, status.overridesForecast {
      return status.message
    }
    return "按当前已确认周期内最多近 7 天的有效用量估算；不等于本机 Proxy 流量。"
  }

  private var progressSummary: String {
    guard quota != nil else {
      return "暂无比例"
    }
    return "剩余 \(remainingFraction.formatted(.percent.precision(.fractionLength(0))))"
  }
}
