import Foundation
import Security

extension AppDiagnosticEvent {
  func diagnosticExportEvent(at timestamp: Date) -> DiagnosticExportEvent {
    switch self {
    case .applicationLaunched(let summary):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "application.launched",
        outcome: summary.isAdHoc.map { $0 ? "adhoc" : "identity" } ?? "unknown",
        statusCode: Int(summary.inspectionStatus)
      )
    case .sharedCoreRuntimeProbe(let status):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "shared_core.runtime_probe",
        outcome: status.rawValue
      )
    case .sharedCoreProxyTypeShadow(let observation):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "shared_core.proxy_type_shadow",
        source: observation.source.rawValue,
        status: observation.status.rawValue
      )
    case .sharedCoreProxyTypeRoute(let observation):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "shared_core.proxy_type_route",
        source: observation.source.rawValue,
        status: observation.status.rawValue
      )
    case .sharedCoreTrafficShadow(let observation):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "shared_core.traffic_shadow",
        outcome: observation.status.rawValue,
        format: observation.format.rawValue
      )
    case .sharedCoreTrafficRoute(let observation):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "shared_core.traffic_route",
        outcome: observation.source.rawValue,
        status: observation.status.rawValue,
        format: observation.format.rawValue
      )
    case .keychainOperationStarted(let context):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "keychain.operation.started",
        reason: context.reason.rawValue,
        operation: context.operation.rawValue
      )
    case .keychainOperationFinished(let context, let outcome, let elapsedMilliseconds):
      let detail = outcome.diagnosticExportDetail
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "keychain.operation.finished",
        outcome: detail.outcome,
        reason: context.reason.rawValue,
        operation: context.operation.rawValue,
        statusCode: detail.statusCode,
        elapsedMilliseconds: max(elapsedMilliseconds, 0)
      )
    case .connectionAttemptStarted(let trigger, let attemptNumber):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "connection.attempt.started",
        trigger: trigger.rawValue,
        attemptNumber: max(attemptNumber, 1)
      )
    case .connectionEstablished:
      return DiagnosticExportEvent(timestamp: timestamp, category: "connection.established")
    case .runtimeConfigurationUnavailable(let reason):
      return connectionReasonEvent(
        timestamp: timestamp,
        category: "runtime_configuration.unavailable",
        reason: reason
      )
    case .connectionDataStale(
      let timeoutSeconds,
      let reconnectAfterSeconds,
      let lastSnapshotAgeMilliseconds
    ):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "connection.data_stale",
        timeoutSeconds: max(timeoutSeconds, 0),
        reconnectAfterSeconds: max(reconnectAfterSeconds, 0),
        lastSnapshotAgeMilliseconds: max(lastSnapshotAgeMilliseconds, 0)
      )
    case .connectionCancellationRequested(let source, let lastSnapshotAgeMilliseconds):
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "connection.cancellation_requested",
        source: source.rawValue,
        lastSnapshotAgeMilliseconds: lastSnapshotAgeMilliseconds.map { max($0, 0) }
      )
    case .connectionReconnectScheduled(let reason, let delaySeconds):
      let detail = reason.diagnosticExportDetail
      return DiagnosticExportEvent(
        timestamp: timestamp,
        category: "connection.reconnect_scheduled",
        reason: detail.reason,
        statusCode: detail.statusCode,
        delaySeconds: Int(clamping: delaySeconds)
      )
    case .connectionStopped(let reason):
      return connectionReasonEvent(
        timestamp: timestamp,
        category: "connection.stopped",
        reason: reason
      )
    case .profileQuotaQueryStarted(let context):
      return profileQuotaEvent(
        timestamp: timestamp,
        category: "profile_quota.query.started",
        context: context
      )
    case .profileQuotaQueryFinished(
      let context,
      let outcome,
      let elapsedMilliseconds,
      let retryAfterSeconds
    ):
      let detail = outcome.diagnosticExportDetail
      return profileQuotaEvent(
        timestamp: timestamp,
        category: "profile_quota.query.finished",
        context: context,
        outcome: detail.outcome,
        httpStatus: detail.statusCode,
        networkCode: detail.networkCode,
        elapsedMilliseconds: max(elapsedMilliseconds, 0),
        timeoutSeconds: detail.timeoutSeconds,
        retryAfterSeconds: retryAfterSeconds.map { max($0, 0) }
      )
    }
  }

  private func connectionReasonEvent(
    timestamp: Date,
    category: String,
    reason: ConnectionDiagnosticReason
  ) -> DiagnosticExportEvent {
    let detail = reason.diagnosticExportDetail
    return DiagnosticExportEvent(
      timestamp: timestamp,
      category: category,
      reason: detail.reason,
      statusCode: detail.statusCode
    )
  }

  private func profileQuotaEvent(
    timestamp: Date,
    category: String,
    context: ProfileQuotaDiagnosticContext,
    outcome: String? = nil,
    httpStatus: Int? = nil,
    networkCode: Int? = nil,
    elapsedMilliseconds: Int? = nil,
    timeoutSeconds: Int? = nil,
    retryAfterSeconds: Int? = nil
  ) -> DiagnosticExportEvent {
    DiagnosticExportEvent(
      timestamp: timestamp,
      category: category,
      outcome: outcome,
      trigger: context.trigger.rawValue,
      proxyKind: context.proxyKind.rawValue,
      userAgentSource: context.userAgentSource.rawValue,
      httpStatus: httpStatus,
      networkCode: networkCode,
      elapsedMilliseconds: elapsedMilliseconds,
      timeoutSeconds: timeoutSeconds,
      retryAfterSeconds: retryAfterSeconds,
      isCurrentProfile: context.isCurrentProfile
    )
  }
}

