import SwiftUI

struct QuotaEventSummaryView: View {
  let analysis: SubscriptionQuotaAnalysis
  let subscriptionName: String
  let confirmCurrentCycle: @MainActor (UUID) async -> String?

  var body: some View {
    if analysis.pendingCycleConfirmation != nil || !analysis.recentEvents.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        if let cycle = analysis.pendingCycleConfirmation {
          QuotaCycleConfirmationView(
            cycle: cycle,
            subscriptionName: subscriptionName,
            confirmCurrentCycle: confirmCurrentCycle
          )
          .id(cycle.id)
        }

        ForEach(analysis.recentEvents.prefix(3)) { event in
          HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: symbolName(for: event.kind))
              .foregroundStyle(
                event.kind.requiresUserConfirmation && !event.isUserConfirmed
                  ? MihomoColorToken.statusWarning : MihomoColorToken.statusNeutral
              )
            Text(SubscriptionQuotaFormatter.quotaEvent(event))
            Spacer()
            Text(SubscriptionQuotaFormatter.updatedAt(event.occurredAt))
              .foregroundStyle(.secondary)
          }
          .font(.caption2)
        }
      }
      .padding(10)
      .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  private func symbolName(for kind: QuotaEventKind) -> String {
    switch kind {
    case .usageReset:
      "arrow.counterclockwise"
    case .totalIncreased:
      "plus.circle"
    case .totalDecreased:
      "minus.circle"
    case .expirationChanged:
      "calendar.badge.clock"
    }
  }
}
