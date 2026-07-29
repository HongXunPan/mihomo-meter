import Combine
import Foundation

@MainActor
final class RuntimeQuotaTrackingController: ObservableObject, RuntimeQuotaTrackingLifecycle {
  @Published private(set) var snapshot = RuntimeQuotaTrackingSnapshot.empty

  private let ledgerService: RuntimeQuotaLedgerService
  private let observer: any RuntimeQuotaObserving
  private let now: @MainActor () -> Date

  private var latestCandidate: RuntimeQuotaCandidate?
  private var runtimeSourceKey: String?
  private var validatedEndpoint: ControllerEndpoint?
  private var requiresConfirmationBeforeRecording = false
  private var isDataResetInProgress = false
  private var isPrepared = false

  init(
    ledger: any QuotaLedgerStoring,
    observer: any RuntimeQuotaObserving,
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    ledgerService = RuntimeQuotaLedgerService(ledger: ledger)
    self.observer = observer
    self.now = now
  }

  func prepare() async {
    do {
      apply(try await ledgerService.prepare(at: now()))
      snapshot.pauseReason = snapshot.isPaused ? .previousAmbiguity : nil
      snapshot.observationStatus = .controllerUnavailable
      isPrepared = true
    } catch {
      setUnavailable(error)
    }
  }

  func controllerValidated(endpoint: ControllerEndpoint, secret: String) {
    guard isPrepared else {
      return
    }
    if let validatedEndpoint, validatedEndpoint != endpoint, snapshot.isActive {
      requiresConfirmationBeforeRecording = true
    }
    validatedEndpoint = endpoint
    latestCandidate = nil
    snapshot.observationStatus = .checking
    observer.start(endpoint: endpoint, secret: secret) { [weak self] result in
      await self?.handle(result)
    }
  }

  func controllerUnavailable() {
    observer.stop()
    latestCandidate = nil
    guard !isStorageUnavailable else {
      return
    }
    snapshot.observationStatus = .controllerUnavailable
  }

  func enableTracking() async {
    guard snapshot.subscription == nil, let candidate = latestCandidate else {
      return
    }
    do {
      apply(try await ledgerService.enable(candidate: candidate, at: now()))
      snapshot.pauseReason = nil
      runtimeSourceKey = candidate.sourceKey
      requiresConfirmationBeforeRecording = false
    } catch {
      setUnavailable(error)
    }
  }

  func resumeTracking() async {
    guard
      let subscription = snapshot.subscription,
      subscription.status == .paused,
      let candidate = latestCandidate
    else {
      return
    }
    do {
      apply(
        try await ledgerService.resume(
          candidate: candidate,
          state: storedState,
          at: now()
        )
      )
      snapshot.pauseReason = nil
      runtimeSourceKey = candidate.sourceKey
      requiresConfirmationBeforeRecording = false
    } catch {
      setUnavailable(error)
    }
  }

  func confirmCurrentCycle() async {
    guard
      let subscriptionID = snapshot.subscription?.id,
      let cycleID = snapshot.analysis.pendingCycleConfirmation?.id
    else {
      return
    }
    do {
      snapshot.analysis = try await ledgerService.confirmCycle(
        id: cycleID,
        subscriptionID: subscriptionID,
        at: now()
      )
    } catch {
      setUnavailable(error)
    }
  }

  func prepareForDataReset() {
    isDataResetInProgress = true
  }

  func completeDataReset() {
    snapshot.subscription = nil
    snapshot.analysis = .empty
    snapshot.pauseReason = nil
    runtimeSourceKey = nil
    requiresConfirmationBeforeRecording = false
    isDataResetInProgress = false
    if latestCandidate != nil {
      snapshot.observationStatus = .available
    } else if validatedEndpoint != nil {
      snapshot.observationStatus = .checking
    } else {
      snapshot.observationStatus = .controllerUnavailable
    }
  }

  func cancelDataReset() {
    isDataResetInProgress = false
  }

  func stop() {
    observer.stop()
  }

  private var isStorageUnavailable: Bool {
    if case .unavailable = snapshot.observationStatus {
      return true
    }
    return false
  }

  private func handle(_ result: RuntimeQuotaObservationResult) async {
    guard !isDataResetInProgress else {
      return
    }
    switch result {
    case .failed(let message):
      latestCandidate = nil
      snapshot.observationStatus = .failed(message)
    case .selection(let selection):
      await handle(selection)
    }
  }

  private func handle(_ selection: RuntimeQuotaCandidateSelection) async {
    switch selection {
    case .none:
      latestCandidate = nil
      snapshot.observationStatus = .noCandidate
      await pauseTracking(reason: .noCandidate)
    case .multiple(let count):
      latestCandidate = nil
      snapshot.observationStatus = .multipleCandidates(count)
      await pauseTracking(reason: .multipleCandidates)
    case .single(let candidate):
      latestCandidate = candidate
      snapshot.observationStatus = .available
      await handle(candidate)
    }
  }

  private func handle(_ candidate: RuntimeQuotaCandidate) async {
    guard snapshot.isActive else {
      return
    }
    if requiresConfirmationBeforeRecording {
      requiresConfirmationBeforeRecording = false
      await pauseTracking(reason: .controllerChanged)
      return
    }
    if let runtimeSourceKey, runtimeSourceKey != candidate.sourceKey {
      await pauseTracking(reason: .sourceChanged)
      return
    }

    runtimeSourceKey = candidate.sourceKey
    do {
      apply(
        try await ledgerService.record(
          candidate: candidate,
          state: storedState,
          at: now()
        )
      )
    } catch {
      setUnavailable(error)
    }
  }

  private func pauseTracking(reason: RuntimeQuotaPauseReason) async {
    guard let subscription = snapshot.subscription, subscription.status == .active else {
      return
    }
    do {
      apply(
        try await ledgerService.pause(
          state: storedState,
          at: now()
        )
      )
      snapshot.pauseReason = reason
    } catch {
      setUnavailable(error)
    }
  }

  private var storedState: RuntimeQuotaStoredState {
    RuntimeQuotaStoredState(
      subscription: snapshot.subscription,
      analysis: snapshot.analysis
    )
  }

  private func apply(_ state: RuntimeQuotaStoredState) {
    snapshot.subscription = state.subscription
    snapshot.analysis = state.analysis
  }

  private func setUnavailable(_ error: any Error) {
    snapshot.observationStatus = .unavailable(error.localizedDescription)
  }
}
