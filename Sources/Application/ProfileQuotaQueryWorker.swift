import Foundation

struct ProfileQuotaWorkerState: Equatable, Sendable {
  let activeSubscriptionID: UUID?
  let statuses: [UUID: ProfileQuotaQueryStatus]
  let isRefreshingAll: Bool
}

@MainActor
final class ProfileQuotaQueryWorker {
  private let ledgerService: ProfileQuotaLedgerService
  private let schedulePolicy: ProfileQuotaSchedulePolicy
  private let executor: ProfileQuotaQueryExecutor
  private let now: @MainActor () -> Date

  private var targets: [ProfileQuotaTarget] = []
  private var proxy: MihomoLocalProxy?
  private var userAgent = MihomoRuntimeConfiguration.ExternalResourceUserAgent.mihomoDefault
  private var statuses: [UUID: ProfileQuotaQueryStatus] = [:]
  private var manualQueue: [UUID] = []
  private var activeSubscriptionID: UUID?
  private var isRefreshingAll = false
  private var workerTask: Task<Void, Never>?
  private var workerID = UUID()
  private var isStarted = false
  private var onStateChange: (@MainActor () -> Void)?

  init(
    ledgerService: ProfileQuotaLedgerService,
    queryClient: any ActiveQuotaQuerying,
    schedulePolicy: ProfileQuotaSchedulePolicy,
    diagnosticLogger: any AppDiagnosticLogging,
    now: @escaping @MainActor () -> Date,
    jitter: @escaping @MainActor () -> TimeInterval
  ) {
    self.ledgerService = ledgerService
    self.schedulePolicy = schedulePolicy
    executor = ProfileQuotaQueryExecutor(
      ledgerService: ledgerService,
      queryClient: queryClient,
      schedulePolicy: schedulePolicy,
      diagnosticLogger: diagnosticLogger,
      now: now,
      jitter: jitter
    )
    self.now = now
  }

  var state: ProfileQuotaWorkerState {
    ProfileQuotaWorkerState(
      activeSubscriptionID: activeSubscriptionID,
      statuses: statuses,
      isRefreshingAll: isRefreshingAll
    )
  }

  func setStateChangeHandler(_ handler: @escaping @MainActor () -> Void) {
    onStateChange = handler
  }

  func start() {
    isStarted = true
    wakeWorker()
  }

  func updateTargets(_ targets: [ProfileQuotaTarget]) {
    let previousTargets = Dictionary(
      uniqueKeysWithValues: self.targets.map { ($0.subscription.id, $0) })
    let activeTargetChanged =
      targets.first { $0.subscription.id == activeSubscriptionID }.map {
        previousTargets[$0.subscription.id]?.subscriptionURL != $0.subscriptionURL
      } ?? (activeSubscriptionID != nil)

    self.targets = targets
    let targetIDs = Set(targets.map(\.subscription.id))
    manualQueue.removeAll { !targetIDs.contains($0) }
    statuses = statuses.filter { targetIDs.contains($0.key) }
    for target in targets
    where previousTargets[target.subscription.id]?.subscription.urlFingerprint
      != target.subscription.urlFingerprint
    {
      statuses[target.subscription.id] = nil
    }
    notifyStateChange()
    wakeWorker(cancelActiveQuery: activeTargetChanged)
  }

  func updateProxy(
    _ proxy: MihomoLocalProxy?,
    userAgent: MihomoRuntimeConfiguration.ExternalResourceUserAgent
  ) {
    let shouldCancelActiveQuery = self.proxy != proxy || self.userAgent != userAgent
    self.proxy = proxy
    self.userAgent = userAgent
    notifyStateChange()
    wakeWorker(cancelActiveQuery: shouldCancelActiveQuery)
  }

  func refresh(subscriptionID: UUID) async {
    guard
      proxy != nil,
      activeSubscriptionID == nil,
      let target = queryableTarget(subscriptionID: subscriptionID),
      await canRefresh(target)
    else {
      return
    }
    enqueueManualRefresh(subscriptionID)
  }

  func refreshAll() async {
    guard proxy != nil, activeSubscriptionID == nil else {
      return
    }
    var queuedIDs: [UUID] = []
    for target in targets where target.subscriptionURL != nil {
      if await canRefresh(target) {
        queuedIDs.append(target.subscription.id)
      }
    }
    guard !queuedIDs.isEmpty else {
      return
    }
    manualQueue.append(contentsOf: queuedIDs.filter { !manualQueue.contains($0) })
    isRefreshingAll = true
    notifyStateChange()
    wakeWorker()
  }

  func stop() {
    isStarted = false
    workerID = UUID()
    workerTask?.cancel()
    workerTask = nil
    activeSubscriptionID = nil
    manualQueue.removeAll()
    isRefreshingAll = false
  }

