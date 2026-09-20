import SwiftUI

struct StatusMenuQuotaStatusView: View {
  let target: StatusMenuQuotaTrendTarget
  let status: ProfileQuotaStatusPresentation?
  let referenceDate: Date
  let confirmCurrentCycle: @MainActor (UUID) async -> String?

  var body: some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: 32, alignment: .leading)
  }

  @ViewBuilder
  private var content: some View {
    if let cycle = target.pendingCycleConfirmation {
      QuotaCycleConfirmationView(
        cycle: cycle,
        subscriptionName: target.title,
        isCompact: true,
        confirmCurrentCycle: confirmCurrentCycle
      )
      .id(cycle.id)
    } else if let status, status.overridesForecast {
      Label(status.title, systemImage: status.symbolName)
        .font(.caption)
        .foregroundStyle(status.tone.color)
        .lineLimit(2)
        .help(status.message)
    } else {
      Text(
        SubscriptionQuotaFormatter.depletion(
          target.trends.depletionForecast,
          relativeTo: referenceDate
        )
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(2)
      .help("按当前已确认周期内最多近 7 天的有效用量估算；不随图表范围切换。")
    }
  }
}
