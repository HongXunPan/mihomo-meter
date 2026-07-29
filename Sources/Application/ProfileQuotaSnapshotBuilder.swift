import Foundation

struct ProfileQuotaSnapshotBuilder {
  let ledgerService: ProfileQuotaLedgerService
  let schedulePolicy: ProfileQuotaSchedulePolicy

  func build(
    targets: [ProfileQuotaTarget],
    isProxyAvailable: Bool,
    workerState: ProfileQuotaWorkerState,
    at date: Date
  ) async throws -> ProfileQuotaTrackingSnapshot {
    var items: [ProfileQuotaTrackingItem] = []
    for target in targets {
      let state = try await ledgerService.queryState(for: target.subscription.id)
      let analysis = try await ledgerService.analysis(
        for: target.subscription.id,
        at: date
      )
      let availableAt = schedulePolicy.manualRefreshAvailableAt(state: state)
      items.append(
        ProfileQuotaTrackingItem(
          subscription: target.subscription,
          profileUID: target.profileUID,
          isCurrent: target.isCurrent,
          availability: target.availability,
          analysis: analysis,
          queryStatus: queryStatus(
            for: target,
            state: state,
            isProxyAvailable: isProxyAvailable,
            workerState: workerState,
            at: date
          ),
          canRefresh: canRefresh(
            target,
            availableAt: availableAt,
            isProxyAvailable: isProxyAvailable,
            workerState: workerState,
            at: date
          ),
          manualRefreshAvailableAt: availableAt
        )
      )
    }
    return ProfileQuotaTrackingSnapshot(
      profiles: items,
      isRefreshingAll: workerState.isRefreshingAll,
      storageErrorMessage: nil
    )
  }

  private func queryStatus(
    for target: ProfileQuotaTarget,
    state: ProfileQuotaQueryState?,
    isProxyAvailable: Bool,
    workerState: ProfileQuotaWorkerState,
    at date: Date
  ) -> ProfileQuotaQueryStatus {
    guard target.availability == .available else {
      return .unavailableProfile
    }
    if workerState.activeSubscriptionID == target.subscription.id {
      return .querying
    }
    if let transientStatus = workerState.statuses[target.subscription.id] {
      return transientStatus
    }
    guard isProxyAvailable else {
      return .waitingForProxy
    }
    return .scheduled(
      schedulePolicy.dueDate(for: target.subscription, state: state, now: date)
    )
  }

  private func canRefresh(
    _ target: ProfileQuotaTarget,
    availableAt: Date?,
    isProxyAvailable: Bool,
    workerState: ProfileQuotaWorkerState,
    at date: Date
  ) -> Bool {
    guard
      isProxyAvailable,
      workerState.activeSubscriptionID == nil,
      target.subscriptionURL != nil
    else {
      return false
    }
    return availableAt.map { $0 <= date } ?? true
  }
}