  func reset() async {
    isStarted = false
    targets = []
    statuses = [:]
    manualQueue = []
    activeSubscriptionID = nil
    isRefreshingAll = false
    workerID = UUID()
    let activeTask = workerTask
    workerTask = nil
    activeTask?.cancel()
    await activeTask?.value
    notifyStateChange()
  }

  private func enqueueManualRefresh(_ subscriptionID: UUID) {
    guard !manualQueue.contains(subscriptionID) else {
      return
    }
    manualQueue.append(subscriptionID)
    wakeWorker()
  }

  private func wakeWorker(cancelActiveQuery: Bool = false) {
    guard isStarted else {
      return
    }
    if activeSubscriptionID != nil, !cancelActiveQuery {
      return
    }
    let previousTask = workerTask
    workerID = UUID()
    previousTask?.cancel()
    let id = workerID
    if cancelActiveQuery, previousTask != nil {
      workerTask = Task { [weak self] in
        await previousTask?.value
        guard let self, isStarted, workerID == id else {
          return
        }
        activeSubscriptionID = nil
        await runWorker(id: id)
        finishWorker(id: id)
      }
    } else {
      startWorker(id: id)
    }
  }

  private func startWorker(id: UUID) {
    workerTask = Task { [weak self] in
      guard let self else {
        return
      }
      await runWorker(id: id)
      finishWorker(id: id)
    }
  }

  private func finishWorker(id: UUID) {
    guard workerID == id else {
      return
    }
    workerTask = nil
    activeSubscriptionID = nil
    isRefreshingAll = false
    notifyStateChange()
  }

  private func runWorker(id: UUID) async {
    while !Task.isCancelled, workerID == id {
      guard let proxy else {
        return
      }
      if let target = nextManualTarget() {
        await performQuery(target: target, proxy: proxy, trigger: .manual)
        if manualQueue.isEmpty {
          isRefreshingAll = false
        }
        continue
      }
      guard let candidate = await nextAutomaticTarget() else {
        return
      }
      let delay = candidate.dueDate.timeIntervalSince(now())
      if delay > 0 {
        do {
          let boundedDelay = min(delay, 86_400)
          try await Task.sleep(nanoseconds: UInt64(boundedDelay * 1_000_000_000))
        } catch {
          return
        }
        continue
      }
      await performQuery(target: candidate.target, proxy: proxy, trigger: .automatic)
    }
  }

  private func nextManualTarget() -> ProfileQuotaTarget? {
    while !manualQueue.isEmpty {
      let subscriptionID = manualQueue.removeFirst()
      if let target = queryableTarget(subscriptionID: subscriptionID) {
        return target
      }
    }
    return nil
  }

  private func nextAutomaticTarget() async -> (target: ProfileQuotaTarget, dueDate: Date)? {
    var candidates: [(ProfileQuotaTarget, Date)] = []
    do {
      for target in targets where target.subscriptionURL != nil {
        let state = try await ledgerService.queryState(for: target.subscription.id)
        let dueDate = schedulePolicy.dueDate(
          for: target.subscription,
          state: state,
          now: now()
        )
        candidates.append((target, dueDate))
      }
    } catch {
      return nil
    }
    return candidates.min { left, right in
      if left.1 != right.1 {
        return left.1 < right.1
      }
      return left.0.isCurrent && !right.0.isCurrent
    }.map { (target: $0.0, dueDate: $0.1) }
  }

  private func performQuery(
    target: ProfileQuotaTarget,
    proxy: MihomoLocalProxy,
    trigger: ProfileQuotaQueryTrigger
  ) async {
    activeSubscriptionID = target.subscription.id
    statuses[target.subscription.id] = .querying
    notifyStateChange()

    do {
      statuses[target.subscription.id] = try await executor.execute(
        target: target,
        proxy: proxy,
        userAgent: userAgent,
        trigger: trigger,
        isTargetCurrent: { [weak self] in self?.isCurrent(target) == true }
      )
    } catch {
      activeSubscriptionID = nil
      return
    }
    activeSubscriptionID = nil
    notifyStateChange()
  }

  private func queryableTarget(subscriptionID: UUID) -> ProfileQuotaTarget? {
    targets.first {
      $0.subscription.id == subscriptionID && $0.subscriptionURL != nil
    }
  }

  private func canRefresh(_ target: ProfileQuotaTarget) async -> Bool {
    if statuses[target.subscription.id]?.allowsImmediateManualRetry == true {
      return true
    }
    guard let state = try? await ledgerService.queryState(for: target.subscription.id) else {
      return true
    }
    let availableAt = schedulePolicy.manualRefreshAvailableAt(state: state)
    return availableAt.map { $0 <= now() } ?? true
  }

  private func isCurrent(_ target: ProfileQuotaTarget) -> Bool {
    targets.contains {
      $0.subscription.id == target.subscription.id
        && $0.subscription.urlFingerprint == target.subscription.urlFingerprint
        && $0.subscriptionURL == target.subscriptionURL
    }
  }

  private func notifyStateChange() {
    onStateChange?()
  }
}
