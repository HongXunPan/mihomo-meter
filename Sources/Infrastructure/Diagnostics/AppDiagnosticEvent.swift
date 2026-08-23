import Foundation
import Security

protocol AppDiagnosticLogging: Sendable {
  func record(_ event: AppDiagnosticEvent) async
}

struct NoOpAppDiagnosticLogger: AppDiagnosticLogging {
  static let shared = NoOpAppDiagnosticLogger()

  func record(_ event: AppDiagnosticEvent) async {}
}

enum KeychainDiagnosticOperation: String, Sendable {
  case load
  case save
  case delete
}

enum KeychainAccessReason: String, Sendable {
  case applicationStartup = "application_startup"
  case connectionValidated = "connection_validated"
  case validatedEmptyAccessKey = "validated_empty_access_key"
  case explicitRemoval = "explicit_removal"
}

struct KeychainDiagnosticContext: Equatable, Sendable {
  let requestID: UUID
  let operation: KeychainDiagnosticOperation
  let reason: KeychainAccessReason

  init(
    requestID: UUID = UUID(),
    operation: KeychainDiagnosticOperation,
    reason: KeychainAccessReason
  ) {
    self.requestID = requestID
    self.operation = operation
    self.reason = reason
  }

  fileprivate var logFields: String {
    [
      "request_id=\(requestID.uuidString.lowercased())",
      "operation=\(operation.rawValue)",
      "reason=\(reason.rawValue)",
    ].joined(separator: " ")
  }
}

enum KeychainDiagnosticOutcome: Equatable, Sendable {
  case loaded
  case empty
  case notFound
  case updated
  case created
  case deleted
  case cleared
  case alreadyMissing
  case invalidData
  case failed(OSStatus)

  fileprivate var logFields: String {
    switch self {
    case .loaded:
      "result=loaded status=0"
    case .empty:
      "result=empty status=0"
    case .notFound:
      "result=not_found status=\(errSecItemNotFound)"
    case .updated:
      "result=updated status=0"
    case .created:
      "result=created status=0"
    case .deleted:
      "result=deleted status=0"
    case .cleared:
      "result=cleared status=0"
    case .alreadyMissing:
      "result=already_missing status=\(errSecItemNotFound)"
    case .invalidData:
      "result=invalid_data status=0"
    case .failed(let status):
      "result=failed status=\(status)"
    }
  }
}

enum ConnectionAttemptTrigger: String, Sendable {
  case applicationStartup = "application_startup"
  case userRequest = "user_request"
  case immediateRetry = "immediate_retry"
  case automaticRetry = "automatic_retry"
  case systemRecovery = "system_recovery"
}

enum ConnectionCancellationSource: String, Sendable {
  case staleWatchdog = "stale_watchdog"
  case userDisconnect = "user_disconnect"
  case applicationTermination = "application_termination"
  case userConnectionRequest = "user_connection_request"
  case immediateRetry = "immediate_retry"
  case systemEnvironmentChange = "system_environment_change"
}

struct AppCodeSigningSummary: Equatable, Sendable {
  let identifier: String
  let teamIdentifier: String?
  let isAdHoc: Bool?
  let inspectionStatus: OSStatus
}

enum AppDiagnosticEvent: Equatable, Sendable {
  case applicationLaunched(AppCodeSigningSummary)
  case sharedCoreRuntimeProbe(SharedCoreRuntimeStatus)
  case sharedCoreProxyTypeShadow(SharedCoreProxyTypeShadowObservation)
  case sharedCoreProxyTypeRoute(SharedCoreProxyTypeRouteObservation)
  case sharedCoreTrafficShadow(SharedCoreTrafficShadowObservation)
  case sharedCoreTrafficRoute(SharedCoreTrafficRouteObservation)
  case keychainOperationStarted(KeychainDiagnosticContext)
  case keychainOperationFinished(
    KeychainDiagnosticContext,
    outcome: KeychainDiagnosticOutcome,
    elapsedMilliseconds: Int
  )
  case connectionAttemptStarted(
    trigger: ConnectionAttemptTrigger,
    attemptNumber: Int
  )
  case connectionEstablished
  case runtimeConfigurationUnavailable(reason: ConnectionDiagnosticReason)
  case connectionDataStale(
    timeoutSeconds: Int,
    reconnectAfterSeconds: Int,
    lastSnapshotAgeMilliseconds: Int
  )
  case connectionCancellationRequested(
    source: ConnectionCancellationSource,
    lastSnapshotAgeMilliseconds: Int?
  )
  case connectionReconnectScheduled(
    reason: ConnectionDiagnosticReason,
    delaySeconds: UInt64
  )
  case connectionStopped(reason: ConnectionDiagnosticReason)
  case profileQuotaQueryStarted(ProfileQuotaDiagnosticContext)
  case profileQuotaQueryFinished(
    ProfileQuotaDiagnosticContext,
    outcome: ProfileQuotaDiagnosticOutcome,
    elapsedMilliseconds: Int,
    retryAfterSeconds: Int?
  )

