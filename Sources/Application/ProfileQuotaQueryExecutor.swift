import Foundation

@MainActor
struct ProfileQuotaQueryExecutor {
  private let ledgerService: ProfileQuotaLedgerService
  private let queryClient: any ActiveQuotaQuerying
  private let schedulePolicy: ProfileQuotaSchedulePolicy
  private let diagnosticLogger: any AppDiagnosticLogging
  private let now: @MainActor () -> Date
  private let jitter: @MainActor () -> TimeInterval

  init(
    ledgerService: ProfileQuotaLedgerService,
    queryClient: any ActiveQuotaQuerying,
    schedulePolicy: ProfileQuotaSchedulePolicy,
    diagnosticLogger: any AppDiagnosticLogging,
    now: @escaping @MainActor () -> Date,
    jitter: @escaping @MainActor () -> TimeInterval
  ) {
    self.ledgerService = ledgerService
    self.queryClient = queryClient
    self.schedulePolicy = schedulePolicy
    self.diagnosticLogger = diagnosticLogger
    self.now = now
    self.jitter = jitter
  }

  func execute(
    target: ProfileQuotaTarget,
    proxy: MihomoLocalProxy,
    userAgent: MihomoRuntimeConfiguration.ExternalResourceUserAgent,
    trigger: ProfileQuotaQueryTrigger,
    isTargetCurrent: @escaping @MainActor () -> Bool
  ) async throws -> ProfileQuotaQueryStatus {
    guard let subscriptionURL = target.subscriptionURL else {
      return .unavailableProfile
    }
    let diagnosticContext = makeDiagnosticContext(
      target: target,
      proxy: proxy,
      userAgent: userAgent,
      trigger: trigger
    )
    let startedAt = ProcessInfo.processInfo.systemUptime
    await diagnosticLogger.record(.profileQuotaQueryStarted(diagnosticContext))

    do {
      let result = try await queryClient.query(
        subscriptionURL: subscriptionURL,
        via: proxy,
        userAgent: userAgent.value
      )
      try Task.checkCancellation()
      guard isTargetCurrent() else {
        throw CancellationError()
      }
      let queryDate = now()
      try await ledgerService.record(result: result, for: target.subscription, at: queryDate)
      try await ledgerService.saveQueryState(
        schedulePolicy.successfulState(
          for: target.subscription,
          at: queryDate,
          jitter: jitter()
        )
      )
      await recordFinished(
        context: diagnosticContext,
        outcome: .succeeded,
        startedAt: startedAt,
        retryAt: nil,
        referenceDate: queryDate
      )
      return .available
    } catch is CancellationError {
      await recordFinished(
        context: diagnosticContext,
        outcome: .cancelled,
        startedAt: startedAt,
        retryAt: nil,
        referenceDate: now()
      )
      throw CancellationError()
    } catch {
      let failureDate = now()
      let failure = await failureStatus(
        error,
        target: target,
        trigger: trigger,
        at: failureDate
      )
      let outcome =
        if case .storageUnavailable = failure.status {
          ProfileQuotaDiagnosticOutcome.storageUnavailable
        } else {
          diagnosticOutcome(for: error)
        }
      await recordFinished(
        context: diagnosticContext,
        outcome: outcome,
        startedAt: startedAt,
        retryAt: failure.retryAt,
        referenceDate: failureDate
      )
      return failure.status
    }
  }

  private func failureStatus(
    _ error: any Error,
    target: ProfileQuotaTarget,
    trigger: ProfileQuotaQueryTrigger,
    at failureDate: Date
  ) async -> (status: ProfileQuotaQueryStatus, retryAt: Date?) {
    do {
      let previousState = try await ledgerService.queryState(for: target.subscription.id)
      let failedState = schedulePolicy.failedState(
        for: target.subscription,
        previous: previousState,
        trigger: trigger,
        at: failureDate,
        jitter: jitter()
      )
      try await ledgerService.saveQueryState(failedState)
      return (
        .failed(
          message: error.localizedDescription,
          retryAt: failedState.nextAttemptAt,
          manualRetryPolicy: manualRetryPolicy(for: error)
        ),
        failedState.nextAttemptAt
      )
    } catch {
      return (.storageUnavailable(error.localizedDescription), nil)
    }
  }

  private func makeDiagnosticContext(
    target: ProfileQuotaTarget,
    proxy: MihomoLocalProxy,
    userAgent: MihomoRuntimeConfiguration.ExternalResourceUserAgent,
    trigger: ProfileQuotaQueryTrigger
  ) -> ProfileQuotaDiagnosticContext {
    ProfileQuotaDiagnosticContext(
      subscriptionID: target.subscription.id,
      urlFingerprint: target.subscription.urlFingerprint,
      trigger: trigger == .manual ? .manual : .automatic,
      isCurrentProfile: target.isCurrent,
      proxyKind: diagnosticProxyKind(proxy.kind),
      userAgentSource: diagnosticUserAgentSource(userAgent.source)
    )
  }

  private func diagnosticUserAgentSource(
    _ source: MihomoRuntimeConfiguration.ExternalResourceUserAgent.Source
  ) -> ProfileQuotaDiagnosticUserAgentSource {
    switch source {
    case .mihomoConfiguration:
      .mihomoConfiguration
    case .mihomoDefault:
      .mihomoDefault
    }
  }

  private func diagnosticProxyKind(
    _ proxyKind: MihomoLocalProxyKind
  ) -> ProfileQuotaDiagnosticProxyKind {
    switch proxyKind {
    case .mixed:
      .mixed
    case .http:
      .http
    case .socks:
      .socks
    }
  }

  private func diagnosticOutcome(for error: any Error) -> ProfileQuotaDiagnosticOutcome {
    guard let queryError = error as? ActiveQuotaQueryError else {
      return .storageUnavailable
    }
    switch queryError {
    case .insecureSubscriptionURL:
      return .insecureSubscriptionURL
    case .noAvailableMihomoProxy:
      return .noAvailableMihomoProxy
    case .insecureRedirect:
      return .insecureRedirect
    case .invalidResponse:
      return .invalidResponse
    case .httpStatus(let statusCode):
      return .httpStatus(statusCode)
    case .missingSubscriptionUserInfo(let statusCode):
      return .missingSubscriptionInfo(statusCode: statusCode)
    case .invalidSubscriptionUserInfo:
      return .invalidSubscriptionInfo
    case .timedOut(let timeoutSeconds):
      return .timedOut(timeoutSeconds: timeoutSeconds)
    case .network(let code):
      return .network(code)
    case .transport:
      return .transport
    }
  }

  private func manualRetryPolicy(
    for error: any Error
  ) -> ProfileQuotaManualRetryPolicy {
    guard let queryError = error as? ActiveQuotaQueryError else {
      return .cooldown
    }
    switch queryError {
    case .timedOut, .network, .transport:
      return .immediate
    default:
      return .cooldown
    }
  }

  private func recordFinished(
    context: ProfileQuotaDiagnosticContext,
    outcome: ProfileQuotaDiagnosticOutcome,
    startedAt: TimeInterval,
    retryAt: Date?,
    referenceDate: Date
  ) async {
    let elapsedMilliseconds = Int(
      max((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000, 0)
    )
    let retryAfterSeconds = retryAt.map {
      Int(max($0.timeIntervalSince(referenceDate).rounded(.up), 0))
    }
    await diagnosticLogger.record(
      .profileQuotaQueryFinished(
        context,
        outcome: outcome,
        elapsedMilliseconds: elapsedMilliseconds,
        retryAfterSeconds: retryAfterSeconds
      )
    )
  }
}