extension KeychainDiagnosticOutcome {
  fileprivate var diagnosticExportDetail: (outcome: String, statusCode: Int) {
    switch self {
    case .loaded: ("loaded", 0)
    case .empty: ("empty", 0)
    case .notFound: ("not_found", Int(errSecItemNotFound))
    case .updated: ("updated", 0)
    case .created: ("created", 0)
    case .deleted: ("deleted", 0)
    case .cleared: ("cleared", 0)
    case .alreadyMissing: ("already_missing", Int(errSecItemNotFound))
    case .invalidData: ("invalid_data", 0)
    case .failed(let status): ("failed", Int(status))
    }
  }
}

extension ConnectionDiagnosticReason {
  fileprivate var diagnosticExportDetail: (reason: String, statusCode: Int?) {
    switch self {
    case .invalidEndpoint: ("invalid_endpoint", nil)
    case .authenticationFailed: ("authentication_failed", nil)
    case .controllerHTTP(let code): ("controller_http", code)
    case .controllerInvalidResponse: ("controller_invalid_response", nil)
    case .unsupportedResponse: ("unsupported_response", nil)
    case .controllerNetwork(let code): ("controller_network", code.rawValue)
    case .controllerTransport: ("controller_transport", nil)
    case .streamMalformedMessage: ("stream_malformed_message", nil)
    case .streamNetwork(let code): ("stream_network", code.rawValue)
    case .streamClosed: ("stream_closed", nil)
    case .keychainInvalidData: ("keychain_invalid_data", nil)
    case .keychainStatus(let status): ("keychain_status", Int(status))
    case .dataStale: ("data_stale", nil)
    case .unknown: ("unknown", nil)
    }
  }
}

extension ProfileQuotaDiagnosticOutcome {
  fileprivate var diagnosticExportDetail:
    (
      outcome: String,
      statusCode: Int?,
      networkCode: Int?,
      timeoutSeconds: Int?
    )
  {
    switch self {
    case .succeeded: ("succeeded", nil, nil, nil)
    case .cancelled: ("cancelled", nil, nil, nil)
    case .insecureSubscriptionURL: ("insecure_subscription_url", nil, nil, nil)
    case .noAvailableMihomoProxy: ("no_available_mihomo_proxy", nil, nil, nil)
    case .insecureRedirect: ("insecure_redirect", nil, nil, nil)
    case .invalidResponse: ("invalid_response", nil, nil, nil)
    case .httpStatus(let code): ("http_status", code, nil, nil)
    case .missingSubscriptionInfo(let code): ("missing_subscription_info", code, nil, nil)
    case .invalidSubscriptionInfo: ("invalid_subscription_info", nil, nil, nil)
    case .timedOut(let seconds):
      ("network_error", nil, URLError.Code.timedOut.rawValue, max(seconds, 0))
    case .network(let code): ("network_error", nil, code.rawValue, nil)
    case .transport: ("transport_error", nil, nil, nil)
    case .storageUnavailable: ("storage_unavailable", nil, nil, nil)
    }
  }
}
