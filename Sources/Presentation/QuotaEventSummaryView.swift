import SwiftUI

struct QuotaEventSummaryView: View {
  let analysis: SubscriptionQuotaAnalysis
  let confirmCurrentCycle: () async -> Void

  var body: some View {
    if !analysis.recentEvents.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        if analysis.pendingCycleConfirmation != nil {
          QuotaCycleConfirmationView(confirmCurrentCycle: confirmCurrentCycle)
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

struct QuotaCycleConfirmationView: View {
  let confirmCurrentCycle: () async -> Void

  var body: some View {
    HStack(spacing: 8) {
      Label("用量下降可能代表套餐重置，请确认新周期。", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(MihomoColorToken.statusWarning)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 8)

      Button("确认新周期") {
        Task {
          await confirmCurrentCycle()
        }
      }
      .controlSize(.small)
    }
    .font(.caption)
  }
}
