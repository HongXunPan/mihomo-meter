import Combine
import Foundation

@MainActor
final class ProfileQuotaTrackingController: ObservableObject, ProfileQuotaTrackingLifecycle {
  @Published private(set) var snapshot = ProfileQuotaTrackingSnapshot.empty

  private let ledgerService: ProfileQuotaLedgerService
  private let snapshotBuilder: ProfileQuotaSnapshotBuilder
  private let worker: ProfileQuotaQueryWorker
  private let now: @MainActor () -> Date

  private var targets: [ProfileQuotaTarget] = []
  private var isProxyAvailable = false
  private var isPrepared = false

  init(
    ledger: any QuotaLedgerStoring,
    queryClient: any ActiveQuotaQuerying = MihomoActiveQuotaQueryClient(),
    schedulePolicy: ProfileQuotaSchedulePolicy = ProfileQuotaSchedulePolicy(),
    diagnosticLogger: any AppDiagnosticLogging = NoOpAppDiagnosticLogger.shared,
    now: @escaping @MainActor () -> Date = Date.init,
    jitter: @escaping @MainActor () -> TimeInterval = { Double.random(in: 0...30) }
  ) {
    let ledgerService = ProfileQuotaLedgerService(ledger: ledger)
    self.ledgerService = ledgerService
    snapshotBuilder = ProfileQuotaSnapshotBuilder(
      ledgerService: ledgerService,
      schedulePolicy: schedulePolicy
    )
    worker = ProfileQuotaQueryWorker(
      ledgerService: ledgerService,
      queryClient: queryClient,
      schedulePolicy: schedulePolicy,
      diagnosticLogger: diagnosticLogger,
      now: now,
      jitter: jitter
    )
    self.now = now
    worker.setStateChangeHandler { [weak self] in
      self?.requestSnapshotRefresh()
    }
  }

  func prepare() async {
    do {
      try await ledgerService.prepare()
      isPrepared = true
      worker.start()
      await refreshSnapshot()
    } catch {
      snapshot.storageErrorMessage = error.localizedDescription
    }
  }

  func updateTargets(_ targets: [ProfileQuotaTarget]) {
    self.targets = targets
    worker.updateTargets(targets)
    requestSnapshotRefresh()
  }

  func controllerValidated(
    endpoint: ControllerEndpoint,
    runtimeConfiguration: MihomoRuntimeConfiguration
  ) {
    let proxy = MihomoLocalProxy(
      endpoint: endpoint,
      runtimeConfiguration: runtimeConfiguration
    )
    isProxyAvailable = proxy != nil
    worker.updateProxy(
      proxy,
      userAgent: runtimeConfiguration.externalResourceUserAgent
    )
    requestSnapshotRefresh()
  }

  func controllerUnavailable() {
    isProxyAvailable = false
    worker.updateProxy(nil, userAgent: .mihomoDefault)
    requestSnapshotRefresh()
  }

  func refresh(subscriptionID: UUID) async {
    await worker.refresh(subscriptionID: subscriptionID)
  }

  func refreshAll() async {
    await worker.refreshAll()
  }

  func confirmCurrentCycle(subscriptionID: UUID) async {
    guard
      let item = snapshot.profiles.first(where: { $0.id == subscriptionID }),
      let cycleID = item.analysis.pendingCycleConfirmation?.id
    else {
      return
    }
    do {
      try await ledgerService.confirmCycle(id: cycleID)
      await refreshSnapshot()
    } catch {
      snapshot.storageErrorMessage = error.localizedDescription
    }
  }

  func prepareForDataReset() async {
    targets = []
    await worker.reset()
    snapshot = .empty
  }

  func resumeAfterDataReset() {
    worker.start()
  }

  func stop() {
    worker.stop()
  }

  private func refreshSnapshot() async {
    guard isPrepared else {
      return
    }
    let capturedTargets = targets
    do {
      let updatedSnapshot = try await snapshotBuilder.build(
        targets: capturedTargets,
        isProxyAvailable: isProxyAvailable,
        workerState: worker.state,
        at: now()
      )
      guard capturedTargets == targets else {
        return
      }
      snapshot = updatedSnapshot
    } catch {
      snapshot.storageErrorMessage = error.localizedDescription
    }
  }

  private func requestSnapshotRefresh() {
    Task { [weak self] in
      await self?.refreshSnapshot()
    }
  }
}
