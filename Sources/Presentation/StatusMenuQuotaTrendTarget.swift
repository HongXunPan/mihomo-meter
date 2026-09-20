import Foundation

struct StatusMenuQuotaTrendTarget: Identifiable {
  let id: UUID
  let title: String
  let isCurrent: Bool
  let analysis: SubscriptionQuotaAnalysis

  var quota: SubscriptionQuotaSnapshot? {
    analysis.latestQuota
  }

  var trends: RuntimeQuotaTrends {
    analysis.trends
  }

  var pendingCycleConfirmation: QuotaCycle? {
    analysis.pendingCycleConfirmation
  }

  @MainActor
  static func available(
    controller: RuntimeQuotaTrackingController,
    profileQuotaController: ProfileQuotaTrackingController
  ) -> [StatusMenuQuotaTrendTarget] {
    if !profileQuotaController.snapshot.profiles.isEmpty {
      return profileQuotaController.snapshot.profiles.map {
        StatusMenuQuotaTrendTarget(
          id: $0.id,
          title: $0.subscription.name,
          isCurrent: $0.isCurrent,
          analysis: $0.analysis
        )
      }
    }

    guard let subscription = controller.snapshot.subscription else {
      return []
    }
    return [
      StatusMenuQuotaTrendTarget(
        id: subscription.id,
        title: subscription.name,
        isCurrent: true,
        analysis: controller.snapshot.analysis
      )
    ]
  }
}