  var logMessage: String {
    switch self {
    case .applicationLaunched(let summary):
      let signingType = summary.isAdHoc.map { $0 ? "adhoc" : "identity" } ?? "unknown"
      return [
        "event=application.launched",
        "bundle_id=\(summary.identifier)",
        "signing=\(signingType)",
        "team_id=\(summary.teamIdentifier ?? "none")",
        "inspection_status=\(summary.inspectionStatus)",
      ].joined(separator: " ")
    case .sharedCoreRuntimeProbe(let status):
      return "event=shared_core.runtime_probe result=\(status.rawValue)"
    case .sharedCoreProxyTypeShadow(let observation):
      return [
        "event=shared_core.proxy_type_shadow",
        "source=\(observation.source.rawValue)",
        "status=\(observation.status.rawValue)",
      ].joined(separator: " ")
    case .sharedCoreProxyTypeRoute(let observation):
      return [
        "event=shared_core.proxy_type_route",
        "source=\(observation.source.rawValue)",
        "status=\(observation.status.rawValue)",
      ].joined(separator: " ")
    case .sharedCoreTrafficShadow(let observation):
      return [
        "event=shared_core.traffic_shadow",
        "format=\(observation.format.rawValue)",
        "result=\(observation.status.rawValue)",
      ].joined(separator: " ")
    case .sharedCoreTrafficRoute(let observation):
      return [
        "event=shared_core.traffic_route",
        "format=\(observation.format.rawValue)",
        "result=\(observation.source.rawValue)",
        "status=\(observation.status.rawValue)",
      ].joined(separator: " ")
    case .keychainOperationStarted(let context):
      return "event=keychain.operation.started \(context.logFields)"
    case .keychainOperationFinished(let context, let outcome, let elapsedMilliseconds):
      return [
        "event=keychain.operation.finished",
        context.logFields,
        outcome.logFields,
        "elapsed_ms=\(max(elapsedMilliseconds, 0))",
      ].joined(separator: " ")
    case .connectionAttemptStarted(let trigger, let attemptNumber):
      return [
        "event=connection.attempt.started",
        "trigger=\(trigger.rawValue)",
        "attempt=\(max(attemptNumber, 1))",
      ].joined(separator: " ")
    case .connectionEstablished:
      return "event=connection.established"
    case .runtimeConfigurationUnavailable(let reason):
      return [
        "event=runtime_configuration.unavailable",
        reason.logFields,
      ].joined(separator: " ")
    case .connectionDataStale(
      let timeoutSeconds,
      let reconnectAfterSeconds,
      let lastSnapshotAgeMilliseconds
    ):
      return [
        "event=connection.data_stale",
        "timeout_seconds=\(max(timeoutSeconds, 0))",
        "reconnect_after_seconds=\(max(reconnectAfterSeconds, 0))",
        "last_snapshot_age_ms=\(max(lastSnapshotAgeMilliseconds, 0))",
      ].joined(separator: " ")
    case .connectionCancellationRequested(
      let source,
      let lastSnapshotAgeMilliseconds
    ):
      var fields = [
        "event=connection.cancellation_requested",
        "source=\(source.rawValue)",
      ].joined(separator: " ")
      if let lastSnapshotAgeMilliseconds {
        fields += " last_snapshot_age_ms=\(max(lastSnapshotAgeMilliseconds, 0))"
      }
      return fields
    case .connectionReconnectScheduled(let reason, let delaySeconds):
      return [
        "event=connection.reconnect_scheduled",
        reason.logFields,
        "delay_seconds=\(delaySeconds)",
      ].joined(separator: " ")
    case .connectionStopped(let reason):
      return [
        "event=connection.stopped",
        reason.logFields,
      ].joined(separator: " ")
    case .profileQuotaQueryStarted(let context):
      return "event=profile_quota.query.started \(context.logFields)"
    case .profileQuotaQueryFinished(
      let context,
      let outcome,
      let elapsedMilliseconds,
      let retryAfterSeconds
    ):
      var fields = [
        "event=profile_quota.query.finished",
        context.logFields,
        outcome.logFields,
        "elapsed_ms=\(max(elapsedMilliseconds, 0))",
      ]
      if let retryAfterSeconds {
        fields.append("retry_after_seconds=\(max(retryAfterSeconds, 0))")
      }
      return fields.joined(separator: " ")
    }
  }
}
